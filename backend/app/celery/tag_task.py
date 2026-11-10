import logging
import time

import openai
import requests
from sqlalchemy import func, or_, true
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session, aliased
from sqlmodel import select

from app.celery.db import sync_session_maker
from app.celery.worker import app
from app.core.config import settings
from app.models import UserTag, Tag, ChatBotMessage, UserTaggingCheckpoint

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

openai.api_key = settings.OPENAI_API_KEY

# Bump this when changing sentiment/keyword semantics. Existing tags are kept;
# the new version re-examines the completed conversation from its first QA.
ANALYSIS_VERSION = "qa-keyword-v1"
CONVERSATION_END = "이제 대화는 여기까지야! 고마워 :)"
TAGGING_INITIALIZATION_LOCK = 290029


class TaggingAnalysisError(RuntimeError):
    """A provider failure must never be checkpointed as a valid no-tag result."""


candidate_keywords = [
    # 🍽 음식/음료
    "커피", "술", "차", "주스", "와인", "맥주",
    "한식", "중식", "일식", "양식", "분식", "패스트푸드", "디저트",

    # 🎵 음악
    "음악", "발라드", "팝송", "락", "재즈", "힙합", "클래식", "EDM", "밴드", "아이돌",

    # 🎮 게임
    "게임", "rpg", "fps", "전략", "모바일게임", "콘솔게임", "보드게임",

    # 🎥 문화/엔터테인먼트
    "영화", "드라마", "예능", "넷플릭스", "애니메이션", "유튜브", "책", "웹툰",
    "브이로그", "팟캐스트", "틱톡", "소설", "웹소설", "작곡", "작사",

    # 🏃‍♀️ 운동/취미
    "운동", "헬스", "요가", "러닝", "등산", "축구", "농구", "테니스",
    "댄스", "사진", "그림", "피아노", "드로잉", "캘리그라피",

    # ✈️ 여행/장소
    "여행", "국내", "해외", "바다", "산", "도시", "자연",
    "캠핑", "호텔", "펜션", "카페", "맛집",

    # 🧑‍💻 기술/디지털
    "안드로이드", "애플", "아이폰", "개발", "프로그래밍",
    "코딩", "AI", "GPT", "챗GPT", "IT", "테크", "스타트업",
    "UX", "UI", "디자인툴", "노션", "슬랙", "생산성",

    # 💼 커리어/직업
    "취업", "이직", "프리랜서", "공무원", "개발자", "디자이너",
    "마케터", "번역가", "의사", "간호사", "교사", "아르바이트",

    # 🎓 학문/지식
    "심리학", "경제학", "철학", "사회학", "역사", "문학", "수학",
    "물리학", "생물학", "천문학", "언어학", "법학", "교육학", "토익", "토플", "한국사",

    # 🧠 자기계발/루틴
    "자기계발", "명상", "독서", "글쓰기", "아침루틴", "시간관리",
    "목표설정", "공부법", "플래너",

    # 🌍 사회/환경
    "환경", "기후", "제로웨이스트", "비건", "사회운동",
    "정치", "뉴스", "시사", "노동", "인권", "페미니즘",

    # 🧘‍♀️ 정신/웰빙
    "멘탈헬스", "우울", "불안", "자존감", "감정조절", "마인드풀니스",

    # 🐶 일상/생활
    "반려동물", "강아지", "고양이", "일상", "직장", "학교",
    "연애", "취미", "쇼핑", "친구", "동호회", "인스타그램", "MBTI"
]



def trim_question_for_keyword(question: str) -> str:
    parts = question.split("?")
    for part in reversed(parts):
        if part.strip():
            return part.strip() + "?"
    return question.strip()

def analyze_sentiment(text: str) -> int:
    response = requests.post(
        settings.RUNPOD_SENTIMENT_API_URL,
        json={"input": {"text": text}},
        headers={"Authorization": f"Bearer {settings.RUNPOD_API_KEY}"},
        timeout=10,
    )
    response.raise_for_status()
    request_id = response.json().get("id")
    if not request_id:
        raise TaggingAnalysisError("Missing sentiment request ID")

    for _ in range(120):
        time.sleep(1)
        status_response = requests.get(
            f"https://api.runpod.ai/v2/{settings.RUNPOD_ENDPOINT_ID}/status/{request_id}",
            headers={"Authorization": f"Bearer {settings.RUNPOD_API_KEY}"},
            timeout=5,
        )
        status_response.raise_for_status()
        result = status_response.json()
        if result.get("status") == "COMPLETED":
            sentiment = (result.get("output") or {}).get("sentiment")
            if type(sentiment) is not int or sentiment not in (0, 1, 2):
                raise TaggingAnalysisError("Invalid sentiment result")
            return sentiment
        if result.get("status") in {"FAILED", "CANCELLED"}:
            raise TaggingAnalysisError("Sentiment job failed")
    raise TaggingAnalysisError("Sentiment polling timed out")


def keyword_with_sbert_then_gpt(text: str, sim_threshold=0.5):
    prompt = f"""
    아래 문장을 읽고, 사용자의 관심 분야를 상위 개념으로 한 단어만 출력해줘.
    가능한 키워드는 {candidate_keywords} 에서 꼭 하나만 선택.
    입력: "{text}"
    출력:
    """
    response = openai.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.3,
    )
    gpt_keyword = (response.choices[0].message.content or "").strip()
    if gpt_keyword not in candidate_keywords:
        raise TaggingAnalysisError("Invalid keyword result")
    return gpt_keyword

def analyze_qa_and_extract_keyword(question: str, answer: str):
    q_sent = analyze_sentiment(question)
    a_sent = analyze_sentiment(answer)
    if q_sent not in (0, 1, 2) or a_sent not in (0, 1, 2):
        raise TaggingAnalysisError("Invalid sentiment result")

    if q_sent == a_sent and q_sent in [0, 1]:
        combined = f"{trim_question_for_keyword(question)} {answer.strip()}"
        keyword = keyword_with_sbert_then_gpt(combined)
        return {"keyword": keyword}
    return None

def check_not_tag_user(db: Session):
    """Find closed conversations with missing, failed, or outdated progress."""
    last_msg_subq = (
        select(
            ChatBotMessage.user_id,
            func.max(ChatBotMessage.id).label("last_msg_id"),
        )
        .group_by(ChatBotMessage.user_id)
        .subquery()
    )
    checkpoint = UserTaggingCheckpoint
    query = (
        select(ChatBotMessage.user_id)
        .join(last_msg_subq, ChatBotMessage.id == last_msg_subq.c.last_msg_id)
        .outerjoin(checkpoint, checkpoint.user_id == ChatBotMessage.user_id)
        .where(
            ChatBotMessage.content.contains(CONVERSATION_END),
            or_(
                checkpoint.user_id.is_(None),
                checkpoint.analysis_version != ANALYSIS_VERSION,
                checkpoint.status != "completed",
                checkpoint.target_message_id < ChatBotMessage.id,
            ),
        )
        .order_by(ChatBotMessage.user_id)
    )
    return list(db.execute(query).scalars())


def save_user_tag(db: Session, user_id: int, keyword: str, score: float):
    """Flush the tag inside the caller's checkpoint transaction; never commit."""
    # Different users can discover the same new keyword concurrently.
    db.execute(
        insert(Tag).values(name=keyword).on_conflict_do_nothing(index_elements=["name"])
    )
    tag_id = db.execute(select(Tag.id).where(Tag.name == keyword)).scalar_one()
    exists = db.execute(
        select(UserTag.id).where(UserTag.user_id == user_id, UserTag.tag_id == tag_id)
    ).first()
    if not exists:
        db.add(UserTag(user_id=user_id, tag_id=tag_id, score=score))
    db.flush()


def _locked_checkpoint(db: Session, user_id: int, *, skip_locked=False):
    # Reload after every commit, including when expire_on_commit=False. A
    # concurrent worker may have advanced the cursor while we had no row lock.
    return db.execute(
        select(UserTaggingCheckpoint)
        .where(UserTaggingCheckpoint.user_id == user_id)
        .with_for_update(skip_locked=skip_locked)
        .execution_options(populate_existing=True)
    ).scalar_one_or_none()


def _next_qa(db: Session, user_id: int, after_id: int, target_id: int):
    question = aliased(ChatBotMessage)
    # Use an indexed seek for the immediate successor, including non-user
    # messages. Filtering the successor's role before LIMIT would change QA
    # adjacency by jumping over intervening assistant messages.
    answer = (
        select(ChatBotMessage.id, ChatBotMessage.role, ChatBotMessage.content)
        .where(
            ChatBotMessage.user_id == user_id,
            ChatBotMessage.id > question.id,
            ChatBotMessage.id <= target_id,
        )
        .order_by(ChatBotMessage.id).limit(1)
        .correlate(question).lateral()
    )
    return db.execute(
        select(question.content, answer.c.content, answer.c.id)
        .select_from(question).join(answer, true())
        .where(
            question.user_id == user_id,
            question.id > after_id,
            question.id <= target_id,
            question.role == "assistant",
            answer.c.role == "user",
        )
        .order_by(question.id).limit(1)
    ).first()


def process_user_for_tagging(db: Session, user_id: int):
    failed_cursor = None
    try:
        # Serialize initializers before the existence read: otherwise two
        # workers can both see no row and the later INSERT can wait on a worker
        # already doing paid analysis. This lock is released by the init commit.
        if not db.scalar(select(func.pg_try_advisory_xact_lock(
            TAGGING_INITIALIZATION_LOCK, user_id
        ))):
            db.rollback()
            return
        exists = db.scalar(select(UserTaggingCheckpoint.user_id).where(
            UserTaggingCheckpoint.user_id == user_id
        ))
        if exists is None:
            db.execute(
                insert(UserTaggingCheckpoint).values(
                    user_id=user_id,
                    analysis_version=ANALYSIS_VERSION,
                    status="pending",
                    last_message_id=0,
                    target_message_id=0,
                ).on_conflict_do_nothing(index_elements=["user_id"])
            )
        db.commit()
        while True:
            checkpoint = _locked_checkpoint(db, user_id, skip_locked=True)
            if checkpoint is None:
                # Another worker owns this user's QA; try other users this run.
                db.rollback()
                return
            if checkpoint.analysis_version != ANALYSIS_VERSION:
                checkpoint.analysis_version = ANALYSIS_VERSION
                checkpoint.last_message_id = 0
                checkpoint.target_message_id = 0
                checkpoint.status = "pending"
                checkpoint.last_error = None
                db.commit()
                continue
            failed_cursor = checkpoint.last_message_id
            latest = db.execute(
                select(ChatBotMessage)
                .where(ChatBotMessage.user_id == user_id)
                .order_by(ChatBotMessage.id.desc()).limit(1)
            ).scalar_one_or_none()
            if latest is None or CONVERSATION_END not in latest.content:
                db.rollback()
                return
            if (checkpoint.status == "completed"
                    and checkpoint.target_message_id >= latest.id):
                db.rollback()
                return

            checkpoint.target_message_id = latest.id
            checkpoint.status = "running"
            checkpoint.last_error = None
            pair = _next_qa(db, user_id, checkpoint.last_message_id, latest.id)
            if pair is None:
                checkpoint.last_message_id = latest.id
                checkpoint.status = "completed"
                db.commit()
                return

            question, answer, answer_id = pair
            result = analyze_qa_and_extract_keyword(question, answer)
            if result is not None:
                keyword = result["keyword"]
                if keyword not in candidate_keywords:
                    raise TaggingAnalysisError("Invalid keyword result")
                save_user_tag(db, user_id, keyword, 0.0)
            # Valid no-tag results also advance. A tag and its cursor always
            # commit together, so an interrupted QA is safe to retry.
            checkpoint.last_message_id = answer_id
            db.commit()
    except Exception as error:
        db.rollback()
        try:
            checkpoint = _locked_checkpoint(db, user_id, skip_locked=True)
            # Do not overwrite a newer worker's successful commit, including
            # when our commit succeeded but its acknowledgement was lost.
            if (checkpoint is not None
                    and checkpoint.analysis_version == ANALYSIS_VERSION
                    and checkpoint.last_message_id == failed_cursor
                    and checkpoint.status != "completed"):
                checkpoint.status = "failed"
                # Store only the type: provider errors may contain user text,
                # credentials or request URLs.
                checkpoint.last_error = type(error).__name__[:100]
                db.commit()
            else:
                db.rollback()
        except Exception:
            db.rollback()
            logger.error("Unable to record tagging failure: user_id=%s", user_id)
        raise


@app.task
def process_user_tag():
    if not settings.AI_ENABLED:
        return
    # Discovery and every user get separate sessions. A failed transaction or
    # disconnected DB connection must not poison the next user's session.
    with sync_session_maker() as session:
        user_ids = check_not_tag_user(session)
    for user_id in user_ids:
        with sync_session_maker() as session:
            try:
                process_user_for_tagging(session, user_id)
            except Exception as error:
                session.rollback()
                logger.error(
                    "Tagging failed; retry on next run: user_id=%s error=%s",
                    user_id, type(error).__name__,
                )

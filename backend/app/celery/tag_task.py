import logging
import time

import openai
import requests
from sqlalchemy import func
from sqlalchemy.orm import Session
from sqlmodel import select

from app.celery.db import sync_session_maker
from app.celery.worker import app
from app.core.config import settings
from app.models import UserTag, Tag, ChatBotMessage

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

openai.api_key = settings.OPENAI_API_KEY

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
    try:
        # 1. 분석 요청 보내기
        response = requests.post(
            settings.RUNPOD_SENTIMENT_API_URL,
            json={"input": {"text": text}},
            headers={"Authorization": f"Bearer {settings.RUNPOD_API_KEY}"},
            timeout=10
        )
        response.raise_for_status()
        result = response.json()

        request_id = result.get("id")
        if not request_id:
            logger.warning(f"[sentiment] ID 없음: {result}")
            return -1

        # 2. 최대 30초까지 폴링 (0.5초 간격)
        for _ in range(120):
            time.sleep(1)
            status_response = requests.get(
                f"https://api.runpod.ai/v2/{settings.RUNPOD_ENDPOINT_ID}/status/{request_id}",
                headers={"Authorization": f"Bearer {settings.RUNPOD_API_KEY}"},
                timeout=5
            )
            status_response.raise_for_status()
            status_result = status_response.json()

            status = status_result.get("status")
            if status == "COMPLETED":
                sentiment = status_result.get("output", {}).get("sentiment")
                if sentiment is not None:
                    return sentiment
                else:
                    logger.warning(f"[sentiment] 결과 도착했지만 sentiment 없음: {status_result}")
                    return -1
            elif status in {"FAILED", "CANCELLED"}:
                logger.error(f"[sentiment] 처리 실패: {status_result}")
                return -1

        # 30초 동안 결과가 안 나오면 타임아웃
        logger.warning(f"[sentiment] 30초 안에 완료되지 않음 (id: {request_id})")
        return -1

    except Exception as e:
        logger.error(f"[sentiment] 외부 API 호출 실패: {e}")
        return -1

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
    gpt_keyword = response.choices[0].message.content.strip()
    logger.info(f"[keyword] GPT fallback → '{gpt_keyword}'")
    return gpt_keyword

def analyze_qa_and_extract_keyword(question: str, answer: str):
    q_sent = analyze_sentiment(question)
    a_sent = analyze_sentiment(answer)
    logger.debug(f"[sentiment] Q={q_sent}, A={a_sent}")

    if q_sent == a_sent and q_sent in [0, 1]:
        combined = f"{trim_question_for_keyword(question)} {answer.strip()}"
        keyword = keyword_with_sbert_then_gpt(combined)
        return {"keyword": keyword}
    return None

def check_not_tag_user(db: Session):
    # 1. 태그된 사용자 목록
    tagged_user_subq = select(UserTag.user_id).distinct()

    # 2. 사용자별 가장 마지막 메시지 ID 추출
    last_msg_subq = (
        select(
            ChatBotMessage.user_id,
            func.max(ChatBotMessage.id).label("last_msg_id")
        )
        .group_by(ChatBotMessage.user_id)
        .subquery()
    )

    # 3. 마지막 메시지 내용 필터링 + 태그 없는 사용자 조건 적용
    query = (
        select(ChatBotMessage.user_id)
        .join(last_msg_subq, ChatBotMessage.id == last_msg_subq.c.last_msg_id)
        .where(
            ~ChatBotMessage.user_id.in_(tagged_user_subq),  # 태그 없는 사용자
            ChatBotMessage.content.ilike("%이제 대화는 여기까지야! 고마워 :)%")  # 마지막 메시지 조건
        )
    )

    user_rows = db.execute(query).all()
    user_ids = [row[0] for row in user_rows]

    logger.info(f"[check_user] 조건에 맞는 사용자 수: {len(user_ids)} → {user_ids}")
    return user_ids

def save_user_tag(db: Session, user_id: int, keyword: str, score: float):
    tag = db.query(Tag).filter_by(name=keyword).first()
    if not tag:
        tag = Tag(name=keyword)
        db.add(tag)
        db.flush()

    exists = db.query(UserTag).filter_by(user_id=user_id, tag_id=tag.id).first()
    if not exists:
        db.add(UserTag(user_id=user_id, tag_id=tag.id, score=score))
        logger.info(f"[DB] 태그 저장 완료 → user_id={user_id}, tag='{keyword}', score={score}")
    else:
        logger.info(f"[DB] 이미 존재하는 태그 → user_id={user_id}, tag='{keyword}'")

    db.commit()


def process_user_for_tagging(db: Session, user_id: int):
    logger.info(f"[tagging] user_id={user_id} 분석 시작")
    messages = db.execute(
        select(ChatBotMessage)
        .where(ChatBotMessage.user_id == user_id)
        .order_by(ChatBotMessage.id)
    ).scalars().all()

    qa_pairs = [
        (messages[i].content, messages[i + 1].content)
        for i in range(len(messages) - 1)
        if messages[i].role == "assistant" and messages[i + 1].role == "user"
    ]
    logger.info(f"[tagging] QA 페어 수: {len(qa_pairs)}")

    for q, a in qa_pairs:
        result = analyze_qa_and_extract_keyword(q, a)
        if result:
            save_user_tag(db, user_id, result["keyword"], 0.0)
        else:
            logger.info("[tagging] 키워드 추출 실패")

@app.task
def process_user_tag():
    logger.info("[Celery] process_user_tag 시작")
    with sync_session_maker() as session:
        user_ids = check_not_tag_user(session)
        for user_id in user_ids:
            try:
                process_user_for_tagging(session, user_id)
            except Exception as e:
                logger.exception(f"[Celery] 사용자 처리 중 오류 발생: user_id={user_id}")

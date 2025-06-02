import logging

import openai
import torch
from sqlalchemy import func
from sqlalchemy.orm import Session
from sqlmodel import select

from app.celery.ai_moel.model_loader import load_model
from app.celery.db import sync_session_maker
from app.celery.worker import app
from app.core.config import settings
from app.models import UserTag, Tag, ChatBotMessage

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

openai.api_key = settings.OPENAI_API_KEY

candidate_keywords = [
    "커피", "술", "안드로이드", "애플",
    "음악", "발라드", "팝송", "밴드", "힙합",
    "게임", "rpg", "fps", "운동",
    "영화", "책", "여행", "반려동물", "산", "바다", "국내", "해외",
    "한식", "중식", "일식", "양식"
]

def analyze_sentiment(text: str) -> int:
    try:
        sentiment_model, sentiment_tokenizer = load_model()
        text = text.replace("?", "").strip()
        inputs = sentiment_tokenizer(text, return_tensors="pt", truncation=True)
        with torch.no_grad():
            outputs = sentiment_model(**inputs)

        probs = torch.softmax(outputs.logits, dim=1)
        pred = torch.argmax(probs, dim=1).item()

        logger.info(f"[sentiment] 예측 결과: {pred}")
        return pred

    except Exception as e:
        logger.exception(f"[sentiment] 분석 중 오류 발생: {e}")
        return -1

def trim_question_for_keyword(question: str) -> str:
    parts = question.split("?")
    for part in reversed(parts):
        if part.strip():
            return part.strip() + "?"
    return question.strip()

def keyword_with_sbert_then_gpt(text: str, sim_threshold=0.5):
    prompt = f"""
    아래 문장을 읽고, 사용자의 관심 분야를 상위 개념으로 한 단어만 출력해줘.
    가능한 키워드는 {candidate_keywords} 중 하나만 선택.
    입력: "{text}"
    출력:
    """
    response = openai.chat.completions.create(
        model="gpt-3.5-turbo",
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
    subq = select(UserTag.user_id).distinct()
    user_rows = db.execute(
        select(ChatBotMessage.user_id)
        .where(~ChatBotMessage.user_id.in_(subq))
        .group_by(ChatBotMessage.user_id)
        .having(func.count(ChatBotMessage.id) >= 10)
    ).all()
    user_ids = [row[0] for row in user_rows]
    logger.info(f"[check_user] 대상 사용자 수: {len(user_ids)} → {user_ids}")
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

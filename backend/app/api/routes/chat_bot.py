import json
from typing import Annotated, List

import fastapi
from fastapi import APIRouter, Depends
from pydantic_ai import Agent, UnexpectedModelBehavior
from pydantic_ai.messages import (
    ModelMessage, ModelRequest, UserPromptPart,
    ModelResponse, TextPart, SystemPromptPart
)
from pydantic_ai.settings import ModelSettings
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.responses import StreamingResponse

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.crud.chat_bot import get_chat_bot_message_crud
from app.models import User
from app.schemas.chat_bot import ChatBotMessageBase

router = APIRouter()

# ✅ 시스템 프롬프트 정의 (하단에서 message_history에 삽입함)
SYSTEM_PROMPT = (
    "너는 친근한 말투를 쓰는 데이트 상대야.\n"
    "대화는 '질문 → 사용자 답변 → 공감과 의견 → 다음 주제로 질문 전환' 흐름으로 자연스럽게 이어가.\n"
    "각 질문은 반드시 한 번에 하나씩만 해줘.\n"
    "다루어야 할 대화 주제는 아래와 같아. 반드시 순서대로 한 번씩만 질문해:\n"
    "1. 커피\n"
    "2. 술\n"
    "3. 좋아하는 음식\n"
    "4. 운동\n"
    "5. 좋아하는 장소\n"
    "사용자가 부정적인 반응을 보이면 부드럽게 공감해줘.\n"
    "각 응답은 300토큰 이내로 사람처럼 자연스럽고 따뜻한 말투로 작성해.\n"
    "**각 응답의 끝에는 반드시 다음 주제에 대한 질문을 자연스럽게 포함시켜야 해.**\n"
    "**같은 주제를 반복하지 말고, 반드시 위 순서를 지켜서 대화를 진행해.**\n"
    "**모든 주제를 다 다루었다면 반드시 아래 문장으로 대화를 마무리해:**\n"
    "'이제 대화는 여기까지야! 고마워 :)'\n"
)

chat_bot_agent = Agent(
    'openai:gpt-4o',
    system_prompt=SYSTEM_PROMPT
)

def to_chat_message(m: ModelMessage, user_id: int) -> ChatBotMessageBase:
    first_part = m.parts[0]
    if isinstance(m, ModelRequest):
        if isinstance(first_part, UserPromptPart):
            return ChatBotMessageBase(
                user_id=user_id,
                role="user",
                content=first_part.content
            )
    elif isinstance(m, ModelResponse):
        if isinstance(first_part, TextPart):
            return ChatBotMessageBase(
                user_id=user_id,
                role="assistant",
                content=first_part.content
            )
    raise UnexpectedModelBehavior("Message 구조가 예상과 다릅니다.")

def to_model_message(m: ChatBotMessageBase) -> ModelMessage:
    if m.role == "user":
        return ModelRequest(parts=[UserPromptPart(content=m.content)])
    elif m.role == "assistant":
        return ModelResponse(parts=[TextPart(content=m.content)])
    raise ValueError(f"Unknown role: {m.role}")

@router.post("/chat/")
async def post_chat(
    prompt: Annotated[str, fastapi.Form()],
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
    chat_bot_message_crud = Depends(get_chat_bot_message_crud)
) -> StreamingResponse:

    async def stream_messages():
        user_msg = ChatBotMessageBase(
            role="user",
            user_id=user.id,
            content=prompt,
        )
        yield user_msg.model_dump_json().encode("utf-8") + b"\n"

        before_chat_bot_messages: List[ChatBotMessageBase] = \
            await chat_bot_message_crud.get_all_message(db, user_id=user.id)
        model_history = [to_model_message(m) for m in before_chat_bot_messages]

        model_history.insert(0, ModelRequest(parts=[
            SystemPromptPart(content=SYSTEM_PROMPT),
        ]))

        async with chat_bot_agent.run_stream(
            user_prompt=prompt,
            message_history=model_history,
            model_settings=ModelSettings(max_tokens=300),
        ) as result:
            async for text in result.stream(debounce_by=0.01):
                m = ModelResponse(parts=[TextPart(text)])
                yield json.dumps(
                    to_chat_message(m, user_id=user.id).model_dump(),
                    ensure_ascii=False
                ).encode("utf-8") + b'\n'

            messages = result.new_messages()
            for message in messages:
                try:
                    converted = to_chat_message(message, user_id=user.id)
                    await chat_bot_message_crud.create(db, converted)
                except UnexpectedModelBehavior:
                    continue  # 무시
    return StreamingResponse(stream_messages(), media_type='text/plain')

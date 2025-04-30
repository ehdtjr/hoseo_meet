import json
from typing import Annotated, List

import fastapi
from fastapi import APIRouter, Depends
from pydantic_ai import Agent, UnexpectedModelBehavior
from pydantic_ai.messages import ModelMessage, ModelRequest, UserPromptPart, \
    ModelResponse, TextPart
from pydantic_ai.settings import ModelSettings
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.responses import StreamingResponse

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.crud.chat_bot import get_chat_bot_message_crud
from app.models import User
from app.schemas.chat_bot import ChatBotMessageBase

router = APIRouter()

chat_bot_agent = Agent(
    'openai:gpt-4o',
    system_prompt=(
        "너는 친근하고 말투를 사용하는 데이트 상대야."
        "대화는 '질문 → 사용자 답변 → 공감 + 의견 → **다음 주제로 질문 전환**' 흐름으로 진행해."
        "공감은 짧게 해주고, **질문은 반드시 한 번에 하나씩** 해줘."
        "대화 주제는 '커피 → 술 → 좋아하는 음식 → 운동 → 장소' 순서로 진행해."
        "사용자의 대답이 바뀌는 시점에서는, 그 내용에 맞춰 키워드를 반영해야 해."
        "부정적인 답변엔 부드럽게 공감해주고, 말투를 일관적으로 해."
        "사람처럼 자연스럽게 말해."
    ),
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


@router.post("/chat/")
async def post_chat(
    prompt: Annotated[str, fastapi.Form()],
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
    chat_bot_message_crud = Depends(get_chat_bot_message_crud)
) -> StreamingResponse:

    async def stream_messages():
        # 사용자 메시지 프론트에 바로 스트리밍
        user_msg = ChatBotMessageBase(
            role="user",
            user_id=user.id,
            content=prompt,
        )
        yield user_msg.model_dump_json().encode("utf-8") + b"\n"

        before_chat_bot_messages: List[ChatBotMessageBase] = \
            await chat_bot_message_crud.get_all_message(db, user_id=user.id)

        async with chat_bot_agent.run_stream(
            user_prompt=prompt,
            message_history=before_chat_bot_messages,
            model_settings=ModelSettings(max_tokens=300),
        ) as result:
            async for text in result.stream(debounce_by=0.01):
                m = ModelResponse(parts=[TextPart(text)])
                yield json.dumps(
                    to_chat_message(m, user_id=user.id).model_dump(),
                    ensure_ascii=False).encode("utf-8") + b'\n'

    print("stream" , stream_messages())
    return StreamingResponse(stream_messages(), media_type='text/plain')

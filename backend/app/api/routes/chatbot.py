import datetime
import json
from typing import Annotated

import fastapi
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic_ai import Agent
from starlette.responses import StreamingResponse

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.models import User


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
        "300토큰 이내로 대답하고, 사람처럼 자연스럽게 말해."
    ),
)
keyword_agent = Agent('openai:gpt-4o')

@router.post("/chat")
async def post_chat(
    prompt: Annotated[str, fastapi.Form()],
    user: User = Depends(current_active_user),
    db: AsyncSession = Depends(get_async_session),
) -> StreamingResponse:

    async def stream_messages():
        yield (
            json.dumps(
                {
                    'role': 'user',
                    'content': prompt,
                    'timestamp': datetime.now(
                        tz=datetime.timezone.utc).isoformat(),
                }
            ).encode('utf-8')
        )

    async with chat_bot_agent.run_stream(
        prompt,
    ) as result:
        pass
from typing import Literal

from pydantic import BaseModel, ConfigDict


class ChatBotMessageBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: int
    role: Literal["user", "assistant"]
    content: str

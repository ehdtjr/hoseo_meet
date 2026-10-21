from typing import Literal

from pydantic import BaseModel

EventType = Literal["stream", "user", "location", "read"]


class EventBase(BaseModel):
    type: EventType
    data: str
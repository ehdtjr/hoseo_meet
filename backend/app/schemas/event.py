from typing import Dict, Any, Literal

from pydantic import BaseModel
import json

EventType = Literal["stream", "user", "location", "read"]


class EventBase(BaseModel):
    type: EventType
    data: Dict[str, Any]

    def to_str_dict(self) -> Dict[str, str]:
        return {
            "type": self.type,
            "data": json.dumps(self.data)  # data 필드를 JSON 문자열로 변환
        }
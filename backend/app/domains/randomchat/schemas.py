from typing import Literal

from pydantic import BaseModel, Field, model_validator


class QueueStatus(BaseModel):
    status: Literal["idle", "waiting", "matched"]
    stream_id: int | None = Field(default=None, gt=0)

    @model_validator(mode="after")
    def validate_match(self):
        if (self.status == "matched") != (self.stream_id is not None):
            raise ValueError("Only a matched result has a stream_id")
        return self

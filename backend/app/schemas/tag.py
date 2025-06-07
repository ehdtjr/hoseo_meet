from dataclasses import Field
from typing import Optional, Annotated

from pydantic import BaseModel, ConfigDict, condecimal



class TagBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: str


class TagCreate(TagBase):
    pass


class TagRead(TagBase):
    id: int


PositiveScore = Annotated[float, condecimal(ge=0)]

class UserTagBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: int
    tag_id: int
    score: PositiveScore = 0.0


class UserTagCreate(UserTagBase):
    pass


class UserTagRead(UserTagBase):
    id: int
    tag: Optional[TagRead] = None

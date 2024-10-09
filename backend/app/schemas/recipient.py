from enum import Enum

from pydantic import BaseModel, ConfigDict


class RecipientType(Enum):
    USER = 1
    STREAM = 2


class RecipientBase(BaseModel):
    model_config = ConfigDict(use_enum_values=True, from_attributes=True)

    id: int
    type: RecipientType
    type_id: int


class RecipientCreate(BaseModel):
    model_config = ConfigDict(use_enum_values=True, from_attributes=True)

    type: RecipientType
    type_id: int


class RecipientRead(RecipientBase):
    pass

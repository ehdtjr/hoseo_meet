from typing import Generic, TypeVar, Type, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from sqlalchemy.orm import DeclarativeBase


ModelType = TypeVar("ModelType", bound=DeclarativeBase)
SchemaType = TypeVar("SchemaType", bound=BaseModel)


class CRUDBase(Generic[ModelType, SchemaType]):
    def __init__(self, model: Type[ModelType], schema: Type[SchemaType]):
        self.model = model
        self.schema = schema

    async def create(self, db: AsyncSession, obj_in: SchemaType) -> SchemaType:
        obj_in_data = obj_in.model_dump()
        db_obj = self.model(**obj_in_data)
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)
        return self.schema.model_validate(db_obj.__dict__)

    async def get(self, db: AsyncSession, id: int) -> Optional[SchemaType]:
        result = await db.get(self.model, id)
        if result is None:
            return None
        return self.schema.model_validate(result.__dict__)

    async def update(self, db: AsyncSession, obj_in: SchemaType) -> SchemaType:
        db_obj = await db.get(self.model, obj_in.id)
        update_data = obj_in.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            setattr(db_obj, field, value)

        await db.commit()
        await db.refresh(db_obj)

        return self.schema.model_validate(db_obj)

    async def delete(self, db: AsyncSession, id: int) -> None:
        obj = await db.get(self.model, id)
        if obj:
            await db.delete(obj)
            await db.commit()

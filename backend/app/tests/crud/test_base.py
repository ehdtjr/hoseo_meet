from pydantic import BaseModel, ConfigDict
from sqlalchemy import Column, Integer, String

from app.core.db import Base
from app.crud.base import CRUDBase
from app.tests.conftest import BaseTest


class TestModel(Base):
    __tablename__ = 'test_model'

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)


class TestModelCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str


class TestCRUDBase(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        self.crud_base = CRUDBase[TestModel, TestModelCreate](TestModel,
                                                              TestModelCreate)

    async def test_create(self):
        # given
        obj_in = TestModelCreate(id=1, name='Test Name')

        # when
        obj = await self.crud_base.create(self.db, obj_in)

        # then
        self.assertIsNotNone(obj)
        self.assertEqual(obj.id, 1)
        self.assertEqual(obj.name, 'Test Name')

    async def test_get(self):
        # given
        test_obj = TestModel(id=1, name='Test Name')
        self.db.add(test_obj)
        await self.db.commit()
        await self.db.refresh(test_obj)

        # when
        obj = await self.crud_base.get(self.db, 1)

        # then
        self.assertIsNotNone(obj)
        self.assertEqual(obj.id, 1)
        self.assertEqual(obj.name, 'Test Name')

    async def test_update(self):
        # given
        test_obj = TestModel(id=1, name='Test Name')
        self.db.add(test_obj)
        await self.db.commit()
        await self.db.refresh(test_obj)

        # when
        update_in = TestModelCreate(id=1, name='Updated Name')
        updated_obj = await self.crud_base.update(self.db, update_in)

        # then
        self.assertEqual(updated_obj.name, 'Updated Name')

    async def test_delete(self):
        # given
        test_obj = TestModel(id=1, name='Test Name')
        self.db.add(test_obj)
        await self.db.commit()
        await self.db.refresh(test_obj)

        # when
        await self.crud_base.delete(self.db, 1)

        # then
        obj = await self.crud_base.get(self.db, 1)
        self.assertIsNone(obj)

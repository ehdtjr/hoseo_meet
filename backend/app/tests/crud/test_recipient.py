from app.crud.recipient import RecipientCRUD
from app.models.recipient import Recipient
from app.schemas.recipient import RecipientCreate, RecipientType
from app.tests.conftest import BaseTest


class TestRecipientCRUD(BaseTest):
    async def test_create(self):
        recipient_crud = RecipientCRUD()
        recipient_data = RecipientCreate(
            type=RecipientType.STREAM,
            type_id=1
        )

        # when
        await recipient_crud.create(self.db, recipient_data)

        # then
        result = await self.db.get(Recipient, 1)

        self.assertIsNotNone(result)
        self.assertEqual(result.id, 1)
        self.assertEqual(result.type, RecipientType.STREAM.value)
        self.assertEqual(result.type_id, 1)

    async def test_get_recipient(self):
        # `create` 메서드를 통해 객체를 생성하여 `get` 테스트
        recipient_crud = RecipientCRUD()
        recipient_data = RecipientCreate(
            id=1,
            type=RecipientType.STREAM,
            type_id=1
        )
        await recipient_crud.create(self.db, recipient_data)

        # when
        result = await recipient_crud.get(self.db, 1)

        # then
        self.assertIsNotNone(result)
        self.assertEqual(result.id, 1)
        self.assertEqual(result.type, RecipientType.STREAM.value)
        self.assertEqual(result.type_id, 1)

    async def test_delete_recipient(self):
        recipient_crud = RecipientCRUD()
        recipient_data = RecipientCreate(
            id=1,
            type=RecipientType.STREAM,
            type_id=1
        )
        await recipient_crud.create(self.db, recipient_data)

        # when
        await recipient_crud.delete(self.db, 1)

        # then
        result = await self.db.get(Recipient, 1)
        self.assertIsNone(result)


    async def test_get_by_type_id(self):
        recipient_crud = RecipientCRUD()
        recipient_data = RecipientCreate(
            type=RecipientType.STREAM,
            type_id=2
        )
        await recipient_crud.create(self.db, recipient_data)

        # when
        result = await recipient_crud.get_by_type_id(self.db, 2)

        # then
        self.assertIsNotNone(result)
        self.assertEqual(result.type, RecipientType.STREAM.value)
        self.assertEqual(result.type_id, 2)
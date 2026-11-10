"""Synthetic seed import proves coordinates and no partial save on bad input."""
import csv
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from sqlalchemy import func, select, text

from app.models.room_post import RoomPost
from app.scripts.rental_csv import FIELDS
from app.scripts.room_to_postgresql import load_room_posts_from_csv
from app.tests.conftest import BaseTest, override_get_db
from contextlib import asynccontextmanager


class TestRentalImport(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'synthetic.csv'
        self.row = ['Synthetic room', 'Synthetic address', '', '', '', '', '',
                    'quoted, comment', 'back', '36.74', '127.07']

    def write(self, rows):
        with self.path.open('w', newline='') as output:
            csv.writer(output).writerows([FIELDS, *rows])

    async def load(self):
        with patch('app.scripts.room_to_postgresql.get_async_session_context',
                   asynccontextmanager(override_get_db)):
            await load_room_posts_from_csv(str(self.path))

    async def test_valid_synthetic_rows_load_coordinates(self):
        self.write([self.row])
        await self.load()
        self.assertEqual(await self.db.scalar(select(func.count()).select_from(RoomPost)), 1)
        point = await self.db.scalar(text('SELECT ST_AsText(location::geometry) FROM room_post'))
        self.assertEqual(point, 'POINT(127.07 36.74)')

    async def test_invalid_later_row_does_not_partially_save(self):
        bad = self.row.copy()
        bad[0] = 'Invalid second room'
        bad[-1] = 'not longitude'
        self.write([self.row, bad])
        with self.assertRaises(ValueError):
            await self.load()
        self.assertEqual(await self.db.scalar(select(func.count()).select_from(RoomPost)), 0)

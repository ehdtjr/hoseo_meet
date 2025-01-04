# file: app/core/init_db.py (예시)
import csv
import asyncio
from typing import List
from sqlalchemy.ext.asyncio import AsyncEngine

from app.core.db import engine, Base
from app.models.room_post import RoomPost
import csv
from typing import List, Optional

from app.core.db import get_async_session_context
from app.models.room_post import RoomPost

async def init_tables() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

async def load_room_posts_from_csv(csv_path: str) -> None:

    async with get_async_session_context() as session:
        # CSV 파일 열기
        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)

            # Insert할 RoomPost 객체들을 모아둔다
            room_posts = []
            for row in reader:
                # CSV 컬럼명과 모델 필드를 맞춰서 매핑
                post = RoomPost(
                    name=row["name"],
                    address=row["address"],
                    contact=row.get("contact"),
                    price=row.get("price"),
                    fee=row.get("fee"),
                    options=row.get("options"),
                    gas_type=row.get("gas_type"),
                    comment=row.get("comment"),
                    place=row["place"],
                    latitude=float(row["latitude"]),
                    longitude=float(row["longitude"]),
                )
                room_posts.append(post)

            session.add_all(room_posts)
        # 세션 커밋
        await session.commit()

async def main():
    # 1. 테이블 초기화(생성) 
    await init_tables()
    # 2. CSV 로드 및 데이터 삽입
    await load_room_posts_from_csv("./room_data.csv")

if __name__ == "__main__":
    # 비동기 함수 실행
    asyncio.run(main())
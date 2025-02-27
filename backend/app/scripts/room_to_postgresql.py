# file: app/core/init_db.py (예시)
import asyncio
import csv

from app.core.db import engine, Base
from app.core.db import get_async_session_context
from app.models.room_post import RoomPost, RoomPostImage


async def init_tables() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def load_room_posts_from_csv(csv_path: str) -> None:
    async with get_async_session_context() as session:
        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            room_posts = []
            for row in reader:
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
        await session.commit()


async def load_room_post_images_from_csv(csv_path: str) -> None:
    async with get_async_session_context() as session:
        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            images = []
            for row in reader:
                # CSV 파일에는 room_id와 image 컬럼이 있어야 합니다.
                image_obj = RoomPostImage(
                    room_id=int(row["room_id"]),
                    image=row["image_url"]
                )
                images.append(image_obj)
            session.add_all(images)
        await session.commit()


async def main():
    # 1. 테이블 초기화(생성)
    await init_tables()
    # 2. CSV 파일로부터 RoomPost 데이터 삽입
    #await load_room_posts_from_csv("../../last_rental_data.csv")
    # 3. CSV 파일로부터 RoomPostImage 데이터 삽입
    await load_room_post_images_from_csv("../../room_image.csv")


if __name__ == "__main__":
    asyncio.run(main())

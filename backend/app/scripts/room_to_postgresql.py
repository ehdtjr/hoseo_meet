# file: app/core/init_db.py (예시)
import asyncio
import csv

from app.core.db import get_async_session_context
from app.models.room_post import RoomPost, RoomPostImage


async def load_room_posts_from_csv(csv_path: str) -> None:
    async with get_async_session_context() as session:
        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            room_posts = []
            for row in reader:
                # CSV 파일에서 경도와 위도를 읽어와서 WKT 문자열로 변환합니다.
                lon = float(row["longitude"])
                lat = float(row["latitude"])
                location_wkt = f"POINT({lon} {lat})"

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
                    location=location_wkt
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
    await load_room_posts_from_csv("../../last_rental_data.csv")
    await load_room_post_images_from_csv("../../room_image.csv")


if __name__ == "__main__":
    asyncio.run(main())

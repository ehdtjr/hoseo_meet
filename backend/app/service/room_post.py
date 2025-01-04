from abc import ABC, abstractmethod
from typing import List, Optional
from math import sqrt
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc

from app.models.room_post import RoomPost
from app.models.room_post import RoomReview  # 리뷰 테이블 (별점 및 리뷰수 계산용)
from app.schemas.room_post import RoomPostListResponse, RoomPostDetailResponse

from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from fastapi import UploadFile

from app.models.room_post import RoomReview
from app.models.room_post import RoomReviewImage
from app.models.user import User
from app.schemas.room_post import RoomReviewResponse, UserPublicRead
from app.utils.s3 import upload_file_to_s3


class RoomPostServiceProtocol(ABC):
    @abstractmethod
    async def get_room_posts(
        self,
        db: AsyncSession,
        place: Optional[str],
        sort_by: Optional[str],  # "distance", "reviews", "rating" 등
        user_lat: Optional[float],
        user_lon: Optional[float],
        skip: int,
        limit: int,
    ) -> List[RoomPostListResponse]: ...

    @abstractmethod
    async def get_room_post_detail(
        self,
        db: AsyncSession,
        room_id: int,
        user_lat: Optional[float] = None,
        user_lon: Optional[float] = None,
    ) -> Optional[RoomPostDetailResponse]: ...


class RoomPostService(RoomPostServiceProtocol):
    async def get_room_posts(
        self,
        db: AsyncSession,
        place: Optional[str],
        sort_by: Optional[str],
        user_lat: Optional[float],
        user_lon: Optional[float],
        skip: int,
        limit: int,
    ) -> List[RoomPostListResponse]:

        # distance_expr (None이면 거리계산 안 함)
        distance_expr = None
        if user_lat is not None and user_lon is not None:
            distance_expr = (RoomPost.latitude - user_lat) ** 2 + (
                RoomPost.longitude - user_lon
            ) ** 2

        columns = [
            RoomPost,
            func.coalesce(func.avg(RoomReview.rating), 0).label("avg_rating"),
            func.count(RoomReview.id).label("reviews_count"),
        ]
        if distance_expr is not None:
            columns.append(distance_expr.label("distance"))
        else:
            pass

        # ROOMPOST + REVIEW outer join, group by
        stmt = (
            select(*columns)
            .outerjoin(RoomReview, RoomReview.room_id == RoomPost.id)
            .group_by(RoomPost.id)
        )

        # place 필터링
        if place:
            stmt = stmt.where(RoomPost.place == place)

        # 정렬
        if sort_by == "distance" and distance_expr is not None:
            stmt = stmt.order_by(distance_expr)  # 오름차순(가까운 순)
        elif sort_by == "reviews":
            stmt = stmt.order_by(desc(func.count(RoomReview.id)))  # 리뷰 많은 순
        elif sort_by == "rating":
            stmt = stmt.order_by(desc(func.coalesce(func.avg(RoomReview.rating), 0)))
        else:
            # 기본 정렬(예: id ASC) 등
            pass

        # 페이지네이션
        stmt = stmt.offset(skip).limit(limit)

        # 실제 실행
        rows = await db.execute(stmt)
        results = rows.all()
        # results 각 row는 (RoomPost, avg_rating, reviews_count, distance 또는 None) tuple 형태

        response_list: List[RoomPostListResponse] = []

        for row in results:
            # row[0] = RoomPost
            room_obj: RoomPost = row[0]
            avg_rating_val: float = float(row[1]) if row[1] else 0.0
            reviews_count_val: int = row[2]
            distance_val: float = 0.0
            if distance_expr is not None:
                # row[3]가 distance 값
                distance_val = float(row[3] or 0.0)

            # Pydantic 모델로 변환
            item = RoomPostListResponse(
                id=room_obj.id,
                name=room_obj.name,
                reviews_count=reviews_count_val,
                avg_rating=avg_rating_val,
                distance=distance_val,  # 필요에 따라 sqrt를 씌울 수도 있음
            )
            response_list.append(item)

        return response_list

    async def get_room_post_detail(
        self,
        db: AsyncSession,
        room_id: int,
        user_lat: Optional[float] = None,
        user_lon: Optional[float] = None,
    ) -> Optional[RoomPostDetailResponse]:
        # 1) RoomPost 하나 조회
        stmt_room = select(RoomPost).where(RoomPost.id == room_id)
        result_room = await db.scalars(stmt_room)
        room_obj = result_room.first()

        if not room_obj:
            return None

        # 2) 리뷰 통계
        stmt_review = select(
            func.count(RoomReview.id), func.coalesce(func.avg(RoomReview.rating), 0)
        ).where(RoomReview.room_id == room_id)
        review_res = await db.execute(stmt_review)
        reviews_count_val, avg_rating_val = review_res.one()
        avg_rating_val = float(avg_rating_val or 0.0)

        # 3) 거리 계산(옵션)
        distance_val = 0.0
        if user_lat is not None and user_lon is not None:
            # 단순 제곱합(실제론 sqrt(...) 또는 하버사인 공식)
            distance_val = (room_obj.latitude - user_lat) ** 2 + (
                room_obj.longitude - user_lon
            ) ** 2
            # 거리에 sqrt를 취할지, 하버사인 공식을 쓸지 등은 선택

        # 4) Pydantic 변환
        detail = RoomPostDetailResponse(
            id=room_obj.id,
            name=room_obj.name,
            reviews_count=reviews_count_val,
            avg_rating=avg_rating_val,
            distance=float(distance_val),
            address=room_obj.address,
            contact=room_obj.contact,
            price=room_obj.price,
            fee=room_obj.fee,
            options=room_obj.options,
            gas_type=room_obj.gas_type,
            comment=room_obj.comment,
            place=room_obj.place,
            latitude=room_obj.latitude,
            longitude=room_obj.longitude,
        )
        return detail


# FastAPI 의존성 주입용
room_post_service = RoomPostService()


def get_room_post_service() -> RoomPostServiceProtocol:
    return room_post_service


class RoomReviewService:
    async def create_room_review(
        self,
        db: AsyncSession,
        user_id: int,
        room_id: int,
        content: str,
        rating: float,
        images: List[UploadFile],
    ) -> RoomReviewResponse:
        """
        리뷰 생성 + RoomReviewImage 테이블에 이미지 URL 저장
        """
        # 1) RoomReview 생성
        new_review = RoomReview(
            room_id=room_id, author_id=user_id, content=content, rating=rating
        )
        db.add(new_review)
        await db.flush()  # review.id 확보

        # 2) 이미지가 있으면 S3 업로드 후 RoomReviewImage 생성
        for file in images:
            destination_path = f"reviews/{new_review.id}/{file.filename}"
            s3_url = upload_file_to_s3(file, destination_path)

            review_image = RoomReviewImage(
                review_id=new_review.id, room_id=room_id, image=s3_url
            )
            db.add(review_image)

        # 3) Commit 및 refresh
        await db.commit()
        await db.refresh(new_review)  # new_review.images 관계 로드

        # 4) 작성자 정보
        author = await db.get(User, user_id)
        author_data = UserPublicRead(
            name=author.name, profile=author.profile
        )

        # 5) 이미지 목록
        image_list = [img.image for img in new_review.images]

        # 6) RoomReviewResponse
        return RoomReviewResponse(
            id=new_review.id,
            room_id=new_review.room_id,
            content=new_review.content,
            rating=float(new_review.rating),
            created_at=new_review.created_at,
            author=author_data,
            images=image_list,
        )

    async def get_room_reviews(
        self,
        db: AsyncSession,
        room_id: int,
        page: int = 1,
        page_size: int = 5,
        sort_by: str = "latest",  # "latest" 또는 "rating"
    ) -> List[RoomReviewResponse]:
        """
        room_id 기준 리뷰 목록 + 페이지네이션 + 정렬
        """
        offset_val = (page - 1) * page_size

        # 기본 쿼리
        stmt = select(RoomReview).where(RoomReview.room_id == room_id)

        # 정렬
        if sort_by == "rating":
            stmt = stmt.order_by(desc(RoomReview.rating), desc(RoomReview.created_at))
        else:
            stmt = stmt.order_by(desc(RoomReview.created_at))

        # 페이지네이션
        stmt = stmt.offset(offset_val).limit(page_size)

        rows = await db.scalars(stmt)
        reviews = rows.all()

        # 변환
        results: List[RoomReviewResponse] = []
        for review in reviews:
            author_user = review.author
            author_data = UserPublicRead(
                name=author_user.name, profile=author_user.profile
            )
            image_list = [img.image for img in review.images]

            resp = RoomReviewResponse(
                id=review.id,
                room_id=review.room_id,
                content=review.content,
                rating=float(review.rating),
                created_at=review.created_at,
                author=author_data,
                images=image_list,
            )
            results.append(resp)

        return results


room_review_service = RoomReviewService()


def get_room_review_service():
    return room_review_service

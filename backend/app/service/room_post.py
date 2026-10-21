from abc import ABC, abstractmethod
from typing import Optional, List, Dict

from fastapi import UploadFile, Depends
from sqlalchemy import func, case
from sqlalchemy import select, desc, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.s3 import s3_manager
from app.crud.room_post import RoomPostHeartCRUD, RoomPostHeartCRUDProtocol, \
    get_room_post_heart
from app.models.room_post import RoomPost, RoomPostHeart
from app.models.room_post import RoomReview
from app.models.room_post import RoomReviewImage
from app.models.user import User
from app.schemas.room_post import RoomPostListResponse, \
    RoomPostDetailResponse, RoomReviewImageBase
from app.schemas.room_post import RoomReviewResponse, UserPublicRead
from app.utils.image import convert_image_to_webp
from app.utils.s3 import generate_s3_key


class RoomPostServiceProtocol(ABC):
    @abstractmethod
    async def get_room_posts(
        self,
        db: AsyncSession,
        user_id: int,
        name:Optional[str],
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

    def __init__(self, room_post_heart_crud: RoomPostHeartCRUDProtocol):
        self._room_post_heart_crud = room_post_heart_crud

    async def get_room_posts(
            self,
            db: AsyncSession,
            user_id: int,
            name: Optional[str],
            place: Optional[str],
            sort_by: Optional[str],
            user_lat: Optional[float],
            user_lon: Optional[float],
            skip: int,
            limit: int,
    ) -> List[RoomPostListResponse]:

        # 거리 계산 식 정의
        distance_expr = None
        if user_lat is not None and user_lon is not None:
            distance_expr = func.ST_Distance(
                RoomPost.location,
                func.ST_SetSRID(func.ST_MakePoint(user_lon, user_lat), 4326)
            )

        # 기본 컬럼 설정
        columns = [
            RoomPost,
            func.coalesce(func.avg(RoomReview.rating), 0).label("avg_rating"),
            func.count(RoomReview.id).label("reviews_count"),
        ]
        if distance_expr is not None:
            columns.append(distance_expr.label("distance"))

        # 좋아요 필터인 경우
        if sort_by == "heart":
            stmt = (
                select(*columns)
                .join(RoomPostHeart, RoomPost.id == RoomPostHeart.room_id)
                .outerjoin(RoomReview, RoomReview.room_id == RoomPost.id)
                .where(RoomPostHeart.user_id == user_id)
                .group_by(RoomPost.id)
            )

            if name:
                stmt = stmt.where(RoomPost.name.ilike(f"%{name}%"))

            if distance_expr is not None:
                stmt = stmt.order_by(distance_expr)

        # 일반 정렬인 경우
        else:
            stmt = (
                select(*columns)
                .outerjoin(RoomReview, RoomReview.room_id == RoomPost.id)
                .group_by(RoomPost.id)
            )

            if place:
                stmt = stmt.where(RoomPost.place == place)

            if name:
                stmt = stmt.where(RoomPost.name.ilike(f"%{name}%"))

            if sort_by == "distance" and distance_expr is not None:
                stmt = stmt.order_by(distance_expr)
            elif sort_by == "reviews":
                stmt = stmt.order_by(desc(func.count(RoomReview.id)))
            elif sort_by == "rating":
                stmt = stmt.order_by(desc(func.avg(RoomReview.rating)))

        # 페이징
        stmt = stmt.offset(skip).limit(limit)

        # 쿼리 실행
        rows = await db.execute(stmt)
        results = rows.all()

        response_list: List[RoomPostListResponse] = []

        for row in results:
            room_obj: RoomPost = row[0]
            avg_rating_val: float = float(row[1]) if row[1] else 0.0
            reviews_count_val: int = row[2]
            distance_val: float = 0
            if distance_expr is not None and len(row) > 3:
                distance_val = row[3] or 0.0

            image_urls = [img.image for img in
                          room_obj.images] if room_obj.images else []

            is_heart = await self._room_post_heart_crud.is_heart(
                db=db,
                user_id=user_id,
                room_id=room_obj.id
            )
            item = RoomPostListResponse(
                id=room_obj.id,
                name=room_obj.name,
                reviews_count=reviews_count_val,
                avg_rating=avg_rating_val,
                distance=distance_val,
                images=image_urls,
                is_heart=is_heart
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

        # 2) 리뷰 통계 (평점 평균 + 개수 + 내림 처리된 평점별 개수)
        rating_counts_expr = {
            i: func.count(case((func.floor(RoomReview.rating) == i, 1))).label(f"rating_{i}")
            for i in range(1, 6)
        }

        stmt_review = select(
            func.count(RoomReview.id).label("reviews_count"),
            func.coalesce(func.avg(RoomReview.rating), 0).label("avg_rating"),
            *rating_counts_expr.values()
        ).where(RoomReview.room_id == room_id)

        review_res = await db.execute(stmt_review)
        review_data = review_res.one()

        reviews_count_val = review_data[0]
        avg_rating_val = float(review_data[1] or 0.0)

        # 평점별 개수 가져오기
        review_rating_counts: Dict[int, int] = {
            i: review_data[2 + i - 1] for i in range(1, 6)
        }

        # 3) 거리 계산(옵션)
        distance_val = 0.0
        if user_lat is not None and user_lon is not None:
            distance_stmt = select(
                func.ST_Distance(
                    RoomPost.location,
                    func.ST_SetSRID(func.ST_MakePoint(user_lon, user_lat), 4326)
                )
            ).where(RoomPost.id == room_id)
            distance_res = await db.execute(distance_stmt)
            distance_val = distance_res.scalar() or 0.0

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
            images=[img.image for img in room_obj.images] if room_obj.images else [],
            review_rating_counts=review_rating_counts  # 추가된 부분
        )
        return detail


# FastAPI 의존성 주입용
async def get_room_post_service(
    room_poset_heart_crud: RoomPostHeartCRUDProtocol = Depends(get_room_post_heart)
) -> RoomPostServiceProtocol:
    return RoomPostService(room_poset_heart_crud)


class RoomReviewService:
    async def create_room_review(
            self,
            db: AsyncSession,
            user_id: int,
            room_id: int,
            content: str,
            rating: float,
            images: Optional[List[UploadFile]],
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

        # 2) 이미지 처리
        if images:  # images가 None이 아닐 때만 실행
            valid_images = [file for file in images if file.filename]  # 빈 파일 제거

            for file in valid_images:
                destination_path = generate_s3_key(
                    f"reviews/{room_id}/{new_review.id}", file.filename
                )

                if file.content_type == "image/webp":
                    file.file.seek(0)  # 파일 포인터를 처음으로 이동
                    s3_url = await s3_manager.upload_file(file,
                                                          destination_path)
                else:
                    webp_file = convert_image_to_webp(file.file)
                    s3_url = await s3_manager.upload_byte_file(
                        webp_file, destination_path, "image/webp"
                    )

                review_image = RoomReviewImage(
                    review_id=new_review.id, room_id=room_id, image=s3_url
                )
                db.add(review_image)

        # 3) Commit 및 refresh
        await db.commit()
        await db.refresh(new_review)  # new_review.images 관계 로드

        # 4) 작성자 정보
        author_data = UserPublicRead.model_validate(await db.get(User, user_id))

        # 5) RoomReviewResponse
        return RoomReviewResponse(
            id=new_review.id,
            room_id=new_review.room_id,
            content=new_review.content,
            rating=float(new_review.rating),
            created_at=new_review.created_at,
            author=author_data,
            images=[img.image for img in
                    new_review.images] if new_review.images else []
        )

    async def get_room_reviews(
        self,
        db: AsyncSession,
        room_id: int,
        page: int = 1,
        page_size: int = 5,
        sort_by: str = "latest",  # "latest" 또는 "rating"
    ) -> List[RoomReviewResponse]:
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
                id=author_user.id,
                name=author_user.name,
                profile=author_user.profile
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

    async def delete_review_by_id(
        self,
        db: AsyncSession,
        review_id: int,
        user_id: int,
    ) -> Optional[RoomReviewResponse]:

        # 1) 리뷰가 존재하고 본인(author_id == user_id) 인지 확인
        stmt = select(RoomReview).where(RoomReview.id == review_id)
        result = await db.scalars(stmt)
        review = result.first()

        if not review or (review.author_id != user_id):
            return None  # 라우터에서 404 or 권한 에러

        author_data: UserPublicRead =\
            UserPublicRead.model_validate(
                await db.get(User, review.author_id)
            )

        # 이미지 목록(지금 상태에선 DB에 row가 존재)
        image_list = [img.image for img in review.images]

        for img_url in image_list:
            await s3_manager.delete_file(img_url)

        delete_images_stmt = delete(RoomReviewImage).where(
            RoomReviewImage.review_id == review_id
        )
        await db.execute(delete_images_stmt)

        # 4) 리뷰 삭제
        delete_review_stmt = delete(RoomReview).where(RoomReview.id == review_id)
        await db.execute(delete_review_stmt)

        await db.commit()

        return RoomReviewResponse(
            id=review.id,
            room_id=review.room_id,
            content=review.content,
            rating=float(review.rating),
            created_at=review.created_at,
            author=author_data,
            images=image_list,
        )


    async def get_room_images_by_room(
        self,
        db: AsyncSession,
        room_id: int,
        skip: int = 0,
        limit: int = 10,
    ) -> Optional[List[RoomReviewImageBase]]:
        query = (
            select(RoomReviewImage)
            .where(RoomReviewImage.room_id == room_id)
            .order_by(desc(RoomReviewImage.created_at))
            .offset(skip)
            .limit(limit)
        )
        result = await db.execute(query)
        return [RoomReviewImageBase.model_validate(image) for image in result.scalars()]


async def get_room_review_service():
    return RoomReviewService()
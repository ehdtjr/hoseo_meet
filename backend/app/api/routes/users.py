from fastapi import APIRouter, UploadFile
from fastapi import HTTPException
from fastapi.params import Depends, File
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.db import get_async_session
from app.core.s3 import S3Manager
from app.core.security import current_active_user
from app.crud.user import UserFCMTokenCRUDProtocol, \
    get_user_fcm_token_crud, UserCRUDProtocol, get_user_crud
from app.models import User
from app.schemas.stream import SubscriptionRequest
from app.schemas.user import (UserFCMTokenCreate, UserFCMTokenRequest,
                              UserRead, UserPublicRead, UserUpdate)
from app.service.stream import SubscriberServiceProtocol, \
    get_subscription_service
from app.utils.image import convert_image_to_webp
from app.utils.s3 import generate_s3_key

router = APIRouter()


@router.post("/me/register/fcm-token")
async def register_fcm_token(
        fcm_token: UserFCMTokenRequest,
        db: AsyncSession = Depends(get_async_session),
        user: User = Depends(current_active_user),
        fcm_token_crud: UserFCMTokenCRUDProtocol = Depends(
            get_user_fcm_token_crud)
):
    try:

        """
            이미 등록된 토큰이 있는지 확인 user로, 있다면 업데이트
        """
        existing_fcm_token = await fcm_token_crud.get_user_fcm_token_by_user_id(
            db, user.id)

        if existing_fcm_token:
            existing_fcm_token.fcm_token = fcm_token.fcm_token
            await fcm_token_crud.update(db, existing_fcm_token)
            return {
                "msg": "",
                "result": "success",
            }

        fcm_token_data = UserFCMTokenCreate(
            user_id=user.id,
            fcm_token=fcm_token.fcm_token
        )

        await fcm_token_crud.create(db, fcm_token_data)

        return {
            "msg": "",
            "result": "success",
        }
    except Exception as e:
        raise (HTTPException(status_code=500,
                             detail=f"Failed to register fcm token: {str(e)}"))


@router.get("/me/subscriptions")
async def get_subscriptions(
        db: AsyncSession = Depends(get_async_session),
        user: User = Depends(current_active_user),
        subscriptions_service: SubscriberServiceProtocol = Depends(
            get_subscription_service),
):
    """
    현재 로그인된 사용자(user.id)가 구독 중인 모든 스트림 목록을 조회.

    - subscription_service.get_subscription_list로 사용자 구독 목록을 가져옴.
    - 예외 발생 시 HTTP 500 반환.
    """
    try:
        subscriptions = \
            await subscriptions_service.get_subscription_list(db, user.id)
        return {
            "msg": "",
            "result": "success",
            "subscriptions": subscriptions
        }
    except Exception as e:
        raise (HTTPException(status_code=500,
                             detail=f"Failed to fetch subscriptions: {str(e)}"))


@router.post("/me/subscriptions")
async def post_subscriptions(
        subscription_data: SubscriptionRequest,
        db: AsyncSession = Depends(get_async_session),
        user: User = Depends(current_active_user),
        subscription: SubscriberServiceProtocol = Depends(
            get_subscription_service)
):
    try:
        await subscription.subscribe(db, user.id, subscription_data.stream_id)
        return {
            "msg": "",
            "result": "success",
        }
    except Exception as e:
        raise (HTTPException(status_code=500,
                             detail=f"Failed to subscribe: {str(e)}"))


@router.delete("/me/subscriptions")
async def delete_subscriptions(
        subscription_data: SubscriptionRequest,
        db: AsyncSession = Depends(get_async_session),
        user: User = Depends(current_active_user),
        subscription: SubscriberServiceProtocol = Depends(
            get_subscription_service)
):
    try:
        await subscription.unsubscribe(
            db, user_id=user.id, stream_id=subscription_data.stream_id
        )
        return {
            "msg": "",
            "result": "success",
        }
    except Exception as e:
        raise (HTTPException(status_code=500,
                             detail=f"Failed to unsubscribe: {str(e)}"))


@router.post("/me/profile")
async def update_user_profile(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    user_crud: UserCRUDProtocol = Depends(get_user_crud),
    s3_manager: S3Manager = Depends(S3Manager),
):
    # 지원하지 않는 파일 형식 처리
    if file.content_type not in ["image/jpeg", "image/png", "image/webp"]:
        raise HTTPException(status_code=400, detail="File type not supported")

    try:
        # 기존 프로필 이미지 URL 가져오기
        current_profile_url = user.profile

        # 새로운 S3 경로 생성
        unique_url = generate_s3_key(f"profile/user_{user.id}", "profile.webp")

        # WebP 형식인지 확인
        if file.content_type == "image/webp":
            file.file.seek(0)  # 파일 포인터를 처음으로 이동
            profile_url = await s3_manager.upload_file(file, unique_url)
        else:
            # WebP가 아닌 경우 변환 후 업로드
            webp_file = convert_image_to_webp(file.file)
            profile_url = await s3_manager.upload_byte_file(webp_file, unique_url, "image/webp")

        # DB 업데이트
        user_update = UserUpdate(
            id=user.id,
            name=user.name,
            profile=profile_url,
        )
        await user_crud.update(db, user_update)

        # 기존 이미지 삭제 (DB 업데이트 후 실행)
        if current_profile_url:
            await s3_manager.delete_file(current_profile_url)
        return {"msg": "Profile updated successfully", "profile_url": profile_url}

    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")



@router.get("/{user_id}/profile", response_model=UserPublicRead)
async def get_user_profile(
        user_id: int,
        db: AsyncSession = Depends(get_async_session),
        user_crud: UserCRUDProtocol = Depends(get_user_crud)
):
    try:
        user: UserRead = await user_crud.get(db, user_id)
        user = UserPublicRead(
            id=user.id,
            name=user.name,
            gender=user.gender,
            profile=user.profile
        )
        return user
    except Exception as e:
        raise (HTTPException(status_code=500,
                             detail=f"Failed to fetch user profile: {str(e)}"))
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
    s3_manager: S3Manager = Depends(S3Manager)
):
    # 지원하지 않는 파일 형식 처리
    if file.content_type not in ["image/jpeg", "image/png"]:
        raise HTTPException(status_code=400, detail="File type not supported")

    try:
        # WebP 변환 및 S3 업로드
        profile_url = await s3_manager.save_image_as_webp_to_s3(file, user.id)

        # DB 업데이트
        user_update = UserUpdate(
            id=user.id,
            name=user.name,
            profile=profile_url,
        )
        await user_crud.update(db, user_update)

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
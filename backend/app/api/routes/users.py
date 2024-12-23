from fastapi import APIRouter
from fastapi.params import Depends
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.crud.user_crud import UserFCMTokenCRUDProtocol, get_user_fcm_token_crud
from app.models import User
from app.schemas.stream import SubscriptionRequest
from app.schemas.user import UserFCMTokenCreate, UserFCMTokenRequest
from app.service.stream import SubscriberServiceProtocol, \
    get_subscription_service

router = APIRouter()

from fastapi import HTTPException


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


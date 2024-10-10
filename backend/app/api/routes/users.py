from fastapi import APIRouter
from fastapi.params import Depends
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.models import User
from app.schemas.stream import SubscriptionRequest
from app.service.stream import SubscriberServiceProtocol, \
    get_subscription_service

router = APIRouter()

from fastapi import HTTPException


@router.get("/me/subscriptions")
async def get_subscriptions(
        db: AsyncSession = Depends(get_async_session),
        user: User = Depends(current_active_user),
        subscriptions_service: SubscriberServiceProtocol = Depends(
            get_subscription_service),
):
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

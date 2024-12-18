from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_async_session
from app.core.security import current_active_user
from app.models import User
from app.schemas.stream import StreamCreate, StreamRead, StreamRequest
from app.service.stream import StreamServiceProtocol, get_stream_service, \
    ActiveStreamServiceProtocol, get_active_stream_service

router = APIRouter()


@router.post("/create", response_model=StreamRead, status_code=201)
async def create_stream(
        stream_request: StreamRequest,
        db: AsyncSession = Depends(get_async_session),
        stream_service: StreamServiceProtocol = Depends(get_stream_service),
        user: User = Depends(current_active_user)
):
    merge_create = StreamCreate(**stream_request.model_dump(),
                                creator_id=user.id)
    new_stream = await stream_service.create_stream(db, merge_create)
    return new_stream

@router.post("/{stream_id}/active",
             status_code=200,
             summary="현재 활성화된 채팅방 설정",
             description="""
사용자가 특정 스트림(채팅방)을 활성 상태로 설정합니다.

활성화된 스트림은 사용자가 현재 집중하여 보고 있는 채팅방을 의미합니다.
이를 통해 서버는 사용자의 활성 채팅방 이외의 채팅방에 대한 새로운 메시지나 이벤트에 대해서는 별도의 알림(푸시, FCM 등)을 보낼 수 있고,
활성 채팅방은 실시간 업데이트(웹소켓 등)만 제공하여 중복된 알림을 피할 수 있습니다.

- **stream_id**: 활성화하려는 스트림 ID
- 성공 시: `{"detail": "Stream activated"}`
""")
async def active_stream(
    stream_id: int,
    active_stream_service: ActiveStreamServiceProtocol = Depends(get_active_stream_service),
    user: User = Depends(current_active_user)
):
    """
    현재 유저를 위해 지정된 스트림을 활성화합니다.
    """
    await active_stream_service.set_active_stream(user.id, stream_id)
    return {"detail": "Stream activated"}


@router.post("/deactive",
             status_code=200,
             summary="현재 활성화된 채팅방 해제",
             description="""
사용자의 현재 활성화된 채팅방 상태를 해제하는 엔드포인트입니다.

기존에는 활성화 상태(`active`)를 통해 사용자가 집중하고 있는 채팅방을 서버가 알 수 있었습니다.
이제 `deactive`를 호출하면, 해당 사용자는 더 이상 어떤 채팅방도 활성 상태로 두지 않게 됩니다.

이를 통해 서버는 사용자가 현재 채팅방을 보고 있지 않다고 판단하여, 해당 채팅방에 대한 알림을 다시 보낼 수 있습니다.

- **stream_id**: 비활성화하려는 스트림 ID
- 성공 시: `{"detail": "Stream deactivated"}`
""")
async def clear_active_stream(
    active_stream_service: ActiveStreamServiceProtocol = Depends(get_active_stream_service),
    user: User = Depends(current_active_user)
):
    """
    현재 활성화 상태를 해제하여 더 이상 사용자가 특정 채팅방을 활성 상태로 보지 않도록 합니다.
    """
    await active_stream_service.deactive_stream(user.id)
    return {"detail": "Stream deactivated"}
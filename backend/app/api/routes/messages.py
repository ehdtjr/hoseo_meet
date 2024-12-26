from typing import List

from fastapi import APIRouter
from fastapi import HTTPException
from fastapi.params import Depends, Form
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_async_session
from app.core.exceptions import PermissionDeniedException
from app.core.security import current_active_user
from app.models import User
from app.schemas.message import (MessageBase, UpdateUserMessageFlagsRequest,
LocationBase)
from app.service.location import get_location_service, LocationService
from app.service.message import MessageServiceProtocol, get_message_service, \
    MessageSendService, get_message_send_service

router = APIRouter()


@router.post("/flags/stream")
async def update_message_flags(
        request: UpdateUserMessageFlagsRequest,
        db: AsyncSession = Depends(get_async_session),
        user: User = Depends(current_active_user),
        message_service: MessageServiceProtocol = Depends(get_message_service)
):
    """
    주어진 앵커를 기준으로 메시지 범위 내에 읽음 상태를 업데이트하는 API.
    사용자 권한을 확인한 후, 메시지를 읽음 처리함.
    """
    try:
        result = await message_service.mark_message_read_stream(
            db=db,
            stream_id=request.stream_id,
            user_id=user.id,
            anchor=request.anchor,
            num_before=request.num_before,
            num_after=request.num_after
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=400,
                            detail=f"Message flag update failed: {str(e)}")


@router.post("/send/stream/{stream_id}", response_model=None)
async def send_message_to_stream(
        stream_id: int,
        message_content: str = Form(...,
                                    description="The content of the message"),
        db: AsyncSession = Depends(get_async_session),
        user: User = Depends(current_active_user),
        message_send_service: MessageSendService = Depends(get_message_send_service)
):
    try:
        await message_send_service.send_message_stream(
            db=db, sender_id=user.id, stream_id=stream_id, message_content=message_content)
        return {"message": "Message sent successfully"}

    except PermissionDeniedException:
        raise HTTPException(status_code=403,
                            detail="You are not allowed to send messages to "
                                   "this stream")
    except Exception as e:
        raise HTTPException(status_code=400,
                            detail=f"Message sending failed: {str(e)}")

@router.get("/stream", response_model=List[MessageBase])
async def get_messages(
        stream_id: int,
        anchor: str = "first_unread",  # 앵커 기본값을 "first_unread"로 설정
        num_before: int = 100,  # 앵커 이전 메시지 개수
        num_after: int = 100,  # 앵커 이후 메시지 개수
        db: AsyncSession = Depends(get_async_session),
        user: User = Depends(current_active_user),
        message_service: MessageServiceProtocol = Depends(get_message_service)
):
    """
    주어진 stream_id의 메시지를 가져오는 API.
    사용자 권한을 확인한 후, 메시지를 앵커 기준으로 가져옴.
    """
    # 메시지 서비스 호출하여 스트림 메시지 가져오기
    try:
        messages = await message_service.get_stream_messages(
            db=db,
            user_id=user.id,
            stream_id=stream_id,
            anchor=anchor,
            num_before=num_before,
            num_after=num_after
        )
        if not messages:
            return []
        return messages
    except PermissionDeniedException as e:
        raise HTTPException(status_code=403, detail=str(e))
    except HTTPException as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/send/stream/location/{stream_id}", response_model=None)
async def send_message_to_location(
    stream_id: int,
    location: LocationBase,  # Body로 받은 lat, lng
    db: AsyncSession = Depends(get_async_session),
    user: User = Depends(current_active_user),
    location_service: LocationService = Depends(get_location_service),
):
    """
    위도/경도 등 위치 정보를 포함한 이벤트를 전송.
    """
    await location_service.send_location_stream(
        db=db,
        user_id=user.id,
        stream_id=stream_id,
        location=location
    )
    return {"detail": "Location event sent successfully"}
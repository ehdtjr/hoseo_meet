
from fastapi import APIRouter
from fastapi.params import Depends
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.db import get_async_session

router = APIRouter()

@router.get("/ping")
async def ping(
    db: AsyncSession = Depends(get_async_session)
):
    return {"message": "pong"}

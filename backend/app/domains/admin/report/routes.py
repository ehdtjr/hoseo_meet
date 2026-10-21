from http.client import HTTPException
from typing import List, Optional

from fastapi import APIRouter
from fastapi.params import Depends
from sqlalchemy.ext.asyncio.session import AsyncSession

from app.core.db import get_async_session
from app.core.security import current_admin_user
from app.crud.user import UserReportCRUD, \
    get_user_report_crud
from app.models import User
from app.schemas.user import UserReportBase

router = APIRouter()

@router.get("/list", response_model=Optional[List[UserReportBase]])
async def list_users(
    skip: int = 0,
    limit: int = 30,
    is_resolved: Optional[bool] = None,
    user: User = Depends(current_admin_user),
    db: AsyncSession = Depends(get_async_session),
    user_report_crud: UserReportCRUD = Depends(get_user_report_crud),
):
    return await user_report_crud.list(db, skip, limit, is_resolved)

@router.post("/update", response_model=UserReportBase)
async def update_user_report(
    request: UserReportBase,
    user: User = Depends(current_admin_user),
    db: AsyncSession = Depends(get_async_session),
    user_report_crud: UserReportCRUD = Depends(get_user_report_crud),
):
    try:
        updated_report = await user_report_crud.update(db, request)
        return updated_report
    except HTTPException as e:
        raise HTTPException(status_code=500, detail=e)

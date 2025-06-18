from typing import List, Optional

from fastapi import APIRouter
from fastapi.params import Depends
from sqlalchemy.ext.asyncio.session import AsyncSession

from app.core.db import get_async_session
from app.core.security import current_admin_user
from app.crud.user import UserCRUDProtocol, get_user_crud
from app.models import User
from app.schemas.user import UserRead, UserUpdate

router = APIRouter()

@router.get("/list", response_model=List[UserRead])
async def list_users(
    skip: int = 0,
    limit: int = 30,
    user_name_key: Optional[str] = None,
    user: User = Depends(current_admin_user),
    db: AsyncSession = Depends(get_async_session),
    user_crud: UserCRUDProtocol = Depends(get_user_crud),
):
    return await user_crud.get_user_list(db, skip=skip, limit=limit, keyword=user_name_key)

@router.post("/update")
async def update_user(
    update_user: UserUpdate,
    user: User = Depends(current_admin_user),
    db: AsyncSession = Depends(get_async_session),
    user_crud: UserCRUDProtocol = Depends(get_user_crud),
):
    return await user_crud.update(db, update_user)
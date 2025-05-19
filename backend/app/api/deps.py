from fastapi import Depends
from fastapi_users_db_sqlalchemy import SQLAlchemyUserDatabase
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_async_session
from app.models.user import User
from fastapi.templating import Jinja2Templates


templates = Jinja2Templates(directory="app/templates")

async def get_user_db(session: AsyncSession = Depends(get_async_session)):
    yield SQLAlchemyUserDatabase(session, User)

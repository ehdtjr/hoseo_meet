from pydantic_core import MultiHostUrl
from sqlalchemy import create_engine, delete
from sqlalchemy.orm import sessionmaker
from app.core.config import settings


def SQLALCHEMY_DATABASE_URI() -> MultiHostUrl:
    return MultiHostUrl.build(
        scheme="postgresql",
        username=settings.POSTGRES_USER,
        password=settings.POSTGRES_PASSWORD,
        host=settings.POSTGRES_SERVER,
        port=settings.POSTGRES_PORT,
        path=settings.POSTGRES_DB,
    )


sync_engine = create_engine(
    str(SQLALCHEMY_DATABASE_URI()),
    pool_size=20,
    max_overflow=10,
)

sync_session_maker = sessionmaker(
    sync_engine,
    expire_on_commit=False,
)

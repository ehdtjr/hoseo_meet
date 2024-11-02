import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.routing import APIRoute
from starlette.middleware.cors import CORSMiddleware

from app.api.main import api_router
from app.core.config import settings
from app.core.redis import redis_client

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def custom_generate_unique_id(route: APIRoute) -> str:
    return f"{route.tags[0]}-{route.name}"


@asynccontextmanager #비동기 컨텍스트 관리자 정의
async def lifespan(app: FastAPI):
    logger.info("Starting application lifespan and connecting to Redis.")
    await redis_client.get_connection()  # Redis 연결
    try:
        yield
    except asyncio.CancelledError:
        logger.warning("Application lifespan task was cancelled.")
    finally:
        logger.info("Ending application lifespan and closing Redis connection.")
        await redis_client.close_connection()  # 종료 시 연결 해제


app = FastAPI(
    lifespan=lifespan,
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    generate_unique_id_function=custom_generate_unique_id,
)

# Set all CORS enabled origins
if settings.BACKEND_CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            str(origin).strip("/") for origin in settings.BACKEND_CORS_ORIGINS
        ],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(api_router, prefix=settings.API_V1_STR)

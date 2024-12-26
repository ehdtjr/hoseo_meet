import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.routing import APIRoute
from prometheus_fastapi_instrumentator import Instrumentator
from starlette.middleware.cors import CORSMiddleware

from app.api.main import api_router
from app.core.config import settings
from app.core.redis import redis_client
from app.middlewares import register_profile_middleware

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

instrumentator = Instrumentator()

@asynccontextmanager  # 비동기 컨텍스트 관리자 정의
async def lifespan(app: FastAPI):
    logger.info("Starting application lifespan and connecting to Redis.")
    await redis_client.get_connection()  # Redis 연결
    instrumentator.expose(app, include_in_schema=False, should_gzip=True)  # Prometheus 메트릭 노출
    try:
        yield
    except asyncio.CancelledError:
        logger.warning("Application lifespan task was cancelled.")
    finally:
        logger.info("Ending application lifespan and closing Redis connection.")
        await redis_client.close_connection()  # 종료 시 연결 해제


def custom_generate_unique_id(route: APIRoute) -> str:
    if route.tags:
        return f"{route.tags[0]}-{route.name}"
    return route.name  # tags가 없는 경우 route 이름만 사용


app = FastAPI(
    lifespan=lifespan,
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    generate_unique_id_function=custom_generate_unique_id,
)


register_profile_middleware(app) # 프로파일링 미들웨어 등록


# Prometheus Instrumentator 초기화
instrumentator.instrument(app)

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

# 라우터 추가
app.include_router(api_router, prefix=settings.API_V1_STR)

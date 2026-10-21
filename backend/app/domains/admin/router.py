from fastapi import APIRouter

from .users import routes as users_router
from .report import routes as report_router


admin_router = APIRouter()

admin_router.include_router(users_router.router, prefix="/user")
admin_router.include_router(report_router.router, prefix="/report")
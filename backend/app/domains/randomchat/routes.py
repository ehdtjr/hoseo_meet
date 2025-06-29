from fastapi import APIRouter, Depends

from app.core.security import current_active_user
from app.models import User

router = APIRouter()

@router.post("/match/queue/join")
async def match_queue_join(
    user: User = Depends(current_active_user),
):
        ...
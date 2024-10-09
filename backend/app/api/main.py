from fastapi import APIRouter

from app.api.routes import auth, events, messages, stream, users

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(stream.router, prefix="/stream", tags=["stream"])
api_router.include_router(events.router, prefix="/events", tags=["events"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(messages.router, prefix="/messages",
                          tags=["messages"])

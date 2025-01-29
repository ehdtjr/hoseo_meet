from fastapi import APIRouter

from app.api.routes import (
    auth,
    meet_post,
    messages,
    stream,
    users,
    oauth,
    websocket,
    room_post,
    story_post,
)


api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(oauth.router, prefix="/oauth", tags=["oauth"])
api_router.include_router(stream.router, prefix="/stream", tags=["stream"])
api_router.include_router(websocket.router, prefix="/events", tags=["events"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(messages.router, prefix="/messages", tags=["messages"])
api_router.include_router(
    meet_post.router, prefix="/meet_post", tags=["meet_post"]
)
api_router.include_router(
    room_post.router, prefix="/room_post", tags=["room_post"]
)
api_router.include_router(
    story_post.router, prefix="/story_post", tags=["story_post"]
)

from fastapi import APIRouter

from app.api.routes import auth, websocket, meet_post_routes, messages, stream, \
    users, test_route

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(stream.router, prefix="/stream", tags=["stream"])
api_router.include_router(websocket.router, prefix="/events", tags=["events"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(messages.router, prefix="/messages",
                          tags=["messages"])
api_router.include_router(meet_post_routes.router, prefix="/meet_post",
tags=["meet_post"])

api_router.include_router(test_route.router, prefix="/test", tags=["test"])

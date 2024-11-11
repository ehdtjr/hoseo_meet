from fastapi import APIRouter

from app.api.routes import auth, events, meet_post_routes, messages, stream, \
    users,oauth

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(oauth.router, prefix="/oauth", tags=["oauth"])
api_router.include_router(stream.router, prefix="/stream", tags=["stream"])
api_router.include_router(events.router, prefix="/events", tags=["events"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(messages.router, prefix="/messages",
                          tags=["messages"])
api_router.include_router(meet_post_routes.router, prefix="/meet_post",tags=["meet_post"])

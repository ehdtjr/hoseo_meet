from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from app.api.deps import templates

router = APIRouter()

@router.get("/privacy-policy", response_class=HTMLResponse)
async def privacy_policy(request: Request):
    return templates.TemplateResponse("privacy_policy.html", {"request": request})

# app/middlewares.py
from fastapi import FastAPI, Request
from typing import Callable
from pyinstrument import Profiler
from pyinstrument.renderers.html import HTMLRenderer
from pyinstrument.renderers.speedscope import SpeedscopeRenderer

def register_profile_middleware(app: FastAPI):
    @app.middleware("http")
    async def profile_middleware(request: Request, call_next: Callable):
        # ?profile=true 로 들어온 요청만 프로파일링
        if request.query_params.get("profile", False):
            # profile_format 파라미터가 없으면 speedscope를 기본값으로
            profile_format = request.query_params.get("profile_format", "speedscope")

            with Profiler(interval=0.001, async_mode="enabled") as profiler:
                response = await call_next(request)

            # 결과 파일 출력
            if profile_format == "html":
                renderer = HTMLRenderer()
                filename = "profile.html"
            else:
                renderer = SpeedscopeRenderer()
                filename = "profile.speedscope.json"

            with open(filename, "w", encoding="utf-8") as f:
                f.write(profiler.output(renderer=renderer))

            return response
        else:
            return await call_next(request)

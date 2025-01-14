# app/middlewares.py
from fastapi import FastAPI, Request
from typing import Callable
from pyinstrument import Profiler
from pyinstrument.renderers.html import HTMLRenderer
from pyinstrument.renderers.speedscope import SpeedscopeRenderer


def register_profile_middleware(app: FastAPI):
    @app.middleware("http")
    async def profile_middleware(request: Request, call_next: Callable):
        # "?profile=true"가 쿼리 파라미터로 있으면, 해당 요청만 프로파일링
        if request.query_params.get("profile", False):
            # profile_format 파라미터: "html"이면 HTML 렌더링, 그 외에는 speedscope(JSON)
            profile_format = request.query_params.get("profile_format", "speedscope")

            # Pyinstrument 5.0 기준: timing(또는 clock_type) 인자 없음
            # interval=0.001은 1ms 간격으로 스택 샘플링
            # async_mode="enabled"로 await 구간을 CPU 점유 중인 함수에 기록
            with Profiler(interval=0.001, async_mode="enabled") as profiler:
                response = await call_next(request)

            # 결과 파일 생성
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
            # 프로파일링이 필요 없는 요청은 그냥 다음 미들웨어/엔드포인트로 진행
            return await call_next(request)

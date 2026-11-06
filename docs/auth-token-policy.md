# API 토큰 용도와 세션 정책

이슈 [#17](https://github.com/ehdtjr/hoseo_meet/issues/17)의 적용 범위는
`CustomJWTStrategy`를 사용하는 일반 API 인증과 refresh/logout 경로다.

## 용도 검증

- 일반 Bearer 인증의 `read_token`은 서명, 만료, audience와 `type=access`를
  검증한 뒤 사용자를 조회한다. 같은 reader를 사용하는 WebSocket 인증에도 적용된다.
- `/api/v1/auth/refresh`는 `type=refresh`를 검증하고, Redis에 저장된 토큰과
  정확히 일치하는 경우에만 갱신한다. access 토큰은 저장소에 넣어도 갱신에 사용할 수 없다.
- 두 경로 모두 `sub`, `exp`, `aud`, `type`을 필수로 요구한다.
  `sub`는 비어 있지 않은 문자열이어야 한다. 일반 인증은 사용자 ID 파싱과 사용자 존재 여부도 검사한다.
- 기존 발급 토큰과의 호환성을 위해 HS256, 키, `fastapi-users:auth` audience를 유지한다.
  서명된 `type` claim으로 용도를 구분하며, type이 없는 JWT는 일반 API 인증에 허용하지 않는다.
  이미 발급된 access와 Redis에 저장된 refresh는 만료 전까지 사용할 수 있다.
- `decode_token` 보조 메서드도 access만 허용한다. 이메일 인증과 비밀번호 재설정용
  별도 전략의 정책 변경은 이번 범위에 포함하지 않는다.

## 만료·회전·로그아웃·다중 기기

- 현재 설정에서 access는 1시간, refresh는 14일이다. 갱신 성공 시 두 토큰을 다시 발급한다.
- refresh에는 매번 새로운 `jti`를 넣어 같은 초 안에서도 서로 다른 토큰을 발급한다.
  갱신이 완료된 뒤 이전 refresh를 다시 제출하면 저장 값과 달라 거절된다.
  이전 형식의 refresh에는 `jti`가 없어도 기존 검증과 저장 값 일치를 통과하면 갱신할 수 있다.
- Redis 키는 `refresh_token:{user_id}`이며 계정당 하나의 refresh만 저장한다.
  새 기기 로그인은 이전 기기의 refresh를 대체한다. 기기별 독립 세션을 제공하지 않는다.
- 로그아웃은 유효한 access 인증을 요구하며 해당 계정의 저장된 refresh를 삭제한다.
  이전 기기의 아직 유효한 access로 로그아웃해도 현재 계정의 refresh가 삭제된다.
- access는 Redis 폐기 목록을 조회하지 않는다. 로그아웃·다른 기기 로그인·refresh 회전 후에도
  기존 access는 만료 시점까지 인증에 사용할 수 있다. 사용자 비활성화 등 엔드포인트의
  사용자 상태 검사는 계속 적용된다. **access 즉시 폐기는 제공하지 않는다.**
- refresh 확인과 재발급/저장은 현재 별도 연산이다. 이미 검증 중인 동시 갱신을 원자적으로
  차단하거나, 로그아웃과 경합하는 갱신 완료를 취소하는 정책은 구현하지 않았다.
  최종 저장 값과 일치하는 refresh만 후속 갱신에 사용할 수 있다.

## 회귀 검증

`backend/app/tests/router/test_auth.py`는 합성 계정과 전용 PostgreSQL/Redis에서
실제 ASGI HTTP 요청을 실행한다. 인증 dependency나 사용자 manager, JWT, 저장소를
대역으로 바꾸지 않으며, 회전 테스트에서만 시간을 고정한다.

```sh
python3 scripts/local_env.py  # 로컬 .env가 없는 경우에만 실행
docker compose build web
docker compose --profile test run --rm test
```

검증 항목은 정상 로그인/access/refresh, refresh를 Bearer로 제출한 요청 및 로그아웃 거절,
access의 refresh 사용 거절, 만료·서명 변조·잘못된 audience/type·필수 claim 누락,
저장소 폐기, 같은 초의 회전과 이전 토큰 재사용 거절, 다중 기기 대체, 로그아웃 후 access
유효성 유지, 기존 jti 없는 토큰의 호환성, 비활성/없는 사용자와 인증 누락이다.

2026-11-06 로컬 검증 환경: Python 3.10, fastapi-users 13.0.0, PyJWT 2.8.0,
FastAPI 0.115.12, HTTPX 0.27.2. 이미지의 `poetry.lock` SHA-256이 저장소의
`3a4225fbdfe1115c2c8042c04fdc12d888b52761d9c52caebdd4d5547ad8ab1f`와 일치함을 확인했다.
격리된 Compose 프로젝트에서 현재 소스를 읽기 전용으로 마운트하여 검증했다.
설치된 잠금 대상 패키지 228개의 버전 불일치는 0개였다.
전체 백엔드 테스트는 **135 passed, 3 warnings**였으며, 신규 인증 테스트 13개를 포함한다.
경고는 기존 Pydantic `Field(env=...)` 사용과 테스트 도우미 클래스 2개의 수집 경고다.
수정 전 전략을 별도로 마운트하면 refresh의 일반 API 인증 허용과 같은 초의 refresh
재발급 충돌을 검출하는 테스트 2개가 실패함도 확인했다. 변경 Python 파일 Ruff 검사와
`git diff --check`도 통과했다.
이 기록은 로컬 검증이며 원격 CI, 운영 배포, 실기기 검증을 의미하지 않는다.

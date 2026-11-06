# campus_meet

```sh
python3 scripts/local_env.py  # 로컬 .env가 없는 경우에만 생성
docker compose up -d
```

로컬 초기화 컨테이너는 저장소에 추적된 Alembic revision을 `head`까지 적용한 뒤
합성 사용자를 만든다. 모델 변경 시 시작 과정에서 revision을 자동 생성하지 않는다.
개발자가 변경 내용을 검토해 다음 revision을 추가한다.

```sh
cd backend
poetry install
poetry run alembic upgrade head
poetry run alembic revision --autogenerate -m "describe schema change"
```

생성된 migration의 upgrade와 downgrade를 검토한 뒤 커밋한다. Alembic 이력이 없는
기존 DB에는 먼저 기준 schema 검증과 adoption 절차가 필요하다.

## 로컬 실행 및 Kubernetes 전환

[로컬 환경 실행·테스트·Kubernetes·백업/복구 절차](docs/local-environment.md)

[DB migration·기존 DB adoption·실패 복구 정책](docs/database-migrations.md)

[채팅·위치 WebSocket 로그 정책과 검증](docs/websocket-logging.md)

[API 토큰 용도·회전·로그아웃·다중 기기 정책](docs/auth-token-policy.md)

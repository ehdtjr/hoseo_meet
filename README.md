# campus_meet
docker-compose up -d
cd backend
poetry install
poetry shell
alembic revision --autogenerate -m "init"
// 오류 발생 시 \backend\app\alembic 경로에 versions 폴더 생성
alembic upgrade head

## 로컬 실행 및 Kubernetes 전환

[로컬 환경 실행·테스트·Kubernetes·백업/복구 절차](docs/local-environment.md)

[채팅·위치 WebSocket 로그 정책과 검증](docs/websocket-logging.md)

[랜덤채팅 매칭 정책·API·DB 적용 절차](docs/randomchat-policy.md)

[메시지 원자적 저장·재처리·기존 DB 마이그레이션](docs/message-outbox.md)

[API 토큰 용도·회전·로그아웃·다중 기기 정책](docs/auth-token-policy.md)

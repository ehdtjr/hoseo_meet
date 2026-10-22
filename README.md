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

# campus_meet
docker-compose up -d
cd backend
poetry install
poetry shell
alembic revision --autogenerate -m "init"
// 오류 발생 시 \backend\app\alembic 경로에 versions 폴더 생성
alembic upgrade head

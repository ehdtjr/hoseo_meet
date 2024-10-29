from celery import Celery
from celery.schedules import crontab

from app.core.config import settings

app = Celery('app',
             broker=f"redis://{settings.REDIS_HOST}:{settings.REDIS_PORT}")

app.autodiscover_tasks(['app.celery.tasks'])
app.conf.beat_schedule = {
    'garbage-collection-every-10-minutes': {
        'task': 'app.celery.tasks.run_garbage_collection',  # tasks.py에 정의될 작업
        'schedule': crontab(minute='*/1'),  # 1분마다 실행
    },
}

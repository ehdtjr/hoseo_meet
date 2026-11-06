# 메시지 원자적 저장과 이벤트 재처리 (#22)

`MessageSendService`가 요청 세션의 트랜잭션을 소유한다. 인증 조회로 이미 열린 트랜잭션도 이 서비스가 commit/rollback하므로, 다른 쓰기 작업을 같은 세션에 섞지 않는다. 본문·전체 수신 상태·수신자별 outbox 중 하나라도 실패하면 전부 rollback한다. 메시지 전송용 CRUD는 개별 commit을 하지 않는다.

인증된 사용자와 `X-Client-Message-ID`를 묶어 PostgreSQL 트랜잭션 advisory lock으로 직렬화하고 unique index로 중복을 차단한다. 같은 ID로 다른 방·본문을 보내면 409다. 메시지 삭제 전까지 키를 유지한다. 헤더 없는 기존 클라이언트는 호환되지만 응답 유실 후 키 없는 재전송은 별개 메시지다. 상세 응답은 [클라이언트 계약](chat-send-contract.md)에 정의한다.

## 재처리와 전달 보장

API lifespan에서 Redis 라우팅과 FCM 전달을 독립적인 두 루프로 시작한다. `channel=route`에서 활성 사용자에게 Redis로 발행하고, 비활성 사용자의 작업은 DB에 `channel=fcm`으로 기록해 넘긴다. FCM이 지연되어도 새 Redis 이벤트 처리는 계속된다. DB를 1초 간격으로 확인하며 `FOR UPDATE SKIP LOCKED`로 여러 API 프로세스가 같은 row를 동시에 처리하지 않는다. 처리 중 프로세스가 죽으면 DB 연결의 트랜잭션/잠금이 해제되어 다른 worker가 복구한다. 각 처리에는 30초 제한을 두며, 실패하면 누적 시도 횟수에 따라 최대 300초까지 backoff한다. 재시도 횟수 제한이나 자동 삭제는 없다. DB 접속 오류도 루프를 종료하지 않고 재시도한다.

현재 활성 방에 있는 사용자는 Redis stream으로, 그 외 사용자는 FCM으로 전달한다. FCM은 Celery 등록만으로 완료 처리하지 않고 provider 응답의 메시지 이름을 확인한다. 사용자에게 등록된 모든 토큰을 대상으로 한다. 수신자별 row를 사용하므로 이미 완료한 다른 수신자에게 재발행하지 않는다. 전달 시점의 활성 방과 토큰을 사용한다. FCM 단계에서도 활성 방을 다시 확인해 사용자가 돌아왔으면 Redis로 전달한다.

FCM SDK 호출은 API 프로세스의 스레드에서 실행하지 않는다. 별도 Python 프로세스에 토큰·본문을 stdin으로 넘기고, 최대 25초 내에 완료되지 않으면 프로세스를 강제 종료하고 회수한다. API 작업 취소 시에도 프로세스 생성 완료 및 종료를 확인한 뒤 DB 잠금을 해제하므로 실행 중인 SDK 호출과 새 재시도가 겹치지 않는다. Linux에서는 부모 프로세스 사망 시 자식도 종료되도록 설정한다. SDK 출력은 전달하지 않으며 자식 실패는 고정된 `FCMDeliveryError`로 기록한다. 한 수신자의 여러 토큰은 자식 안에서 최대 4개씩 병렬 처리한다.

- `redis_accepted`: Redis stream에 이벤트가 들어갔음. Lua로 enqueue와 중복 방지 marker를 원자적으로 기록한다. marker는 7일 유지한다.
- `fcm_accepted`: FCM이 전송을 수락했음. 휴대폰 표시·수신 확인이 아니다.
- `fcm_disabled` / `no_fcm_token`: 전송 생략 사유를 남기고 완료한다. 이후 FCM을 켜거나 토큰을 등록해도 과거 알림을 자동 발송하지 않는다.

HTTP `delivery_status=completed`는 모든 수신자의 처리가 위 결과 중 하나로 끝났다는 뜻이다. 사용자 읽음 상태와는 별개다. `message_outbox`의 `channel`, `attempts`, `available_at`, `completed_at`, `outcome`, `last_error`가 운영 상태다. 오류는 예외 클래스명만 저장·기록하고 본문·토큰·원본 예외 텍스트를 로그에 남기지 않는다.

메시지 저장은 키당 한 번이지만 외부 전달은 **at-least-once**다. FCM 수락 직후 DB commit 전 프로세스가 죽거나 다중 토큰 중 일부가 실패하면 재시도 알림이 중복될 수 있다. Redis marker 소실/7일 경과 후에도 이벤트가 중복될 수 있다. 이벤트의 서버 `id`로 클라이언트가 메시지를 병합하며, FCM data에 `message_id`도 넣는다. Redis stream은 영구 이력이 아니므로 접속 복구는 기존 HTTP 메시지 조회를 사용한다. 재시도 때문에 이벤트가 역순으로 도착할 수 있으므로 Flutter 방 목록의 미리보기는 도착한 이벤트 대신 병합된 메시지 중 가장 큰 서버 ID를 기준으로 갱신한다. 각 이벤트의 읽음 처리는 원래 ID를 유지한다.

## 기존 DB schema 편입

outbox schema는 Alembic `20261106_0003` revision에 추적된다. 빈 DB와 로컬 환경은
`local_init`이 `upgrade head`를 실행해 설치한다. staging/production API 시작은 schema를
자동 변경하지 않는다. 새 API를 시작하기 전에 쓰기를 중지하고 [공통 백업·복구
정책](database-migrations.md#백업과-적용)에 따라 복원본을 검증한 뒤 명시적으로
migration을 실행한다. unique index 생성 중에는 대상 테이블 쓰기가 잠시 대기할 수 있다.

Alembic 이력이 있는 DB는 독립 outbox 스크립트를 실행하지 않고 일반 upgrade 경로를
사용한다.

```sh
# DB가 실행 중이고 새 web 이미지를 빌드한 상태
docker compose run --rm --no-deps web alembic current
docker compose run --rm --no-deps web alembic upgrade head
docker compose run --rm --no-deps web alembic current
```

테이블은 있지만 Alembic 이력이 없는 DB는 현재 schema를 먼저 검증하고 정확히 일치하는
`20261106_0001`, `0002` 또는 `0003`을 기록한 뒤 upgrade한다. `0001`/`0002`로 편입한
DB에는 `0003`이 outbox 객체를 추가하고, 이미 현재 outbox schema와 일치하는 DB는
`0003`에 편입되어 upgrade가 no-op이 된다.

```sh
docker compose run --rm --no-deps web python -m app.scripts.adopt_legacy_db
docker compose run --rm --no-deps web alembic upgrade head
docker compose run --rm --no-deps web alembic current
```

이전 독립 migration의 일부만 적용되어 adoption이 실패한 알려진 outbox schema에는
`migrate_message_outbox`를 pre-adoption 복구 도구로 유지한다. adoption 실패만으로 이
명령을 실행하지 않는다. 백업 복원본에서 차이가 `message.client_message_id`,
`message_sender_client_id`, `message_outbox`, `channel`과 pending index에만 한정됨을
확인한 경우에만 변경 창에서 실행한다.

```sh
docker compose run --rm --no-deps web python -m app.scripts.migrate_message_outbox
docker compose run --rm --no-deps web python -m app.scripts.adopt_legacy_db
docker compose run --rm --no-deps web alembic upgrade head
```

복구 도구는 트랜잭션 안에서 누락된 nullable `message.client_message_id`, unique index,
outbox 테이블, `channel` 컬럼과 대기 작업 index를 additive하게 보완한다. 반복 실행할 수
있고 기존 메시지를 변경하거나 과거 이벤트를 생성하지 않지만, 알려지지 않은 schema
차이를 고치거나 Alembic 이력을 기록하지 않는다. 애플리케이션 시작 과정이나 운영
entrypoint에서 자동 실행하지 않는다.

코드를 rollback해도 추가 schema는 그대로 둘 수 있지만 이전 서버는 키를 사용하지 않아
중복 방지를 제공하지 않는다. pending 이벤트는 outbox worker가 다시 시작될 때까지 DB에
보존된다. 운영 downgrade 대신 forward fix 또는 검증한 백업 복원을 사용한다.

## 운영 확인

```sql
SELECT outcome, count(*) FROM message_outbox
WHERE completed_at IS NOT NULL GROUP BY outcome;

SELECT id, message_id, user_id, channel, attempts, available_at, last_error,
       now() - created_at AS age
FROM message_outbox WHERE completed_at IS NULL ORDER BY created_at;
```

오래된 pending 증가와 반복 오류를 모니터링한다. 의존 서비스를 복구하면 자동 재처리한다. 필요하면 선택한 pending row의 `available_at`만 `now()`로 바꿔 즉시 재시도한다. 메시지 본문이나 수신 상태를 재삽입하지 않는다. 완료 row에는 본문 snapshot이 남으므로 메시지 데이터와 같은 접근·보존 정책을 적용한다. 원본 메시지/사용자 삭제 시 outbox도 DB cascade로 제거한다.

## 재현 테스트

```sh
python3 scripts/local_env.py  # .env가 없을 때만
COMPOSE_PROJECT_NAME=hoseo-issue22 docker compose build web
COMPOSE_PROJECT_NAME=hoseo-issue22 docker compose --profile test run --rm test \
  python -m pytest app/tests/service/test_message_outbox.py app/tests/service/test_message_fcm.py \
  -q -W error::RuntimeWarning
```

테스트는 전용 `test_db` PostgreSQL/PostGIS와 별도 Redis를 사용한다. 실제 CRUD에 수신 상태 부분 실패·outbox 실패를 주입하고, 동시 재전송·HTTP 응답·키 충돌·Redis 실패·합성 FCM provider 실패를 검사한다. 별도 자식 프로세스를 Redis 발행 직후 강제 종료하고 다른 프로세스로 재시작해 pending 복구 및 Redis 중복 방지를 확인한다. legacy outbox 복구 도구의 반복 실행과 데이터 보존도 확인한다. Alembic `0003`의 빈 DB 설치·기존 DB 편입·drift 검사는 [migration 통합 suite](database-migrations.md#자동-검증-범위)에서 수행한다. FCM 지연 중 Redis 진행, 실제 자식 프로세스 타임아웃·취소·생성 중 취소 후 회수, FCM 단계의 재시작 복구를 추가 검증한다. Flutter 테스트는 102 → 101 → 102 이벤트에서 최신 미리보기·시간·메시지 정렬을 유지하면서 102와 101을 각각 한 번씩 읽음 처리하는지 검사한다. 실제 Firebase와 기기 수신은 이 테스트 범위에 포함되지 않는다.

2026-11-06 리뷰 반영 후 로컬 검증: `hoseo-issue22` Compose 프로젝트의 전용 PostGIS 16-3.5/Redis 7에서 전체 백엔드 **143개 통과**, 마지막 프로세스 생성 중 취소 보완 후 FCM 회귀 테스트 **5개 통과**. 기존 의존성 이미지에 현재 `backend/app`을 읽기 전용 마운트해 실행했다. Flutter 3.32.1의 전체 테스트 **71개**, 변경 파일 정적 분석, debug bundle 빌드도 통과했다. 새 Python 파일의 Ruff 검사, 기존 CRLF를 고려한 `git -c core.whitespace=cr-at-eol diff --check`, Compose 구성 검사와 tracked credential 검사도 통과했다. 기존 Pydantic deprecation 및 테스트 helper 클래스 수집 경고는 남아 있다. CI 실행·운영 배포·실제 FCM 기기 수신 결과는 아니다.

위 수치는 독립 outbox migration을 사용하던 #22 구현의 역사적 검증이다. `0003` Alembic
편입 뒤 새 이미지의 migration suite는 **24개**, 현재 코드의 전체 backend suite는
**193개** 통과했다. 현재 `head`의 합성 메시지와 pending outbox를 `pg_dump -Fc` 백업에서
새 DB로 복원한 뒤에도 보존됨을 확인했다. 자세한 범위와 경고, checksum은 [DB migration
통합 결과](database-migrations.md#0003-outbox-통합-검증)에 기록했다. 원격 CI, 운영 DB
적용과 실제 FCM 기기 수신 결과는 아니다.

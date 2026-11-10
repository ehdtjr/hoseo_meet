# DB migration과 기존 DB adoption

DB schema의 기준은 `backend/app/alembic/versions`에 추적된 Alembic revision이다.
애플리케이션 시작 과정은 revision을 만들거나 `Base.metadata.create_all()`로 기존 DB를
변경하지 않는다. 새 revision은 모델 변경과 함께 검토하고 커밋한다.

## DB 상태별 절차

명령은 대상 환경 변수를 설정한 뒤 `backend` 디렉터리에서 실행한다. 실행 전에
`POSTGRES_SERVER`, `POSTGRES_DB`, `POSTGRES_USER`, `ENVIRONMENT`이 의도한 전용 DB를
가리키는지 확인한다.

### 빈 DB

```sh
poetry run alembic upgrade head
poetry run alembic current
```

로컬 Compose와 로컬 Kubernetes의 `local_init`도 이 upgrade를 먼저 실행한 뒤 합성
사용자를 추가한다. 같은 DB에서 다시 실행하면 적용할 새 revision이 없으므로 schema를
다시 만들지 않는다.

### Alembic 이력이 있는 DB

백업과 복원 연습을 마친 뒤 다음 revision을 적용한다.

```sh
poetry run alembic current
poetry run alembic history --verbose
poetry run alembic upgrade head
poetry run alembic current
```

현재 revision이 저장소에 없거나 여러 head가 예상치 않게 나타나면 적용하지 말고 코드와
DB의 출처부터 확인한다.

### 테이블은 있지만 Alembic 이력이 없는 기존 DB

이 경우 `upgrade head`를 바로 실행하면 기준 revision이 기존 테이블을 다시 만들려고
시도한다. 먼저 별도 백업을 만들고 복원 가능한지 확인한 다음 adoption 도구를 실행한다.

```sh
poetry run python -m app.scripts.adopt_legacy_db
poetry run alembic current
poetry run alembic upgrade head
```

adoption 도구는 실제 schema가 지원하는 동결 revision과 정확히 같은 경우에만 일치하는
revision을 stamp한다. stamp는 애플리케이션 테이블이나 데이터를 변경하지 않고
`alembic_version` 테이블을 생성해 이력만 기록한다. 테이블, 컬럼, 타입, 제약, 인덱스에
누락이나 추가가 있으면 아무것도 기록하지 않고 실패한다.
차이를 확인하지 않은 수동 `alembic stamp`나 schema 검사를 우회한 stamp는 금지한다.
현재 지원하는 기존 schema는 `profile_media` 도입 전 기준인 `20261106_0001`, 해당
테이블까지 이미 있는 `20261106_0002`, 메시지 중복 방지와 outbox 객체까지 있는
`20261106_0003`, random-chat queue까지 있는 `20261106_0004`, story media까지 있는
`20261108_0005`, AI 태깅 체크포인트까지 있는 `20261110_0006`이다. 도구는 이 중 정확히
일치하는 revision을 기록하며, 그 밖의 부분 일치 상태를 임의로 추정하지 않는다.

이전 outbox 독립 migration을 일부 적용한 DB는 지원하는 동결 schema 중 어느 것과도
일치하지 않을 수 있다. 이 경우 adoption 오류를 무시하거나 직접 stamp하지 않는다.
차이가 알려진 outbox 객체에만 한정되는지 백업 복원본에서 확인한 뒤 [outbox 기존 schema 복구
절차](message-outbox.md#기존-db-schema-편입)를 사용한다. 복구 도구는 Alembic 이력을
기록하지 않으므로 복구 후에도 adoption과 `upgrade head`를 순서대로 실행해야 한다.

이전 random-chat 독립 migration을 적용한 unversioned DB도 [random-chat 기존 schema
편입 절차](randomchat-policy.md#기존-db-schema-편입)를 따른다. 정상 `0001`–`0003`
schema에는 먼저 adoption을 실행한 뒤 `upgrade head`로 `0004`를 적용한다. legacy helper는
queue가 없고 나머지가 `0003`과 일치하는 DB에서 이전 배포 절차와의 호환이 꼭 필요할
때만 adoption 전에 명시적으로 사용한다. 이미 존재하는 queue schema의 drift는 고치지
않는다.

## 관리 범위와 schema 비교

애플리케이션 migration은 PostgreSQL의 `public` schema만 관리한다. PostGIS가 소유하는
`spatial_ref_sys`와 extension 내부 객체, `tiger`/`topology` schema는 revision이나 drift
대상에 포함하지 않는다. 별도 schema, view, trigger, policy, grant, 함수와 extension
버전은 각 환경의 운영 점검에서 관리한다.

`20261106_0001`은 당시 SQLAlchemy metadata를 revision 안에 동결한 기준 schema다.
빈 DB의 테이블은 이 정의를 통해 생성하며 실행 시점의 애플리케이션 모델을 `create_all`
하지 않는다. 이후 변경은 `20261106_0002`, `20261106_0003`처럼 앞 revision을 잇는
별도 파일로 적용한다. `20261106_0003`은 `message.client_message_id`, 발신자별 중복
방지 index와 `message_outbox`를 버전 이력에 편입한다. `20261106_0004`는
`random_chat_queue`와 FIFO·만료 index를 편입한다. `20261108_0005`는 story media
소유권을, `20261110_0006`은 [AI 태깅 체크포인트](ai-tagging-recovery.md)를 추가한다.
`0006`은 다음 QA를 탐색하는 사용자·메시지 ID 복합 인덱스도 추가한다.
기존 태그를 완료 증거로 추정하거나 변경하지 않으며 체크포인트는 빈 상태로 시작한다.

표준 `alembic check`는 Alembic autogenerate가 지원하는 테이블, 컬럼, 타입, 제약과
인덱스 차이를 검사한다. CHECK 식, PostgreSQL enum label, generated 식, primary key와
partial-index 조건/방식은 표준 비교만으로 항상 검출되지 않는다. 기존 DB adoption과 CI
통합 검사는 저장소의 엄격 비교기를 함께 실행한다. 이 비교 경계 밖의 운영 객체까지
검증했다고 해석하지 않는다.

SERIAL primary key는 기본값이 해당 컬럼에 소유권이 연결된 시퀀스의 `nextval`인지
확인한다. 시퀀스의 schema, 정수 타입과 시작값·증가량·범위·cache·cycle 설정도 기준
정의와 비교한다. 시퀀스 이름 변경은 허용하며 현재 값은 읽거나 증가시키지 않는다.

`alembic upgrade head --sql`로 생성하는 offline SQL도 트랜잭션 안에서 먼저
`SET LOCAL search_path TO public`을 적용한다. 따라서 실행 세션의 기본 schema와
관계없이 온라인 migration과 같은 public schema에 테이블·타입·버전 이력을 만든다.

## 새 revision 작성

모델을 바꾼 개발자는 최신 revision을 적용한 전용 개발 DB에서 초안을 만든다.

```sh
poetry run alembic upgrade head
poetry run alembic revision --autogenerate -m "describe schema change"
poetry run alembic upgrade head
poetry run alembic check
```

생성된 Python 파일에서 upgrade 순서, NULL/기본값 전환, 외래 키와 인덱스 이름, 데이터
변환을 직접 검토한다. 데이터 변환이 필요하면 DDL과 데이터 이동의 실패 단위를 명확히
하고 합성 기존 행으로 검증한다. 애플리케이션 시작이나 배포 과정에서 `revision
--autogenerate`를 실행하지 않는다.

## 백업과 적용

로컬 관리 환경은 [백업·복원 절차](local-environment.md#영속성-및-백업복구)를 사용한다.
다른 환경에서도 적용 전에 다음 순서를 지킨다.

1. 쓰기 트래픽을 중지하거나 점검 모드로 전환하고 PostgreSQL custom-format dump와
   미디어, 실행에 필요한 설정을 함께 백업한다.
2. 백업 파일의 크기와 checksum을 기록하고, 원본과 분리된 DB에 복원한다.
3. 복원 DB에서 현재 revision, 합성 행 수와 핵심 조회를 확인한 뒤 `upgrade head`와
   애플리케이션 smoke test를 실행한다.
4. 검증한 같은 코드와 revision으로 대상 DB를 upgrade하고, revision과 핵심 조회를
   다시 확인한 뒤 쓰기 트래픽을 재개한다.

운영 DB에서 최초로 migration을 실행하면서 복원 가능성을 시험하지 않는다. 이 저장소의
자동 검증도 전용 PostGIS DB만 사용하며 운영 DB 주소를 사용하지 않는다.

## 실패 복구와 downgrade 정책

revision은 가능한 한 PostgreSQL의 한 트랜잭션에서 완료되도록 작성한다. upgrade가
실패하면 서비스를 시작하지 말고 오류 로그와 `alembic current` 결과를 보존한다. 먼저
실패 원인을 수정한 forward revision 또는 수정된 미적용 revision을 전용 복원 DB에서
검증한 뒤 다시 적용한다.

운영 환경에서는 `alembic downgrade`를 복구 수단으로 사용하지 않는다. 이미 적용된
revision 파일을 수정하거나 이력을 다시 stamp하지도 않는다. 일부 DDL이나 외부 작업이
커밋되어 원상 복구가 필요하면, 원본 DB를 덮어쓰지 않고 검증된 백업을 새 DB에 복원해
연결 대상을 전환한다. 기준 revision의 downgrade는 의도적으로 지원하지 않는다.
`profile_media`와 outbox를 추가하는 revision의 downgrade는 테이블·컬럼이나 데이터를
삭제할 수 있으므로 전용 개발/검증 DB에서만 명시적으로 시험한다. 특히 `0003`
downgrade는 pending 전달 작업과 저장된 idempotency key를 제거한다.
`0004` downgrade는 대기 중 사용자와 기록된 random-chat 매칭 결과를 모두 제거한다.

## 자동 검증 범위

CI의 migration 검사는 임시 PostGIS DB에서 다음을 확인해야 한다.

- 빈 DB를 migration 파일만으로 `head`까지 재현한다.
- 기준 schema와 합성 기존 행을 adoption한 뒤 upgrade해 행이 보존되는지 확인한다.
- `upgrade head` 중복 실행과 실패한 revision의 트랜잭션 rollback 및 재시도를 확인한다.
- `alembic check`와 엄격 비교기로 SQLAlchemy metadata와 `head` 사이의 schema drift를
  거절한다.

로컬에서 CI와 같은 검사를 재현할 때는 별도 Compose 프로젝트와 이름이 고정된 전용
DB를 사용한다.

```sh
COMPOSE_PROJECT_NAME=hoseo-migration-check docker compose --profile test up -d --wait test-db
COMPOSE_PROJECT_NAME=hoseo-migration-check docker compose exec -T test-db \
  createdb --username test_user --maintenance-db test_db migration_test_db
COMPOSE_PROJECT_NAME=hoseo-migration-check docker compose --profile test run --rm \
  -e MIGRATION_TEST_DATABASE_URL=postgresql+asyncpg://test_user:test_password@test-db:5432/migration_test_db \
  test python -m pytest app/migration_tests -q
COMPOSE_PROJECT_NAME=hoseo-migration-check docker compose --profile test down -v --remove-orphans
```

검사는 `MIGRATION_TEST_DATABASE_URL`이 없거나 DB 이름이 정확히 `migration_test_db`가
아니면 schema 초기화를 거절한다. 마지막 명령은 이 전용 Compose 프로젝트의 컨테이너와
볼륨을 삭제한다. 네 명령에 같은 전용 프로젝트 이름을 사용하고, 이미 실행 중인 다른
프로젝트 이름을 재사용하지 않는다.

## `0001`–`0002` 로컬 검증 결과 (2026-11-06)

별도 Docker 네트워크의 전용 PostGIS DB에서 **14 passed, 3 warnings, 25.51초**를
확인했다. 최종 이미지를 다시 빌드한 뒤 소스 mount 없이 같은 14개 검사를 재실행해
**14 passed, 3 warnings, 24.46초**도 확인했다. 경고는 기존
Pydantic `Field(env=...)` deprecation 1건과 Alembic이 computed
`message.search_tsvector` 기본값을 수정할 수 없다고 알리는 2건이다. generated 식은
엄격 비교기로 별도 검사한다. 빈 DB 재현과 중복 upgrade, 기준/head 기존 DB adoption,
합성 사용자 보존, 8종 schema drift, 전체 downgrade rollback, 실패 revision rollback과
재시도를 포함한다.

새 `Dockerfile.local` 이미지에서는 소스 mount 없이 격리된 `migration_init_db`에
`local_init`을 두 번 실행했다. 두 실행 뒤 revision은 `20261106_0002`, 합성 사용자는
정확히 2명이었다. 빈 DB에는 migration만으로 애플리케이션 테이블 31개가 생성되었고,
`alembic check`와 413줄의 offline SQL 생성도 통과했다.

같은 격리 DB를 `pg_dump -Fc`로 백업해 새 `migration_restore_db`에
`pg_restore --exit-on-error`로 복원했다. 복원 DB의 revision은 `20261106_0002`, 사용자
수는 2명이었으며 dump SHA-256은
`5c51ba3bf51167da88c8d7eaf3e42815768923616d62fff8c5c32275bb6222ea`였다.

기존 백엔드 전체 suite도 전용 `test_db`와 Redis에서 RuntimeWarning을 오류로 처리해
**152 passed, 3 warnings, 67.68초**로 통과했다. 새 `Dockerfile.local` 이미지 빌드,
변경 Python 파일 Ruff 검사, Compose 설정 검증, credential scan과 `git diff --check`도
통과했다.

이 결과는 로컬의 전용 합성 DB와 현재 소스/이미지에 한정한다. 운영 DB에는 연결하지
않았으며 GitHub Actions 실행, 배포 환경 적용, 실제 운영 데이터 복구를 확인한 결과가
아니다.

### 리뷰 후 보완 검증

PK의 SERIAL 기본값 검사 누락과 offline SQL의 search_path 누락을 보완했다. 수정 전
이미지에 새 회귀 검사를 적용했을 때 기본값 제거·상수 기본값·다른 컬럼의 시퀀스 사용·
시퀀스 소유권 해제·offline schema 설정의 **5개 검사 모두 실패**해 결함을 재현했다.

수정된 이미지를 새로 빌드하고 소스 mount 없이 전용 `migration_test_db`에서 전체
migration suite를 실행해 **22 passed, 4 warnings, 38.09초**를 확인했다. 추가 검증은
시퀀스 증가량/cycle 변경 거절, 이름만 바뀐 정상 시퀀스 허용과 값 보존, 편입·upgrade 후
실제 사용자 INSERT, `migration_shadow, public` search_path에서 offline SQL 전체 적용을
포함한다. Offline 적용 후 public의 모든 애플리케이션 테이블·enum·revision 이력,
빈 shadow schema, 온라인 upgrade/check 및 엄격 비교 통과를 확인했다. 경고는 기존
Pydantic deprecation 1건과 위에 설명한 Alembic computed 경고 3건이다.

변경 Python 파일의 Ruff 검사와 `git diff --check`도 통과했다. 이 보완 단계에서는
migration suite를 재실행했으며, 위의 백엔드 전체 152개 통과 기록은 보완 전 검증이다.
운영 DB 변경이나 원격 CI 실행은 수행하지 않았다.

## `0003` outbox 통합 검증

`origin/main` `074a018`의 outbox schema를 `20261106_0003` revision으로 편입한 통합
tree를 새 `hoseo-issue26-merge:local` 이미지로 빌드했다. 소스 mount 없이 전용
PostGIS DB에서 migration suite를 실행해 **24 passed, 4 warnings, 38.61초**를 확인했다.
경고는 기존 Pydantic deprecation 1건과 computed `message.search_tsvector` 관련 Alembic
경고 3건이다.

검사는 빈 DB의 현재 `head` 재현과 중복 upgrade, `0001`·`0002`·`0003` unversioned
schema adoption, `0002`에서 `0003` upgrade, 합성 사용자·메시지·pending outbox 보존,
부분 적용된 outbox schema 거절, downgrade 전체 rollback, 실패 revision rollback/retry,
schema·SERIAL 시퀀스 drift와 offline public-schema 적용을 포함한다.

현재 `head`의 합성 fixture를 `pg_dump -Fc`로 백업해 새 `migration_restore_db`에
`pg_restore --exit-on-error`로 복원했다. 복원 DB에서 revision `20261106_0003`, 사용자
1명, 메시지 1개와 pending outbox 1개를 확인했다. dump SHA-256은
`8c679c0137831ae13b7dd375d02edae32238d9d3774f5d3f64b09cc065813241`이다.

현재 코드의 전체 백엔드 suite는 기존 의존성 이미지에 현재 소스를 mount하고 전용
`test_db`와 Redis에서 실행해 **193 passed, 3 warnings, 98.94초**로 통과했다. 새 이미지
빌드, 변경 Python 파일 Ruff 검사, Compose 설정 검증, credential scan과
`git diff --check`도 통과했다. 이 결과는 로컬 합성 DB 검증이며 원격 GitHub Actions,
운영 DB 변경, 배포 환경 적용이나 실제 운영 데이터 복구 결과가 아니다.

## `0004` random-chat 통합 검증

`origin/main` `724396e`를 통합한 코드를 `hoseo-issue26-final:local` 이미지로 빌드하고
소스 mount 없이 전용 PostGIS DB에서 **25 passed, 4 warnings, 41.09초**를 확인했다.
빈 DB 재현과 반복 upgrade, `0001`–`0004`의 정확 일치 adoption, 사용자·메시지·pending
outbox·queue 데이터 보존, 부분 schema 거절, SERIAL 설정 검증, rollback/retry,
offline public-schema 적용과 온라인 후속 검사를 포함한다.

현재 코드의 전체 backend suite도 기존 의존성 이미지에 소스를 mount한 전용
`test_db`/Redis에서 **213 passed, 4 warnings, 100.69초**로 통과했다. 기존 Pydantic
경고, 테스트 helper 수집 경고와 admin OpenAPI의 중복 operation ID 경고가 남아 있다.
새 이미지 빌드, Ruff, Compose 설정, credential scan, `git diff --check`도 통과했다.

현재 head의 합성 DB를 `pg_dump -Fc`로 백업하고 새 `migration_restore_db`에
`pg_restore --exit-on-error`로 복원했다. revision `20261106_0004`, 사용자·메시지·pending
outbox·queue 각 1개가 보존되었다. dump SHA-256은
`529eb7ab8816bf4b42578f320b59b1317fd7d5483c5c9e7e65e7e4d3325af61e`다.

이는 전용 합성 DB에서 수행한 로컬 검증이다. 운영 DB 변경이나 배포를 수행하지 않았으며
원격 CI 결과는 PR의 최종 commit에 연결된 GitHub Actions 결과를 확인한다.

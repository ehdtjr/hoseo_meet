# 채팅방 참가·위치 전송 정책 (#19)

외부 참가 경로인 `POST /users/me/subscriptions`, `POST /meet_post/subscribe/{id}`,
`POST /story_post/subscribe/{id}`는 모두 `SubscriberService.subscribe`를 호출한다.
모임·스토리 생성자의 자동 참가에도 같은 정책을 적용한다.
`SubscriptionCRUD.create/update`는 정책을 적용하지 않는 내부 저장 계층이므로
외부 요청에서 직접 호출하면 안 된다.

## 참가와 재가입

- 계정은 `User.is_active=true`여야 한다. 기존 구독의 `is_user_active=false`는
  재가입으로 복구할 수 없으며, 이미 활성 구독인 경우 중복 참가를 거절한다.
- `meet`, `delivery`, `taxi`, `carpool`은 방과 유형이 일치하는 모임 게시글이
  존재해야 한다. `active=true`인 구독 수가 `max_people` 미만일 때만 참가한다.
  생성자도 정원에 포함되며, 재가입도 새 참가와 같은 정원 검사를 받는다.
- `story`는 만료되지 않은 스토리 게시글이 있어야 한다. 정원 필드는 없다.
  생성 시 게시글을 먼저 저장한 뒤 생성자를 참가시킨다.
- `random`과 미지원 유형은 외부 직접 참가·재가입을 거절한다. 랜덤 매칭 API는
  현재 미구현이며, 향후 매칭 결과에 따른 내부 참가 권한을 별도로 정의해야 한다.
- 연결된 게시글이 없는 방에는 생성자도 직접 참가할 수 없다. 모임 생성 요청의
  유형은 `meet`, `delivery`, `taxi`, `carpool`로 제한한다.
- 기존에 저장된 `story`, `random` 유형의 모임 게시글은 목록·상세 조회와 삭제가
  가능하도록 읽기 모델에서 계속 허용한다. 신규 생성 요청의 제한은 유지한다.
- 수신자는 `Stream.recipient_id`, `Recipient.type=STREAM`, `Recipient.type_id`를
  함께 확인한다. 사용자 수신자와 스트림 ID가 겹쳐도 잘못된 구독을 재활성화하지 않는다.

정원 확인 전에 `streams` 행을 `SELECT FOR UPDATE`로 잠근다. 연결된 게시글도
같은 트랜잭션에서 잠그고, 구독 생성·재활성화의 마지막 commit까지 잠금을 유지한다.
PostgreSQL의 기본 `READ COMMITTED` 격리 수준에서 다음 요청은 앞선 참가의 commit 후
인원을 다시 조회한다. 실패·취소는 rollback하여 잠금을 해제한다.

모임·스토리 생성은 스트림, 수신자, 게시글, 생성자 구독을 하나의 트랜잭션에서
저장한다. 내부 CRUD와 서비스는 `commit=False`일 때 flush만 수행하고, 생성 서비스가
생성자 참가 성공 후 한 번만 commit한다. 그 전에는 다른 요청에서 방이나 게시글을
조회하거나 참가할 수 없다. 생성 도중 실패하면 구독을 포함해 모두 rollback한다.
독립적인 CRUD 호출과 외부 참가 요청은 기본값 `commit=True`를 사용한다.

범용 구독 API는 정원 초과·중복 참가에 400, 참가 자격·방 유형 제한에 403,
없는 방·잘못된 수신자 연결에 404를 반환한다. 기존 모임·스토리 API의 없는 게시글
응답은 400을 유지한다.

## 위치 전송

위치 이벤트를 만들기 전에 해당 스트림의 구독, `active`, `is_user_active`, 계정의
`is_active`를 DB에서 확인한다. 비참가자·탈퇴자·비활성 사용자는 403을 받고,
이벤트 dispatcher는 호출되지 않는다. 위치 전송은 현재 참가 여부로 판단하며,
게시글 만료는 신규 참가·재가입을 제한한다.

## 검증

`backend/app/tests/router/test_stream_policy.py`는 실제 FastAPI 경로와 별도 PostgreSQL
세션을 사용한다. 인증 사용자는 합성 대역으로 주입하고 이벤트 dispatcher만 대역으로
교체한다. DB 조회·저장·잠금·서비스 참가 정책은 실제 구현을 사용한다.

- 범용·전용 API 정원 제한, 정상 참가·탈퇴·재가입, 메시지·위치 전송.
- 비참가자·탈퇴자·비활성 구독·비활성 계정의 위치 거절과 이벤트 미발행.
- 미지원 유형, 없는 게시글, 만료 스토리, 수신자 유형 충돌.
- 마지막 자리 신규 참가 경쟁, 재가입과 신규 참가 경쟁, 동일 사용자 중복 참가.
  두 HTTP 요청이 실제 PostgreSQL 행 잠금을 기다리는 것을 `pg_stat_activity`에서
  확인한 뒤 잠금을 풀고 성공 1건·거절 1건 및 최종 인원을 검증한다.
- 저장 실패 시 rollback, 잠금 해제, 정원 미소모.
- 생성자의 가입 직전에 생성 요청을 정지시킨 뒤 별도 HTTP 요청·DB 세션으로
  방·게시글의 미노출과 참가 거절을 확인하고, 생성 완료 후 생성자 자리를 확인한다.
  모임과 스토리 모두 검증한다.
- 생성자 구독 저장 직후 실패를 주입하여 방·수신자·게시글·구독 전체의 rollback을
  검증한다. 기존 유형의 모임 데이터는 목록·상세·삭제 API를 실제 호출한다.

재현 명령(로컬 합성 `.env` 생성 후):

```bash
docker compose -p hoseo-issue19 --profile test up -d --wait test-db test-redis
docker compose -p hoseo-issue19 --profile test run --rm --no-deps \
  -v "$PWD/backend/app:/app/app:ro" test \
  python -m pytest app/tests -q -W error::RuntimeWarning
```

백엔드 이미지에는 `backend/poetry.lock`의 의존성이 설치되어 있어야 한다.
이 검증은 로컬 HTTP/DB 통합 검증이며 실제 기기 수신, GitHub CI, 배포 검증은 별도다.

2026-11-06 리뷰 반영 후 로컬 실행 결과: 정책·생성·기존 데이터 호환성 테스트 20개를
포함한 백엔드 전체 **141개 통과**(58.50초). 관련 테스트 45개도 별도 실행에서 통과했다.
Pydantic 설정 deprecation 1건과 기존 테스트 모델 수집 경고 2건이 있었다.
변경 서비스와 신규 테스트의 치명적 Python 오류 검사(`ruff` E9/F63/F7/F82),
`git diff --check`, 추적 파일 자격 증명 검사를 통과했다.

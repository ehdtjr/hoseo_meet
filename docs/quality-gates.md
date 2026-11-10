# 품질 검사와 실행 증거 (#30)

`.github/workflows/cicd.yml`의 `Local environment checks`가 main push·PR·수동 실행을 검사한다.
주석뿐이던 `ci_cd.yml`은 이미 삭제되어 있으며 복원하지 않는다. 실행하지 않는 workflow 예시는
`.github/workflows` 밖의 문서에 둔다. 운영 배포 단계는 없다.

## 필수 검사

- `repository-checks`: 실제 임시 Git 저장소에 충돌 마커·합성 비밀 표식·금지 파일명을 넣어
  검사 실패를 확인한다. `git ls-files -z`로 확장자와 ignore 규칙에 관계없이 추적 파일을 검사한다.
  충돌 검사는 NUL 바이트가 있는 바이너리를 제외하고 diff3의 공통 조상 마커도 찾는다.
  비밀 검사는 기존 private key·AWS access key·service account·OpenAI project key 패턴을 유지한다.
  출력은 파일명·행 번호만 포함하며 비밀 표식 원문은 출력하지 않는다. 이 패턴 검사가 모든 비밀을
  발견한다는 뜻은 아니다. 과거 Git 이력은 검사 범위에 포함하지 않는다.
- CSV 검사는 실제 추적 seed와 합성 fixture 모두 실행한다. 충돌 양쪽의 데이터가 동일함을
  확인해 11열 헤더 하나와 83행만 보존했다. 이름·주소 쌍은 중복이 없다. 빈 선택 열과 인용된 쉼표는
  허용하며, 잘못된 헤더·열 수·필수 값·중복·비유한/범위 밖 좌표는 거절한다.
  importer는 전체 파일 검증 후 DB 작업을 시작한다. 기본 `local_init`은 이 CSV를 소비하지 않는다.
  이 검사는 기존 임대 정보의 최신성이나 연락처의 정확성을 증명하지 않는다.
- `build-and-test`: lockfile 기반 API/관리자 빌드, Ruff 기준선 검사, 전용 PostGIS/Redis에서
  `app/tests` 전체와 별도 `migration_test_db`에서 migration 전체 실행, 서비스 smoke를 유지한다.
- `flutter-tests`: Flutter 3.32.1 / Dart 3.8.1에서 잠금 의존성, 정적 분석, 전체 테스트,
  합성 WS 비밀 표식의 JIT/AOT 로그 검사 및 debug bundle을 실행한다.
- `admin-tests`: 잠금 의존성 설치 후 전체 Vitest와 ESLint를 실행한다.
- `quality-gate`: 위 네 job이 모두 `success`여야 성공한다. failed·cancelled·skipped job은
  성공으로 집계하지 않는다. 저장소 branch protection/ruleset의 required check 설정은 별도이며
  이 변경은 원격 저장소 설정을 바꾸지 않는다.

`scripts/required_tests.json`은 삭제되거나 선택 실행에서 빠지면 안 되는 테스트 ID를 명시한다.
인증 토큰 거절·갱신 실패, 비회원 권한 거절, 생성/부분 저장 rollback, FCM 발송 실패 재시도,
미디어 생성 실패, CSV 좌표 저장/잘못된 후속 행, Flutter HTTP 403/500·전송 예외·재접속 실패 복구가 포함된다.
각 전체 실행의 JUnit/Flutter machine 보고서를 `check_test_reports.py`로 확인하며
**한 개라도 skipped·failed·error이면 실패**한다. 빈 보고서·중단된 Flutter 실행·필수 ID 누락도 실패한다.
테스트 이름을 바꾸면 새 ID가 같은 실패 경로를 실제 검증하는지 검토하고 manifest를 함께 수정한다.
보고서는 Actions artifact로 보존한다. 합성 데이터만 사용하며 운영 응답이나 자격값을 넣지 않는다.

## 정적 분석 기준선

기준은 #30 작업 시작 시 main `ab89d5f`와 같은 소스이며 변경한 Python 파일의 신규 지적은 없다.
`scripts/baselines/backend.json`은 Poetry lock의 **Ruff 0.6.9** 지적 82개를,
`flutter.json`은 **Dart 3.8.1**의 warning 11개·info 192개 (총 203개)를 파일·규칙별 개수로 기록한다.
이 수치는 경고 없는 전체 정적 분석 통과가 아니다. 기존 Python F821 등도 기술 부채로 남아 있다.
Mypy와 전체 formatter 검사는 이 gate의 통과 항목이 아니다.

- Python 구문 오류와 Dart ERROR는 기준선에 추가할 수 없고 즉시 실패한다.
- 새 파일/규칙의 지적 또는 같은 파일/규칙의 개수 증가도 실패한다. 기존 지적 감소는 허용한다.
- 행 이동은 기존 지적을 신규로 취급하지 않는다. 같은 파일·규칙에서 기존 지적을 지우고 같은 수의
  지적을 추가하는 경우는 개수 비교로 구분할 수 없으므로 코드 검토가 필요하다.
- SDK·lock 변경이나 기술 부채 수정 시 전체 진단 diff를 검토한 후 아래 명령으로 기준선을 갱신한다.
  CI는 기준선을 갱신하지 않는다. 실패를 없애기 위한 무검토 재생성은 하지 않는다.

```sh
# 루트, Poetry lock과 같은 Ruff 환경
python3 scripts/check_static_analysis.py backend --executable ruff
python3 scripts/check_static_analysis.py flutter --executable /path/to/flutter-3.32.1/bin/dart
# 진단 변경을 검토한 경우에만 위 명령에 --write-baseline 추가
python3 -m unittest discover -s scripts/tests -v
python3 scripts/check_conflicts.py
python3 scripts/check_secrets.py
PYTHONPATH=backend python3 -m app.scripts.rental_csv backend/last_rental_data.csv
```

## APK·에뮬레이터·실기기 실행 기록 양식

아래 항목을 매 실행마다 복사해 채운다. 미실행은 `미검증`, 비활성 연동은 `비활성/미검증`으로 적고
전체 통과로 합산하지 않는다. debug bundle은 APK/IPA 빌드나 기기 설치 증거가 아니다.
프로브 APK는 실제 제품 APK와 구분하고 [WS 프로브 기록](websocket-recovery-validation.md)과 연결한다.

```text
실행 시각(UTC) / 실행자:
소스 SHA / worktree 변경 유무:
코드·로컬 테스트: 명령 / 종료 코드 / 보고서 위치:
원격 CI: 최종 head SHA / run URL / job 결과 (미실행이면 미검증):
APK/IPA: 제품/프로브 구분 / build 명령 / 종료 코드 / 파일 SHA256:
설치: 기기/에뮬레이터 모델 / OS / 앱 버전 / 설치·실행 결과:
서버: 배포 SHA / 합성 또는 운영 구분 / API·WS·미디어 접근 주소 (자격값 제외):
인증: 로그인 → 만료/401 → 갱신 성공 및 실패 → 재로그인 / 관측 증거:
권한: 다른 계정의 방·프로필·미디어 변경 거절 / 관측 증거:
전송: 성공/HTTP 거절/오프라인 → draft 유지 → 동일 ID 재시도/중복 없음:
WS: 네트워크 끊김·복구 / background·resume / 누락 수신·중복 / 관측 증거:
미디어: 업로드·조회·교체 / 타 계정 거절 / 실패 후 재시도 / 관측 증거:
FCM: 활성 설정 여부 / 서버 발송 결과 / message ID / 기기 수신 시각·관측 증거:
제한: 미검증 항목 / skip 이유 / 다음 확인 사항:
최종 판정: 코드 / 로컬 실행 / 원격 CI / native build / 기기 / 외부 연동을 각각 기재:
```

FCM mock 재시도 테스트는 실제 provider 접수·OS 알림 표시·기기 수신을 증명하지 않는다.
합성 API/WS 테스트와 위젯 테스트도 제품 APK의 전체 사용자 흐름을 대신하지 않는다.
과거 기록은 [로컬 검증 기록](local-validation.md), [WS 복구 기록](websocket-recovery-validation.md)을
해당 시점의 결과로만 읽는다.

## 이번 변경의 로컬 검증 (2026-11-10 UTC)

`ab89d5f` 기반 `11kkw/p2-workflow`의 #30 변경을 포함한 worktree에서 확인했다.
저장소 검사 회귀 테스트 12개, backend 237개, migration 27개, Flutter 95개가 통과했고
각 실행 보고서에 skip은 없다. backend·migration은 별도 `hoseo-issue30` Compose 프로젝트의
전용 PostGIS/Redis 및 `migration_test_db`를 사용했다. 실제 seed의 11열·83행 검사,
합성 CSV의 PostGIS 좌표 저장과 부분 저장 방지, Flutter debug bundle,
WS 로그 JIT/AOT 검사, 정적 기준선, actionlint도 통과했다.
관리자 웹은 Node 22 Docker build 단계에서 frozen lock 설치와 TypeScript/Vite production 빌드,
Vitest 20개 및 ESLint가 통과했다. 호스트의 설치는 파일 작업 대기로 지연되어 이 결과에 포함하지
않았다. production chunk 크기 경고는 남아 있다. 검증용 DB/Redis 컨테이너와 네트워크는 정리했다.

원격 Actions 실행, PR/merge, 운영 배포, 제품 APK/IPA 빌드·설치 및 이번 변경에 대한
에뮬레이터/실기기 API·WS·미디어·FCM 수신은 미검증이다. 기존 backend Pydantic/수집/OpenAPI
경고와 Alembic computed default 경고는 남아 있다.

# #15 로컬 전환 검증 기록

2026-10-22, `11kkw/aws` 작업 브랜치. 사용자 관리 로컬 Kubernetes 운영 + 향후 Cloudflare Tunnel 연결 방향을 반영했다. 이 기록은 개발 환경의 검증 결과이며 실제 클러스터 배포/운영 데이터 이관/외부 공개 완료 기록이 아니다.

## 통과한 검증

- Docker Compose 기본/test/monitoring profile 설정 검증.
- Poetry lock 기반 Python 3.10 API/worker 이미지 및 Yarn frozen lock 기반 관리자 TypeScript/Vite production 이미지 빌드.
- 전용 PostGIS `test_db`와 `test-redis`에서 백엔드 **117 passed**. 테스트 제외/xfail/운영 자격파일 없이 실행. 경고 3개는 기존 Pydantic Field(env) 사용 및 ORM/schema 테스트 도우미 클래스명 관련이며 실패나 테스트 수집 오류가 아니다.
- 마지막 미디어 헤더 보강 후 파일 저장소 테스트 **2 passed** 및 신규 Python 파일 Ruff 검사 성공.
- 실제 컨테이너 HTTP/WS: 합성 관리자 로그인 → refresh → 관리자 목록, 일반 계정의 관리자 접근 403, 게시글 생성 → 활성 채팅방 → 메시지 전송/조회 → WS 수신.
- 실제 컨테이너 미디어: 프로필 업로드 → 서명 URL 조회 200 → 서명 없는 요청 403 → 프로필 교체 시 이전 파일 URL 404. 비인증 사용자 조회는 401.
- 실제 Chromium 브라우저: 동일 출처 `/api/v1` 프록시로 관리자 로그인 후 사용자 관리 화면에서 합성 계정 2개 조회. [화면 증거](evidence/issue-15/admin-users.png).
- DB·Redis 컨테이너 재시작 후 합성 계정 비밀번호 검증, 게시글 행 및 서명 미디어 파일 보존 확인.
- 쓰기 서비스 중지 후 DB/미디어/서명 키 백업. 별도 `hoseo15-restore` Compose 프로젝트의 template0 기반 새 논리 DB 및 별도 미디어 볼륨에 복원하여 비밀번호·게시글·서명 파일 확인. 미디어 SHA256: `36fe6ab71ec56fa1fc84326e4673fbf028c6ad2eb5051ce5a9e6cb0d07c85f4c`.
- `kubectl kustomize kustomize/local` 렌더링 성공. 서버 측 dry-run/apply 검증은 수행하지 않았다.
- 추적 파일 자격정보 형식 검사, Python 구문 검사, 백업 스크립트 `bash -n`, `git diff --check` 성공.

## Flutter 검증 범위

전역 Flutter 3.47.5에서 로그인 폼/빈 입력 검증 **2 passed**, analyzer error 0을 확인했다. 기존 info/warning은 남아 있으므로 경고 없는 분석 통과로 간주하지 않는다. 이 SDK는 잠금 의존성 차이가 있고 Android APK 빌드는 Gradle 8.11.1이 Flutter의 최소 8.14.0보다 낮다는 검사에서 실패했다. 버전 검사를 우회하지 않았다.

Flutter **3.32.1 / Dart 3.8.1**에서 원본 lockfile을 변경하지 않는 `pub get --enforce-lockfile`, 로그인 위젯 테스트 **2 passed**, `flutter build bundle --debug --no-pub`가 모두 성공했다. 프로젝트 및 CI 기준도 이 버전으로 고정했다. 번들 빌드는 asset/kernel 검증이며 APK/IPA 성공을 뜻하지 않는다. APK/IPA/native 설치, 에뮬레이터 및 실기기 전체 로그인/게시글/채팅 흐름은 이 기록의 완료 항목이 아니다.

## 남아 있는 적용/검증

- 대상 Kubernetes 노드, StorageClass/PVC 실제 위치, 내부 접속 주소 확정 후 별도 namespace에 실제 설치·복구 검증.
- Flutter 실기기 또는 에뮬레이터의 API/WS/미디어 연결과 실제 사용자 흐름 확인.
- FCM 수신, 지도, 카카오, 외부 SMTP, OpenAI/RunPod 등 실제 외부 연동 검증. 현재 SMTP는 로컬 Mailpit이고 FCM/AI는 기본 비활성이다.
- Cloudflare Tunnel/공개 호스트/DNS/운영 인증 설정. 터널 자격값, 클라우드 자원 종료, AWS 데이터 이관은 이번 변경에서 다루지 않았다.
- 원격 CI, PR merge, 운영 배포는 미수행. 이슈 #15는 실제 클러스터 및 기기 검증 완료 전까지 열어 둔다.

검증용 복구 프로젝트의 데이터는 정리했다. 소스 개발 환경 컨테이너도 검증 후 종료/제거하며 DB·미디어 볼륨과 로컬 .env는 보존한다. 다시 시작하는 절차와 백업 복원 명령은 [실행 문서](local-environment.md)를 따른다. 실제 자격값이나 백업 내용을 Git에 넣지 않는다.

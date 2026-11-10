# 앱 백그라운드 복귀 시 로그인·채팅 복구 (#10)

## 변경한 동작

- 앱 복귀와 WebSocket 연결 시 access token의 JWT `exp`를 확인하고 만료 30초 전부터 갱신한다. 앱 시작 자동 로그인은 완료를 기다린다.
- HTTP 401, 앱 복귀, 소켓 재연결은 진행 중인 갱신 한 번을 공유한다. 이미 회전한 토큰으로 온 지연된 401은 현재 토큰을 사용한다.
- 원 HTTP 요청은 최대 한 번 재전송한다. 401 뒤 갱신이 실패하면 이전 access token으로 재전송하지 않는다. 기존 JSON/form/multipart/stream 본문 보존 경로를 유지한다.
- refresh endpoint의 400/401/403 자격 거절은 access/refresh token 모두 제거한다. 네트워크, timeout, 429, 5xx, 잘못된 성공 응답은 저장 자격을 보존해 다음 복귀·재시도에서 복구할 수 있게 한다. 갱신 HTTP timeout은 15초다.
- 로그인 교체·로그아웃은 이전 비동기 결과를 무효화한다. 저장소 변경을 순서대로 실행해 진행 중인 토큰 저장이 로그아웃을 되돌리지 않게 한다. 로그아웃 뒤 다른 계정으로 원 요청을 재전송하지 않는다.
- 복귀 후 인증이 준비되면 채팅방 목록을 다시 조회하고 랜덤채팅 polling과 열린 채팅의 WebSocket을 재개한다. 인증 대기 중 다시 백그라운드로 가거나 화면이 닫히면 복구 작업을 취소한다.

## 자동 검증

2026-11-10, Flutter 3.32.1 / Dart 3.8.1, 기존 `pubspec.lock` 유지:

```sh
cd frontend/app
# 신규 checkout에서만: cp .env.example .env
flutter pub get --enforce-lockfile
flutter test --no-pub --reporter expanded
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
flutter build bundle --debug --no-pub
```

- 전체 테스트: 113개 통과.
- analyzer: error 0, 기존 warning 11 / info 193. warning/info는 비실패 옵션으로 실행했다.
- debug bundle 빌드 성공. 운영 APK/IPA 검증을 의미하지 않는다.
- 인증 회귀 테스트는 동시 성공·실패 갱신, 회전 토큰 저장, 지연된 401, 일시 장애에서 저장 자격 유지, 명시적 거절, 로그아웃·계정 교체와 저장 경쟁을 검증한다.
- lifecycle widget 테스트는 인증 준비 전 목록/polling 요청이 시작되지 않으며, 실패·재백그라운드·dispose 후 재개하지 않음을 검증한다.
- 기존 본문 보존, multipart disk streaming, 한 번 재전송, 채팅 WebSocket recovery 테스트도 전체 suite에 포함된다.

## Android 복귀 재현 도구

`frontend/app/tool/session_recovery_probe.dart`는 별도 검증 진입점이다. 실제 `AuthNotifier`, `AuthService`, secure storage, `AuthHttpClient`, `SessionLifecycle`, `ChatPage`를 사용한다. `scripts/session_recovery_probe_server.py`만 대상으로 실행하며 실제 계정은 사용하지 않는다. 서버는 서명을 검증하는 실제 인증 서버가 아니다.

```sh
python3 scripts/session_recovery_probe_server.py
# 다른 터미널, 별도 복사본 frontend/app에서:
flutter pub get --enforce-lockfile
flutter build apk --debug --target-platform android-x64 \
  --target tool/session_recovery_probe.dart \
  --dart-define=API_BASE_URL=http://10.0.2.2:18810/api/v1
```

이번 검증용 복사본은 applicationId만 `dev.hoseo.issue10`으로 분리했다. Android manifest의 activity는 원래 Kotlin 클래스 `com.example.app.MainActivity`를 명시했다. 원본 앱의 Android 설정과 진입점은 변경하지 않았다.

1. 로그인 응답의 access token은 3초 후 만료된다. 최초 채팅 목록 `Session recovery room v1`을 확인한다.
2. Android 홈 버튼으로 백그라운드로 보낸 뒤 토큰 만료를 기다린다.
3. 앱으로 돌아와 `/auth/refresh` 후 새 토큰으로 채팅 목록을 요청하는지 `/snapshot`과 UI에서 확인한다.
4. `POST /control`의 `mode=transient`, `expire=true`로 갱신 503을 재현한다. 다음 복귀에 `mode=ok`로 바꾸면 로그인 입력 없이 복구되어야 한다.
5. `mode=reject`, `expire=true`에서 갱신 거절 후 `Probe signed out`을 확인한다.

```sh
curl -s http://127.0.0.1:18810/snapshot
curl -s -X POST http://127.0.0.1:18810/control \
  -d '{"mode":"transient","expire":true}'
```

운영 API, 실제 사용자 계정, 실기기, release APK/IPA, 운영 배포는 이 검증 범위에 포함되지 않는다.

## Android 에뮬레이터 관찰 결과

2026-11-10, `HoseoPatrol_API_35` / `emulator-5584`, Android API 35 / x86_64, Flutter 3.32.1 / Dart 3.8.1. 격리 패키지 `dev.hoseo.issue10`의 debug APK를 설치하고 Orca Android emulator 도구로 홈 버튼·복귀와 실제 접근성 UI를 관찰했다.

| 시나리오 | 서버 관찰 | UI 관찰 |
| --- | --- | --- |
| 최초 로그인 | 로그인 1회, generation 1로 목록 요청 성공 | `Session recovery room v1` |
| access token 만료 후 홈→복귀 | refresh 1회가 목록 요청보다 먼저 실행, 만료 토큰 요청 없음 | `Session recovery room v2` |
| 서버에서 access 거절 + refresh 503 | 원 요청의 401 후 갱신 실패, 로그인 추가 호출 없음 | 기존 v2 목록 유지, 로그아웃되지 않음 |
| 서버 정상화 후 홈→복귀 | 401→refresh 성공→새 토큰으로 한 번 재전송, 전체 로그인 호출은 계속 1회 | `Session recovery room v3` |
| access 거절 + refresh 400 | 자격 거절 뒤 원 요청 재전송 없음 | `Probe signed out` |

원시 토큰을 제외한 서버 이벤트, 단계별 접근성 UI, 검증한 소스의 SHA-256은 [Android 증거](evidence/issue-10/android-session-probe.json)에 기록했다. 503 동안 기존 랜덤채팅의 5초 polling은 각 요청에서 제한된 갱신을 재시도하며 상태 불확실 경고를 유지한다. 실제 운영 인증 서버의 서명 검증이나 기본 진입점 전체의 로그인·지도·FCM 동작을 증명하지는 않는다.

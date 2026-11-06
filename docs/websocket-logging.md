# WebSocket 로그 정책 (#24)

채팅·위치 WebSocket의 앱 수신 서비스, 채팅방 이벤트 소비자, 서버 송수신·파싱 경로는 payload와 예외 문자열을 로그로 출력하지 않는다. `FormatException`은 입력 원문을, 통신 예외는 URL·헤더·토큰을, 연결 종료 예외는 상대가 보낸 사유를 포함할 수 있으므로 예외 객체와 스택도 출력하지 않는다. 같은 채팅방 경로의 활성화·비활성화 HTTP 응답 본문도 출력하지 않는다.

진단에는 고정된 작업/결과 코드(`decode_failed`, `send_failed`, `redis_connection_failed` 등), 재시도 횟수, HTTP 상태 코드, 정수형 방·메시지 ID만 사용한다. 이벤트 종류는 `stream`, `user`, `location`, `read`만 허용하며 그 외 값과 문자열이 아닌 값은 로그에서 `unknown`으로 바꾼다. 본문·좌표·토큰·헤더·URL·커서·전체 이벤트·알 수 없는 필드 값은 기록하지 않는다. 로그를 추가할 때도 입력을 마스킹한 문자열보다 이러한 허용 목록을 사용한다.

앱의 debug/release에 같은 정책을 적용한다. 원문 출력을 빌드 모드 조건으로 허용하지 않는다. 서버도 DEBUG에서 payload를 출력하지 않으며 로거의 DEBUG 수준을 강제하지 않는다. 실제 이벤트는 기존 내용 그대로 전달한다. 앱에서 잘못된 이벤트를 소비하다 발생한 파싱 오류는 고정된 `socket_event_failed`로 처리하여 다음 정상 이벤트를 계속 처리한다.

## 재현 가능한 검증

Flutter 3.32.1 / Dart 3.8.1, 기존 lockfile을 사용한다. 앱 디렉터리에서:

```sh
cp .env.example .env  # 로컬 설정이 없는 경우에만
flutter pub get --enforce-lockfile
flutter test --no-pub
dart --enable-asserts tool/check_websocket_logging.dart
dart compile exe tool/check_websocket_logging.dart -o /tmp/websocket-log-check
/tmp/websocket-log-check
flutter build bundle --debug --no-pub
flutter build bundle --release --no-pub
```

- 순수 Dart 검사 도구는 실제 loopback WebSocket으로 합성 본문·좌표·토큰을 보낸다. 정상 이벤트 6개가 그대로 전달되고, 잘못된 JSON·비객체 JSON·바이너리 입력 이후에도 수신이 계속되는지 확인한다. 종료 사유와 인증 실패 URL/응답에도 표식을 넣고 재시도/종료 상태를 캡처한다. 캡처된 로그에 표식이 하나라도 있거나 진단 상태가 사라지면 실패한다. 검사는 `assert`에 의존하지 않으므로 AOT에서도 유효하다.
- Flutter 소비자 테스트는 민감한 문자열이 들어간 날짜·읽음·좌표 파싱 오류, 알 수 없는 타입, 조회·읽음·활성화 실패를 확인한다. 오류 뒤 정상 채팅·읽음·위치 업데이트가 적용되는지도 확인한다.
- 서버 `app/tests/service/test_websocket_logging.py`는 DEBUG 로그를 캡처하여 이벤트 전달, malformed JSON, 전송 실패, 클라이언트 프레임/종료, Redis 오류, 연결 정리를 검사한다. DB·Redis는 모의 객체를 사용한다. 기존 백엔드 테스트 환경에서 `python -m pytest app/tests/service/test_websocket_logging.py -q -W error::RuntimeWarning`로 실행한다.
- CI는 기존 전체 백엔드·Flutter 테스트에 더해 Dart JIT/AOT 로그 검사를 실행한다.

2026-11-06 로컬 결과: Flutter 테스트 43개, 서버 로그 테스트 5개, JIT/AOT 로그 검사, debug/release bundle 빌드 통과. 변경 Dart 파일 분석은 오류·경고 없이 기존 유형의 안내 15건(`avoid_print` 13건, 간접 의존성 import 1건, 위치 API deprecation 1건)을 보고했다. 이 결과는 소스·로컬 실행 검증이며 GitHub CI 실행, 배포 환경 로그 수집, 휴대폰에서의 debug/release 실행 결과는 포함하지 않는다. FCM 등 별도 전송 경로 전체를 감사한 결과도 아니다.

# Hoseo Meet 앱

Flutter 3.32.1 / Dart 3.8.1 및 추적된 `pubspec.lock`을 사용한다.

```sh
cp .env.example .env
flutter pub get --enforce-lockfile
flutter test --no-pub
flutter build bundle --debug --no-pub
```

API/WS 주소, Android 에뮬레이터 접속, 미디어 및 FCM 설정은
[로컬 실행 안내](../../docs/local-environment.md#flutter-및-관리자-웹-주소)를 따른다.
테스트·번들 빌드와 APK·기기 검증의 범위 및 실행 기록 양식은
[품질 검사 안내](../../docs/quality-gates.md)에 정리한다.

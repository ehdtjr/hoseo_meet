# 최신 개발 이력 통합

## 기준

이 통합은 운영 배포가 아니라, 분리되어 있던 개발 이력을 `main`에 모으는 작업이다.
기존 브랜치는 삭제하거나 이력을 재작성하지 않는다. 일반 merge commit으로 모든 원본 커밋의 조상 관계를 보존한다.

- 기존 main: `eea67fd80d3469251a8cbc47a612320cea24cf26`
- 최신 backend / random-chat: `bb02f8744038cb589cf46d03e77414e960fa6ee3`
- 최신 Flutter / 관리자 웹: `f965ca5d3aebaee95dd8f5e1db197f0fdfa29ae0`
- `develop`, `server`, `feature/chat`, `feature/chatbot`, `feature/meetpost`, `feature/roompost`는 위 두 개발 브랜치에 포함되어 있다.

## 충돌 해결 원칙

1. backend 실행 소스·의존성은 최신 random-chat 브랜치를 그대로 유지한다.
2. Flutter 실행 소스는 최신 frontend 브랜치의 `features/` 구조를 유지한다. 구형 `pages/home_page.dart`, `screens/home_screen.dart`, `screens/splash_screen.dart`를 복구하지 않는다. 기존 구형 자취방 카테고리 칩은 복구 대상이 아니며, 최신 지도/자취방 화면을 유지한다.
3. `lib/main.dart`는 frontend의 dotenv·날짜·권한·지도·FCM·ProviderScope 초기화를 유지한다.
4. 자동 병합이 만든 `AppConfig.baseUrl` / `socketUrl` 중복 선언을 제거한다. 최신 frontend의 Android 에뮬레이터 기본값(`10.0.2.2`)을 유지하며 운영 주소로 임의 전환하지 않는다.
5. iOS Podfile, Podfile.lock, Xcode 객체 참조는 frontend의 일관된 세트를 사용한다. 위치·사진·카메라 사용 설명과 push background mode를 보존한다. frontend의 CampusMeet 명칭, iOS 15.6 Runner 대상 및 iPhone 대상 설정을 유지한다.
6. backend 쪽 Xcode 프로젝트가 갖고 있던 `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = YES`는 Runner Debug / Release / Profile에 보존한다.
7. 관리자 웹의 Linux 대소문자 구분 빌드 오류를 수정한다: `./pages/dashboard` → `./pages/Dashboard`.
8. 앱의 남아 있던 초기 카운터 예제 테스트를 실제 로그인 폼 및 빈 입력 검증 테스트로 교체한다. 기기 저장소만 테스트 더블을 사용하며 Firebase나 운영 API에 연결하지 않는다.
9. 추적 중이던 환경파일, 성능 시험 토큰 산출물, Python bytecode, 빌드 캐시·로그·프로파일 산출물은 통합 트리에서 제외한다. 기존 원격 이력 자체는 지우지 않는다. 과거 이력의 자격값 폐기/교체나 이력 정리는 별도 보안 작업이다.

## 로컬 검증 결과

### Flutter

기존 `pubspec.lock`을 변경하지 않고 Flutter **3.32.1 / Dart 3.8.1**로 검증했다.
현재 전역 Flutter 3.47.5에서는 SDK 기본 의존성 차이로 `--enforce-lockfile` 검증이 실패하므로, 기존 프로젝트를 확인할 때 같은 SDK를 사용한다.

```sh
cd frontend/app
cp .env.example .env
# 실제 앱 실행에는 프로젝트 소유자에게 받은 공개 지도 클라이언트 ID를 로컬 .env에 설정한다.
flutter pub get --enforce-lockfile
flutter test --no-pub --reporter expanded
flutter build bundle --debug --no-pub
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
```

- 잠금 의존성 설치 성공.
- 로그인 폼 렌더링 / 빈 입력 검증 **2개 통과**.
- Flutter debug asset/kernel bundle 빌드 성공. APK/IPA/native 빌드 성공을 뜻하지 않는다.
- analyzer: **error 0, warning 11, info 216**. 경고·정보를 비실패로 설정한 결과이며, 경고 없는 전체 정적 검사 통과가 아니다.
- 로컬 테스트에는 비밀이 없는 합성 `.env`만 사용했다. 실제 자격파일·운영 계정을 복사하지 않았다.

### 관리자 웹

```sh
cd frontend/web/admin-dashboard
npm run build
npm run lint
```

- TypeScript + Vite production build 성공, ESLint 성공.
- 기존 Yarn registry 다운로드는 timeout으로 실패했다. 대체 검증 환경은 npm registry에서 `npm install --package-lock=false --ignore-scripts --include=dev`로 선언 범위의 의존성을 설치했다. **기존 yarn.lock을 재현한 설치 성공으로 간주하면 안 된다.** Manifest와 기존 lockfile은 변경하지 않았다.
- production chunk 크기 경고는 남아 있다.
- 실제 API 호출·관리자 로그인·운영 배포는 검증하지 않았다.

### Backend

- Python 3.10 문법 기준으로 `.py` 파일 **143개 파싱 성공**.
- 기존 Poetry lock에서 의존성을 내보내 별도 Python 3.10 환경에 설치했다. 원본 manifest와 lockfile은 변경하지 않았다.
- 합성 로컬 설정으로 `pytest app/tests --collect-only -q`를 시도했으나, import 시 필요한 `hoseo-meet-firebase.json`이 없어 **exit 4**로 중단되었다. 테스트 실행 성공이나 전체 gate 통과로 기록하지 않는다.
- 원격/운영 자격파일을 읽거나 복사하지 않았다. PostGIS·Redis 테스트 인스턴스에 대한 테이블 삭제/flush 작업이나 운영 대상 부하 시험을 실행하지 않았다.
- 테스트 수집 이후의 기존 테스트 호환성 문제는 별도 확인이 필요하다. 최신 backend 소스 보존 확인은 전체 백엔드 기능 검증을 대신하지 않는다.

### iOS / Android / 운영

- iOS plist와 Xcode 참조·Podfile/lock 일관성은 정적으로 확인한다.
- Xcode/CocoaPods native 빌드, Android APK, 에뮬레이터·실기기 실행, 푸시 수신, 운영 서비스는 이번 통합에서 검증하지 않았다.
- 운영 배포는 수행하지 않는다. 포함된 GitHub Actions workflow에 운영 업로드/배포 단계가 없는지 확인했다.

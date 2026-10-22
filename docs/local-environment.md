# 사용자 관리 환경으로 전환 (#15)

목표는 사용자 관리 **로컬 Kubernetes**에서 API·관리자 웹·PostGIS·Redis·Celery를 운영하고, 추후 Cloudflare Tunnel로 접속 경로를 연결하는 것이다. 개발·CI 재현은 Docker Compose를 사용한다. 현재 대상 노드·StorageClass·내부 주소는 미확정이며 이 문서는 실제 클러스터 배포를 완료했다는 뜻이 아니다. 외부 AWS 자원, DNS, 운영 데이터에는 손대지 않는다.

## 개발 환경: Linux + Docker Compose v2

루트에서 실행한다. Python 3은 설정 생성에만 필요하며 API는 Python 3.10 컨테이너에서 실행한다.

```sh
python3 scripts/local_env.py          # 루트 .env만 생성, 기존 파일은 덮어쓰지 않음
docker compose --profile test config -q
docker compose build web admin
docker compose up -d --wait web admin celery-worker celery-beat mailpit
```

- API: http://localhost:8000/docs
- 관리자: http://localhost:5173 (동일 출처 `/api/v1` 프록시)
- 로컬 메일함: http://localhost:8025 (외부 SMTP 발송 없음)
- 합성 계정: `.env`의 FIRST_SUPERUSER 및 `member@example.com`. 비밀번호는 두 계정 모두 생성된 FIRST_SUPERUSER_PASSWORD. 실제 계정을 쓰지 않는다.
- 기본 설정은 AWS/FCM/AI 자격값을 요구하지 않는다. 이미지/패키지를 처음 받으려면 인터넷이 필요하다.

```sh
docker compose --profile test run --rm test    # 전체 백엔드 테스트, 전용 DB/Redis
docker compose exec -T web python -m app.scripts.local_smoke
docker compose --profile monitoring up -d prometheus grafana
docker compose stop                           # 중지, 데이터 유지
docker compose down                           # 컨테이너 제거, 볼륨 유지
```

**초기화는 이 프로젝트 데이터가 더 이상 필요 없을 때만** `docker compose --profile test --profile monitoring down -v`로 한다. DB/미디어/Redis/모니터링 볼륨이 삭제된다. 공유 클러스터나 다른 프로젝트에 적용하지 않는다. 초기화 스크립트는 비어 있는 로컬 DB의 테이블을 생성하고 합성 사용자 2명만 추가한다. 기존 사용자나 CSV를 갱신하지 않으며 운영 스키마 마이그레이션을 대신하지 않는다.

기본 포트는 모두 127.0.0.1에만 바인딩한다. DB/Redis는 호스트 포트를 열지 않는다. `API_PORT`, `ADMIN_PORT`, `MAIL_PORT`로 충돌을 피한다. 호스트 포트를 바꾸면 DOMAIN/MEDIA_BASE_URL도 맞춰야 한다. 비밀값은 루트 `.env`에서만 소비하며 backend/.env는 만들지 않는다.

## 로컬 Kubernetes

`kustomize/local`은 기존 외부 레지스트리/Ingress/HPA 구성과 분리되어 있다. ClusterIP만 생성하므로 외부 공개나 터널 설치를 하지 않는다. API/worker/beat는 RWO 미디어 PVC를 공유하는 단일 Pod에 배치한다. API Pod 복제는 1이며 Recreate 전략을 사용한다. 다중 노드 HA 구성이 아니다. DB 10Gi, 미디어 10Gi, Redis 1Gi PVC를 사용하며 **적용 전에 대상 노드와 기본 StorageClass 및 백업 위치를 확인**해야 한다. local-path 등 노드 로컬 볼륨이면 노드 장애 시 별도 복구가 필요하다.

검토용 렌더링은 클러스터를 변경하지 않는다.

```sh
kubectl kustomize kustomize/local > /tmp/hoseo-local.yaml
docker build -f backend/Dockerfile.local -t hoseo-local-backend:local backend
docker build -t hoseo-local-admin:local frontend/web/admin-dashboard
```

다음은 대상 클러스터/이미지 반입 경로를 결정한 **후** 실행하는 배포 절차다. Docker 이미지와 k3s/containerd 이미지 저장소는 다르므로, 선택한 클러스터의 이미지 반입 절차로 위 두 이미지를 각 실행 노드에 넣거나 사용자 관리 레지스트리의 고정 태그로 변경한다.

```sh
kubectl apply -f kustomize/local/namespace.yaml
kubectl -n hoseo-meet-local create secret generic local-env --from-env-file=.env
kubectl apply -k kustomize/local
kubectl -n hoseo-meet-local rollout status deployment/web
kubectl -n hoseo-meet-local port-forward service/web 8000:8000
# 별도 터미널
kubectl -n hoseo-meet-local port-forward service/admin 5173:80
```

Secret을 만들기 전 `.env`를 해당 환경에 맞춰 검토한다. POSTGRES_SERVER=db, REDIS_HOST=redis, SMTP_HOST=mailpit는 내부 Service 이름이다. Secret 갱신은 파일을 노출하지 않는 별도 관리 절차를 사용하고 API Pod를 재시작해야 한다. 미디어는 `/data/media` PVC, DB는 `/var/lib/postgresql/data`, Redis는 `/data`에 저장된다. Mailpit은 임시 개발 메일함이다. 이 로컬 오버레이에는 개발용 합성 관리자와 메일함이 있으므로 외부 공개 전에 별도 운영 설정 검토가 필요하다.

Cloudflare Tunnel 연결은 후속 단계다. 추후 정한 호스트를 admin Service의 80 포트에 연결하면 API와 WS도 `/api` 프록시를 통과한다. 공개 주소 확정 시 DOMAIN, MEDIA_BASE_URL, CORS와 Flutter API_BASE_URL/WS_URL을 함께 바꾼다. 지금은 tunnel credentials·DNS·Ingress·방화벽을 생성하지 않는다. 기존 DB에 저장된 절대 미디어 URL은 주소 변경 시 별도 변환/검증이 필요하다.

## 미디어 접근 정책

STORAGE_BACKEND=local이 기본이며 기존 S3Manager 호출이 로컬 디스크로 전달된다. 업로드/변경 권한은 기존 인증/게시글 권한 검사를 유지한다. 파일은 생성 시 덮어쓰기를 거부하고 상대경로/심볼릭 링크 탈출을 차단한다. 읽기는 SECRET_KEY로 서명한 URL을 요구하며 디렉터리 목록을 제공하지 않는다. 서명 없는 요청/변조는 403, 삭제 후는 404다. 이미지 이외의 형식은 바이너리로 제공하고 nosniff/CSP를 적용한다.

이 URL은 **소유자가 공유하면 누구나 읽을 수 있는 만료 없는 접근 링크**다. 사용자별 조회 ACL이나 만료형 서명을 구현한 것은 아니다. 현재 Flutter 이미지 위젯과 DB의 영구 URL에 맞춘 로컬 정책이다. 링크를 로그에 남기지 않으며 API/미디어 프록시 access log를 끈다. 파일 삭제 또는 SECRET_KEY 교체로 링크를 무효화할 수 있다. 키를 바꾸면 로그인 토큰 및 기존 미디어 링크도 무효화되므로 DB·파일·키를 함께 백업한다. 기존 AWS 파일을 자동 다운로드하거나 삭제하지 않는다. S3를 명시적으로 선택할 때만 기존 AWS 설정을 요구한다.

## Flutter 및 관리자 웹 주소

Flutter는 기존 lockfile과 호환되는 **3.32.1 / Dart 3.8.1**을 기준으로 한다. [공식 SDK archive](https://docs.flutter.dev/install/archive)에서 이 버전을 별도 설치하고 해당 `flutter` 실행 파일을 사용한다. 전역 3.47.5에서는 Android 빌드가 Gradle 8.11.1의 최소 버전 검사에서 실패했으며, 검사 우회나 이번 작업과 무관한 SDK/Gradle 일괄 업그레이드는 적용하지 않았다.

관리자 Compose 빌드는 `/api/v1`을 사용한다. Vite 개발 서버도 같은 경로를 localhost:8000으로 프록시한다. 필요하면 VITE_API_BASE_URL로 덮어쓴다.

```sh
cd frontend/app
cp .env.example .env
flutter pub get --enforce-lockfile
# PC/iOS 시뮬레이터에서 호스트 API로 접속
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
# Android 에뮬레이터
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
# 승인된 내부망 노출 및 API 접근 경로를 마련한 실기기에서만 사용
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_HOST:8000/api/v1
```

WS_URL 생략 시 API_BASE_URL에서 ws/wss 주소를 유도한다. API가 발급하는 이미지 URL도 기기에서 접근 가능해야 하므로 MEDIA_BASE_URL을 동일 호스트로 설정해야 한다. 기본 localhost 바인딩은 LAN 실기기 접속을 허용하지 않는다. Android 디버그 빌드만 로컬 HTTP를 허용하며 운영은 HTTPS를 사용한다.

Android 빌드는 google-services.json이 있을 때만 Google Services 플러그인을 적용한다. 로컬 핵심 기능은 이 파일 없이 빌드할 수 있도록 구성했다.

FCM은 서버 FCM_ENABLED=false / Flutter `--dart-define=FCM_ENABLED=false`가 기본이다. 활성화 검증은 Firebase 자격설정/수신 기기가 준비된 후 수행한다. 지도 SDK는 외부 연동을 유지하므로 NAVER_MAP_CLIENT_ID 및 네트워크가 필요한 화면은 별도다. 카카오 인증도 외부 연동이며 이메일 합성 로그인은 이와 독립적이다. AI_ENABLED=false이면 챗봇은 503을 반환하고 태깅 작업은 외부 API를 호출하지 않는다. 실제 OpenAI/RunPod 호출이나 과금 검증은 수행하지 않는다. SMTP는 Mailpit으로 대체하며 외부 수신 증거가 아니다.

## 영속성 및 백업/복구

```sh
scripts/local_backup.sh /absolute/private/new-snapshot
```

스크립트는 쓰기 서비스를 중지하고 DB(custom pg_dump)·미디어(tar.gz)·`.env`를 저장한 후 서비스를 다시 시작한다. 백업에는 자격값과 서명 키가 있으므로 Git에 넣지 않고 별도 디스크에 보관한다. Redis는 재시작 시 AOF로 보존하지만 이 백업에는 포함하지 않으므로 복구 후 재로그인이 필요하다.

원본을 보존하려면 새 체크아웃/독립 Compose 프로젝트에서 복구한다. snapshot/local.env를 새 체크아웃의 `.env`로 복사하고 COMPOSE_PROJECT_NAME과 API/ADMIN/MAIL 포트를 원본과 다르게 설정한다. 기존 이미지 URL의 호스트는 원래 주소임을 유의한다.

```sh
docker compose up -d --wait db redis
# PostGIS 이미지의 기본 DB에는 이미 tiger/topology 스키마가 있으므로
# template0으로 새 빈 논리 DB를 만든 뒤 복원한다. 기존 DB는 삭제하지 않는다.
docker compose exec -T db sh -c 'createdb -U "$POSTGRES_USER" -T template0 "${POSTGRES_DB}_restored"'
cat /absolute/private/snapshot/db.dump | docker compose exec -T db sh -c 'pg_restore -U "$POSTGRES_USER" -d "${POSTGRES_DB}_restored" --no-owner --exit-on-error'
cat /absolute/private/snapshot/media.tar.gz | docker compose run --rm --no-deps -T web sh -c 'mkdir -p /data/media; tar -xzf - -C /data/media'
# .env의 POSTGRES_DB를 위에서 복원한 <기존이름>_restored로 바꾼 후 실행한다.
docker compose up -d --wait web admin celery-worker celery-beat mailpit
```

빈 DB/미디어 볼륨에만 복구한다. 복구한 합성 계정 로그인, DB 행, 파일 해시, 서명 URL, 재시작 후 보존을 확인한 뒤에만 실제 이전을 계획한다. Kubernetes는 해당 PVC에서 같은 pg_dump/파일 스냅샷을 만들고 **별도 namespace/PVC**에서 복원 검증해야 한다. 대상 StorageClass에 따른 VolumeSnapshot 지원 여부는 아직 확인하지 않았다. AWS 운영 데이터 이관은 소유자 승인 후 별도 절차로 수행한다.

## 실행 결과

현재 통과 범위와 남은 Kubernetes/기기 검증은 [검증 기록](local-validation.md)에 별도로 정리했다.

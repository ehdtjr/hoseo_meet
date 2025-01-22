import http from 'k6/http';
import { check, sleep, fail } from 'k6';
import { Trend } from 'k6/metrics';

// 메시지 전송 시간 측정용 메트릭
let messageSendTime = new Trend('message_send_time');

// 1) 환경 변수에서 유저 수, 스트림 수 읽기 (기본값 설정)
const USERS_COUNT = parseInt(__ENV.USERS_COUNT) || 300;
const STREAM_COUNT = parseInt(__ENV.STREAM_COUNT) || 30;

// 2) per-stream 계산
const USERS_PER_STREAM = USERS_COUNT / STREAM_COUNT;

// 메시지 전송에 사용할 샘플 메시지
const messages = [
  'Hello World',
  'Test Message',
  'Random Content',
  'Another Test Message',
  'Message from load test',
];

// 유저 배열 생성
const users = Array.from({ length: USERS_COUNT }, (_, i) => ({
  email: `test${i + 1}@vision.hoseo.edu`,
  password: 'test123',
}));

// 스트림 ID (사전에 생성된 방의 ID)
const streamIds = [
  // 여기에는 *최대* 필요할 수 있는 개수를 넣어둡니다.
  // 실제 STREAM_COUNT만큼만 slice 해서 사용.
  1,2,3,4,5,6,7,8,9,10,
  11,12,13,14,15,16,17,18,19,20,
  21,22,23,24,25,26,27,28,29,30,
  31,32,33,34,35,36,37,38,39,40,
  41,42,43,44,45,46,47,48,49,50
];

// k6 시나리오 옵션
export let options = {
  setupTimeout: '360s',
  scenarios: {
    message_send_test: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        // 1분 동안 VU를 USERS_COUNT명까지 증가
        { duration: '1m', target: USERS_COUNT },
      ],
      gracefulRampDown: '0s',
    },
  },
};

// 로그인 엔드포인트
const loginUrl = 'http://localhost/api/v1/auth/login';

// setup 함수
export function setup() {
  // 스트림 ID 개수 확인 (실제 STREAM_COUNT만큼 사용)
  const neededStreams = streamIds.slice(0, STREAM_COUNT);

  if (!neededStreams || neededStreams.length !== STREAM_COUNT) {
    fail(`Expected ${STREAM_COUNT} stream IDs but got ${neededStreams.length}`);
  }

  let tokenMap = {};
  for (let i = 0; i < USERS_COUNT; i++) {
    const user = users[i];
    const loginPayload = `grant_type=password&username=${user.email}&password=${user.password}`;
    const loginHeaders = { 'Content-Type': 'application/x-www-form-urlencoded' };

    // 로그인 요청
    const loginRes = http.post(loginUrl, loginPayload, { headers: loginHeaders });
    const token = loginRes.json('access_token');

    // 로그인 체크
    const loginChecks = check(loginRes, {
      'login successful': (res) => res.status === 200,
      'token received': () => token !== undefined,
    });

    // 로그인 실패 시 전체 테스트 중단
    if (!loginChecks) {
      console.error(`Login failed for user ${user.email}. Status: ${loginRes.status}, Body: ${loginRes.body}`);
      fail(`Failed to login ${user.email}`);
    }

    // 토큰 저장
    if (token) {
      tokenMap[user.email] = token;
    } else {
      console.warn(`Failed to get token for ${user.email} (status: ${loginRes.status})`);
    }
  }

  return { tokenMap, streamIds: neededStreams };
}

// default 함수
export default function (data) {
  const { tokenMap, streamIds } = data;

  // VU 인덱스 (0부터 시작)
  const userIndex = (__VU - 1) % USERS_COUNT;
  const user = users[userIndex];

  // 토큰 확인
  const token = tokenMap[user.email];
  if (!token) {
    console.error(`No token found for ${user.email}`);
    // 로그인 토큰이 없으면 테스트를 진행할 수 없으므로 fail()
    fail(`No token found for ${user.email}`);
  }

  // 유저에게 할당될 스트림 결정
  const streamIndex = Math.floor(userIndex / USERS_PER_STREAM);
  const assignedStreamId = streamIds[streamIndex];

  // ---------- (1) 스트림 활성화 ----------
  {
    let activeUrl = `http://localhost/api/v1/stream/${assignedStreamId}/active?lifetime_seconds=3600`;
    let activeHeaders = {
      accept: 'application/json',
      Authorization: `Bearer ${token}`,
    };
    let activeRes = http.post(activeUrl, null, { headers: activeHeaders });
    check(activeRes, {
      'active success': (r) => r.status === 200 || r.status === 201,
    });
  }

  // ---------- (2) 메시지 전송 (시간 측정) ----------
  {
    const msgContent = messages[Math.floor(Math.random() * messages.length)];
    const start = Date.now(); // 시작 시각

    const messageUrl = `http://localhost/api/v1/messages/send/stream/${assignedStreamId}?lifetime_seconds=3600`;
    const messageHeaders = {
      accept: 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: `Bearer ${token}`,
    };
    const messagePayload = `message_content=${encodeURIComponent(msgContent)}`;

    const messageRes = http.post(messageUrl, messagePayload, { headers: messageHeaders });

    // 서버 응답이 200이 아닐 경우 체크 실패 (하지만 fail()로 테스트 중단은 안 함)
    const msgChecks = check(messageRes, {
      'message sent successfully': (r) => r.status === 200,
    });

    if (!msgChecks) {
      console.error(
        `Message send failed. Status: ${messageRes.status}, Body: ${messageRes.body}`
      );
      // fail() 대신 체크만 실패 처리 -> 전체 테스트 중단 방지
      // fail(`Message not sent successfully for user ${user.email}, stream ${assignedStreamId}`);
    }

    const end = Date.now();
    messageSendTime.add(end - start);
  }

  // ---------- (3) 스트림 비활성화 ----------
  {
    let deactiveUrl = `http://localhost/api/v1/stream/deactive?lifetime_seconds=3600`;
    let deactiveHeaders = {
      accept: 'application/json',
      Authorization: `Bearer ${token}`,
    };
    let deactiveRes = http.post(deactiveUrl, null, { headers: deactiveHeaders });
    check(deactiveRes, {
      'deactive success': (r) => r.status === 200 || r.status === 201,
    });
  }

  // 메시지 전송 후 1초 대기
  sleep(1);
}

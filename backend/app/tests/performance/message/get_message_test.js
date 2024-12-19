import http from 'k6/http';
import { check, sleep, fail } from 'k6';
import { Trend } from 'k6/metrics';

// 메시지 읽기 시간 측정용 메트릭
let messageReadTime = new Trend('message_read_time');

// 테스트에 사용할 상수들
const USERS_COUNT = 300;
const STREAM_COUNT = 30;
const USERS_PER_STREAM = USERS_COUNT / STREAM_COUNT; // 300 / 30 = 10

// 테스트에 사용할 유저 정보
const users = Array.from({ length: USERS_COUNT }, (_, i) => ({
  email: `test${i + 1}@vision.hoseo.edu`,
  password: 'test123',
}));

// 30개의 스트림 ID (실제 사전 준비 과정에서 얻은 ID를 기입해야 함)
const streamIds = [
    72101, 72102, 72103, 72104, 72105,
    72106, 72107, 72108, 72109, 72110,
    72111, 72112, 72113, 72114, 72115,
    72116, 72117, 72118, 72119, 72120,
    72121, 72122, 72123, 72124, 72125,
    72126, 72127, 72128, 72129, 72130,
];

// k6 시나리오 옵션 설정
export let options = {
  scenarios: {
    message_read_test: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '1m', target: USERS_COUNT }, // 1분 동안 VU를 300명까지 증가
      ],
      gracefulRampDown: '0s',
    },
  },
};

// 로그인 엔드포인트
const loginUrl = 'http://localhost/api/v1/auth/jwt/login';

// setup 함수:
// 모든 유저를 로그인해 tokenMap 생성
// streamIds를 검증한 뒤 tokenMap과 streamIds를 return
export function setup() {
  if (!streamIds || streamIds.length !== STREAM_COUNT) {
    fail(`Expected ${STREAM_COUNT} stream IDs but got ${streamIds ? streamIds.length : 0}`);
  }

  let tokenMap = {};
  for (let i = 0; i < USERS_COUNT; i++) {
    const user = users[i];
    const loginPayload = `grant_type=password&username=${user.email}&password=${user.password}`;
    const loginHeaders = { 'Content-Type': 'application/x-www-form-urlencoded' };

    const loginRes = http.post(loginUrl, loginPayload, { headers: loginHeaders });
    const token = loginRes.json('access_token');

    const loginChecks = check(loginRes, {
      'login successful': (res) => res.status === 200,
      'token received': () => token !== undefined,
    });

    if (!loginChecks) {
      console.error(`Login failed for user ${user.email}. Status: ${loginRes.status}, Body: ${loginRes.body}`);
      fail(`Failed to login ${user.email}`);
    }

    if (token) {
      tokenMap[user.email] = token;
    } else {
      console.warn(`Failed to get token for ${user.email} (status: ${loginRes.status})`);
    }
  }

  return { tokenMap, streamIds };
}

// default 함수:
// 각 VU(가상 사용자)가 할당된 스트림으로 메시지 조회 요청
export default function (data) {
  const { tokenMap, streamIds } = data;

  // 현재 VU 인덱스 (1부터 시작)
  const userIndex = (__VU - 1) % USERS_COUNT;
  const user = users[userIndex];

  const token = tokenMap[user.email];
  if (!token) {
    console.error(`No token found for ${user.email}`);
    fail(`No token found for ${user.email}`);
  }

  // 첫 번째 유저(인덱스 0) 스킵 (스트림 접근 권한 문제 또는 스트림 생성자로 가정)
  if (userIndex === 0) {
    sleep(1);
    return;
  }

  // 유저가 속한 스트림 인덱스 계산
  const streamIndex = Math.floor(userIndex / USERS_PER_STREAM);
  const assignedStreamId = streamIds[streamIndex];

  // 메시지 조회 엔드포인트
  const readUrl = `http://localhost/api/v1/messages/stream?stream_id=${assignedStreamId}`;
  const readHeaders = {
    'accept': 'application/json',
    'Authorization': `Bearer ${token}`,
  };

  // 시간 측정 시작
  const start = Date.now();

  // 메시지 조회 요청 (GET)
  const readRes = http.get(readUrl, { headers: readHeaders });

  // 메시지 조회 성공 여부 체크
  const readChecks = check(readRes, {
    'messages fetched successfully': (r) => r.status === 200,
  });

  if (!readChecks) {
    console.error(`Message read failed. Status: ${readRes.status}, Body: ${readRes.body}`);
    fail(`Message not fetched successfully for user ${user.email}, stream ${assignedStreamId}`);
  }

  // 시간 측정 종료
  const end = Date.now();
  messageReadTime.add(end - start);

  // 1초 대기 후 다음 요청
  sleep(1);
}

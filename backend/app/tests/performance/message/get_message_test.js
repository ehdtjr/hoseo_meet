import http from 'k6/http';
import { check, sleep, fail } from 'k6';
import { Trend } from 'k6/metrics';

// 메시지 읽기 시간 측정용 메트릭 (K6 커스텀 Trend)
let messageReadTime = new Trend('message_read_time');

// 테스트에 사용할 상수들
const USERS_COUNT = 500;    // 500명까지 테스트
const STREAM_COUNT = 50;    // 스트림 50개
const USERS_PER_STREAM = USERS_COUNT / STREAM_COUNT; // 500 / 50 = 10

// 테스트에 사용할 유저 정보
const users = Array.from({ length: USERS_COUNT }, (_, i) => ({
  email: `test${i + 1}@vision.hoseo.edu`,
  password: 'test123',
}));

// 50개의 스트림 ID (1 ~ 50까지)
const streamIds = [
  1,2,3,4,5,6,7,8,9,10,
  11,12,13,14,15,16,17,18,19,20,
  21,22,23,24,25,26,27,28,29,30,
  31,32,33,34,35,36,37,38,39,40,
  41,42,43,44,45,46,47,48,49,50,
];

// k6 시나리오 옵션 설정
export let options = {
  scenarios: {
    message_read_test: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        // 1분 동안 VU를 0 → 500명까지 점진적 증가
        { duration: '1m', target: USERS_COUNT },
      ],
      gracefulRampDown: '0s',
    },
  },
};

// 로그인 엔드포인트
const loginUrl = 'http://localhost/api/v1/auth/login';

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

    // 로그인 체크
    const loginChecks = check(loginRes, {
      'login successful': (res) => res.status === 200,
      'token received': () => token !== undefined,
    });

    if (!loginChecks) {
      console.error(
        `Login failed for user ${user.email}. Status: ${loginRes.status}, Body: ${loginRes.body}`
      );
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

  // userIndex를 기반으로 사용자가 속한 스트림 ID 결정
  const streamIndex = Math.floor(userIndex / USERS_PER_STREAM);
  const assignedStreamId = streamIds[streamIndex];

  // 메시지 조회 엔드포인트
  // 예: num_before=10 (메시지 조회 시 이전 메시지 10개 불러오는 로직)
  const readUrl = `http://localhost/api/v1/messages/stream?stream_id=${assignedStreamId}&num_after=10`;
  const readHeaders = {
    accept: 'application/json',
    Authorization: `Bearer ${token}`,
  };

  // 메시지 조회 요청 (GET)
  const readRes = http.get(readUrl, { headers: readHeaders });

  // 메시지 조회 성공 여부 체크
  const readChecks = check(readRes, {
    'messages fetched successfully': (r) => r.status === 200,
  });

  if (!readChecks) {
    console.error(
      `Message read failed. Status: ${readRes.status}, Body: ${readRes.body}`
    );
    fail(`Message not fetched successfully for user ${user.email}, stream ${assignedStreamId}`);
  }

  // ----------- 시간 측정: K6 내장 타이밍 활용 ----------- //
  // 요청-응답에 걸린 전체 시간(ms)을 K6가 측정해둔 res.timings.duration 값으로 수집
  messageReadTime.add(readRes.timings.duration);

  // 1초 대기 후 다음 요청
  sleep(1);
}

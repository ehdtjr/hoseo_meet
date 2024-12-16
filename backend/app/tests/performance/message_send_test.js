import http from 'k6/http';
import { check, sleep, fail } from 'k6';
import { Trend } from 'k6/metrics';

// 메시지 전송 시간 측정용 메트릭
let messageSendTime = new Trend('message_send_time');

// 테스트에 사용할 상수들
const USERS_COUNT = 300;
const STREAM_COUNT = 30; // 한 방에 10명씩 총 30개의 방
const USERS_PER_STREAM = USERS_COUNT / STREAM_COUNT; // 300 / 30 = 10

// 메시지 전송에 사용할 샘플 메시지들
const messages = [
  'Hello World',
  'Test Message',
  'Random Content',
  'Another Test Message',
  'Message from load test'
];

// 300명의 유저 정의 (사전 준비 스크립트에서 생성한 계정과 동일하다고 가정)
// 인증 필요하므로 이 유저들을 로그인해 토큰을 획득할 것임
const users = Array.from({ length: USERS_COUNT }, (_, i) => ({
  email: `test${i + 1}@vision.hoseo.edu`,
  password: 'test123',
}));

// 하드코딩된 streamIds (사전 준비 스크립트에서 생성한 스트림 IDs)
// 30개 스트림 ID를 하드코딩 (72071 ~ 72100)
const streamIds = [
  72071, 72072, 72073, 72074, 72075,
  72076, 72077, 72078, 72079, 72080,
  72081, 72082, 72083, 72084, 72085,
  72086, 72087, 72088, 72089, 72090,
  72091, 72092, 72093, 72094, 72095,
  72096, 72097, 72098, 72099, 72100
];

// k6 시나리오 옵션 설정
export let options = {
  scenarios: {
    message_send_test: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '1m', target: 300 }, // 30초 동안 VU를 300명까지 증가
      ],
      gracefulRampDown: '0s',
    },
  },
};

// 로그인 엔드포인트
const loginUrl = 'http://localhost/api/v1/auth/jwt/login';

// setup 함수:
// 테스트 시작 전 모든 유저를 로그인해 tokenMap 생성
// streamIds를 검증한 뒤 tokenMap과 streamIds를 return
export function setup() {
  // streamIds 검증
  if (!streamIds || streamIds.length !== STREAM_COUNT) {
    fail(`Expected ${STREAM_COUNT} stream IDs but got a different amount`);
  }

  // 모든 유저에 대해 로그인 요청을 보내 토큰 획득
  let tokenMap = {};
  for (let i = 0; i < USERS_COUNT; i++) {
    const user = users[i];
    const loginPayload = `grant_type=password&username=${user.email}&password=${user.password}`;
    const loginHeaders = { 'Content-Type': 'application/x-www-form-urlencoded' };

    // 로그인 요청
    const loginRes = http.post(loginUrl, loginPayload, { headers: loginHeaders });
    const token = loginRes.json('access_token');

    // 로그인 성공/토큰 획득 여부 체크
    check(loginRes, {
      'login successful': (res) => res.status === 200,
      'token received': () => token !== undefined,
    });

    // 토큰 저장
    if (token) {
      tokenMap[user.email] = token;
    } else {
      console.warn(`Failed to get token for ${user.email} (status: ${loginRes.status})`);
    }
  }

  // tokenMap과 streamIds 반환
  return { tokenMap, streamIds };
}

// default 함수:
// VU(가상 사용자) 마다 할당된 유저정보로 메시지 전송 요청
// setup에서 얻은 tokenMap을 이용해 인증된 상태로 메시지 전송
export default function (data) {
  const { tokenMap, streamIds } = data;

  // 현재 VU 인덱스 계산 (__VU는 k6에서 제공하는 현재 VU 번호)
  const userIndex = (__VU - 1) % USERS_COUNT;
  const user = users[userIndex];
  const token = tokenMap[user.email];

  // 토큰 없으면 실패 처리
  if (!token) {
    fail(`No token found for ${user.email}`);
  }

  // 유저가 속한 스트림 인덱스 계산
  const streamIndex = Math.floor(userIndex / USERS_PER_STREAM);
  const assignedStreamId = streamIds[streamIndex];

  // 랜덤 메시지 선택
  const msgContent = messages[Math.floor(Math.random() * messages.length)];

  // 시간 측정 시작
  const start = Date.now();

  // 메시지 전송 엔드포인트 (인증 필요)
  const messageUrl = `http://localhost/api/v1/messages/send/stream/${assignedStreamId}?lifetime_seconds=3600`;
  const messageHeaders = {
    'accept': 'application/json',
    'Content-Type': 'application/x-www-form-urlencoded',
    'Authorization': `Bearer ${token}`, // 인증 헤더 추가
  };
  const messagePayload = `message_content=${encodeURIComponent(msgContent)}`;

  // 메시지 전송 요청
  const messageRes = http.post(messageUrl, messagePayload, { headers: messageHeaders });

  // 메시지 전송 성공 여부 체크
  check(messageRes, {
    'message sent successfully': (r) => r.status === 200,
  });

  // 시간 측정 종료
  const end = Date.now();
  messageSendTime.add(end - start);

  // 1초 대기 후 다음 요청
  sleep(1);
}

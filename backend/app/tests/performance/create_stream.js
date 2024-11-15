import http from 'k6/http';
import { check, sleep } from 'k6';

// 사용자 계정 생성 (테스트용 계정 목록)
const users = Array.from({ length: 500 }, (_, i) => ({
    email: `test${i + 1}@vision.hoseo.edu`,
    password: 'test123',
}));

// 로그인 토큰 저장소
let tokens = [];

// k6 옵션 설정
export let options = {
    scenarios: {
        login_and_create_stream: {
            executor: 'ramping-vus', // VUs를 점진적으로 증가
            startVUs: 0,
            stages: [
                { duration: '1m', target: 100 }, // 1분 동안 100명의 VUs 도달
                { duration: '2m', target: 200 }, // 2분 동안 200명의 VUs로 증가
                { duration: '3m', target: 300 }, // 2분 동안 200명의 VUs로 증가
                { duration: '3m', target: 400 }, // 2분 동안 200명의 VUs로 증가
                { duration: '1m', target: 0 },   // 1분 동안 VUs 감소
            ],
            exec: 'testStreamCreation', // 실행할 함수 지정
        },
    },
};

// 로그인 함수
function login(user) {
    const url = 'http://127.0.0.1/api/v1/auth/jwt/login';
    const payload = `grant_type=password&username=${user.email}&password=${user.password}`;
    const params = { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } };

    const res = http.post(url, payload, params);

    if (res.status === 200) {
        const body = JSON.parse(res.body);
        return body.access_token; // JWT 토큰 반환
    } else {
        console.log(`Login failed for user ${user.email}: ${res.status}`);
        return null;
    }
}

// 스트림 생성 요청 함수
function createStream(token) {
    const url = 'http://127.0.0.1/api/v1/stream/create/';
    const payload = JSON.stringify({
        name: "치킨해요",
        type: "배달",
    });
    const params = {
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`, // 인증 헤더 추가
        },
    };

    const res = http.post(url, payload, params);

    check(res, {
        'is status 201': (r) => r.status === 201, // HTTP 201 Created 확인
    });

    if (res.status !== 201) {
        console.log(`Stream creation failed: ${res.status} - ${res.body}`);
    }
}

// 부하 테스트 함수
export function testStreamCreation() {
    const vuIndex = (__VU - 1) % users.length; // VU에 따른 사용자 인덱스 선택
    const user = users[vuIndex];

    // 로그인하고 토큰을 가져옵니다.
    let token = tokens[vuIndex];
    if (!token) {
        token = login(user);
        if (token) tokens[vuIndex] = token; // 로그인한 토큰을 저장
    }

    if (token) {
        // 스트림 생성 요청 실행
        createStream(token);
    }

    sleep(1); // 1초 대기
}

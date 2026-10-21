import http from 'k6/http';
import { check, sleep, fail } from 'k6';

// 500명의 고유 사용자 계정 생성
const users = Array.from({ length: 500 }, (_, i) => ({
    email: `test${i + 1}@vision.hoseo.edu`,
    password: 'test123',
}));

export let options = {
    scenarios: {
        subscription_test: {
            executor: 'ramping-vus',
            startVUs: 10,
            stages: [
                { duration: '1m', target: 500 }, // 30초 동안 동시 사용자 500명으로 증가
            ],
            gracefulRampDown: '0s',
        },
    },
};

// 로그인 후 구독 요청을 보내는 테스트
export default function () {
    const user = users[__VU % users.length]; // 가상 사용자 번호로 계정 선택

    // 1. 로그인 요청을 통해 토큰 획득
    const loginUrl = 'http://127.0.0.1:8000/api/v1/auth/jwt/login';
    const loginHeaders = { 'Content-Type': 'application/x-www-form-urlencoded' };
    const loginPayload = `grant_type=password&username=${user.email}&password=${user.password}`;

    const loginRes = http.post(loginUrl, loginPayload, { headers: loginHeaders });
    const token = loginRes.json('access_token');

    check(loginRes, {
        'login successful': (res) => res.status === 200,
        'token received': () => token !== undefined,
    });

    if (!token) {
        fail('Failed to obtain token');
    }

    // 2. 구독 요청에 인증 토큰 포함
    const subscriptionUrl = 'http://127.0.0.1:8000/api/v1/users/me/subscriptions?lifetime_seconds=3600';
    const subscriptionHeaders = {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`, // 인증 토큰 추가
    };
    const subscriptionPayload = JSON.stringify({
        stream_id: 1, // 0번 방에 구독 요청
    });

    const subscriptionRes = http.post(subscriptionUrl, subscriptionPayload, { headers: subscriptionHeaders });

    check(subscriptionRes, {
        'subscription successful': (res) => res.status === 200,
    });
}

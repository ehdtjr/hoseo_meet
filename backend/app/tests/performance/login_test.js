import http from 'k6/http';
import { check, sleep, fail } from 'k6';

// 사용자 계정 목록 생성
const users = Array.from({ length: 300 }, (_, i) => ({
    username: `test${i + 1}@example.com`,
    password: 'testpassword123'
}));

export let options = {
    scenarios: {
        login_test: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '30s', target: 500 }, // 10초 동안 300명의 가상 유저가 로그인 요청
            ],
            exec: 'loginScenario', // 로그인 시나리오 함수
        },
    },
};

// 로그인 시나리오
export function loginScenario() {
    const userIndex = __VU - 1; // 가상 유저 ID를 통해 계정 인덱스 선택
    const { username, password } = users[userIndex % users.length];
    const loginPayload = `grant_type=password&username=${username}&password=${password}&scope=&client_id=&client_secret=`;
    const loginHeaders = { 'Content-Type': 'application/x-www-form-urlencoded', 'accept': 'application/json' };

    const res = http.post('http://127.0.0.1:8000/api/v1/auth/jwt/login?lifetime_seconds=3600', loginPayload, { headers: loginHeaders });

    // 응답이 200인지 확인하고 JSON을 파싱하여 토큰을 추출합니다.
    if (res.status === 200) {
        let token;
        try {
            const responseBody = JSON.parse(res.body);
            token = responseBody.access_token;

            check(token, { 'token is present': (t) => t !== undefined });
        } catch (error) {
            console.log(`Failed to parse JSON: ${res.body}`);
            fail(`Invalid JSON format: ${error.message}`);
        }
    } else {
        console.log(`Login failed for user ${username}: ${res.status} - ${res.body}`);
    }

    sleep(1); // 요청 간격
}

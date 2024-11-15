import http from 'k6/http';
import { check, sleep, fail } from 'k6';

// 사용자 계정 목록 생성 (500개의 고유 이메일 주소)
const users = Array.from({ length: 500 }, (_, i) => ({
    email: `test${i + 1}@vision.hoseo.edu`,
    password: 'test123',
    is_active: true,
    is_superuser: false,
    is_verified: true, // 이메일 인증 상태로 설정
    name: `User${i + 1}`,
    gender: 'unknown',
    profile: 'default_profile'
}));

export let options = {
    scenarios: {}
};

// 선택된 모드에 따라 시나리오 설정
const mode = __ENV.MODE || 'both';

if (mode === 'register') {
    options.scenarios.registration_test = {
        executor: 'constant-vus',
        vus: 80, // 동시에 수행할 가상 사용자 수
        duration: '1m', // 1분 동안 테스트 수행
        exec: 'registerUser', // 사용자 등록 시나리오 함수
    };
} else if (mode === 'login') {
    options.scenarios.login_test = {
        executor: 'ramping-vus',
        startVUs: 0,
        stages: [
            { duration: '1m', target: 80 }, // 30초 동안 500명의 가상 유저가 로그인 요청
        ],
        exec: 'loginScenario', // 로그인 시나리오 함수
    };
}

// 사용자 등록 시나리오
export function registerUser() {
    const userIndex = __VU - 1; // 가상 유저 ID로 계정 인덱스 선택
    const user = users[userIndex % users.length]; // 계정 정보 선택

    const registerPayload = JSON.stringify({
        email: user.email,
        password: user.password,
        is_active: user.is_active,
        is_superuser: user.is_superuser,
        is_verified: user.is_verified,
        name: user.name,
        gender: user.gender,
        profile: user.profile
    });

    const registerHeaders = { 'Content-Type': 'application/json', 'accept': 'application/json' };
    const res = http.post('http://localhost:80/api/v1/auth/register', registerPayload, { headers: registerHeaders });

    // 응답 상태 확인
    const success = check(res, {
        'is status 201': (r) => r.status === 201,
    });

    if (!success) {
        console.log(`Registration failed for user ${user.email}: ${res.status} - ${res.body}`);
    }
}

// 로그인 시나리오
export function loginScenario() {
    const userIndex = __VU - 1; // 가상 유저 ID를 통해 계정 인덱스 선택
    const user = users[userIndex % users.length]; // 등록된 사용자 계정 선택

    const loginPayload = `grant_type=password&username=${user.email}&password=${user.password}&scope=&client_id=&client_secret=`;
    const loginHeaders = { 'Content-Type': 'application/x-www-form-urlencoded', 'accept': 'application/json' };

    const res = http.post('http://localhost:80/api/v1/auth/jwt/login?lifetime_seconds=3600', loginPayload, { headers: loginHeaders });

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
        console.log(`Login failed for user ${user.email}: ${res.status} - ${res.body}`);
    }
    sleep(1);
}

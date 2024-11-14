import http from 'k6/http';
import { check, fail } from 'k6';
import { SharedArray } from 'k6/data';

const users = new SharedArray("users", function () {
    return Array.from({ length: 100 }, (_, i) => ({
        email: `test${i + 1}@vision.hoseo.edu`,
        password: 'test123'
    }));
});

export let options = {
    vus: 100, // 가상 사용자 수
    duration: '30s', // 테스트 지속 시간
    setupTimeout: '5m' // setup 단계 타임아웃 설정
};

// setup 단계에서 각 사용자마다 로그인하여 토큰 획득
export function setup() {
    const tokens = users.map(user => {
        const loginPayload = `grant_type=password&username=${user.email}&password=${user.password}&scope=&client_id=&client_secret=`;
        const loginHeaders = { 'Content-Type': 'application/x-www-form-urlencoded', 'accept': 'application/json' };

        const res = http.post('http://localhost/api/v1/auth/jwt/login?lifetime_seconds=3600', loginPayload, { headers: loginHeaders });

        if (res.status === 200) {
            const responseBody = JSON.parse(res.body);
            const token = responseBody.access_token;
            if (!token) fail(`Unable to obtain token for ${user.email}`);
            return token;
        } else {
            fail(`Login failed for ${user.email}: ${res.status} - ${res.body}`);
        }
    });

    return { tokens }; // 100명의 토큰 리스트 반환
}

// 각 사용자별 메시지 전송 시나리오
export default function (data) {
    const token = data.tokens[__VU % users.length]; // 각 VU마다 자신의 토큰 사용
    const messageUrl = 'http://localhost/api/v1/messages/send/stream/1?lifetime_seconds=3600';
    const messageHeaders = {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        'accept': 'application/json'
    };

    const messagePayload = 'message_content=string1';

    const res = http.post(messageUrl, messagePayload, { headers: messageHeaders });

    check(res, {
        'message sent successfully': (r) => r.status === 200
    });
}

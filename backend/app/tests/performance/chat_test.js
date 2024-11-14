import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep, fail } from 'k6';

// 사용자 계정 목록 생성 (500개의 고유 이메일 주소)
const users = Array.from({ length: 500 }, (_, i) => ({
    email: `test${i + 1}@vision.hoseo.edu`,
    password: 'test123',
    is_active: true,
    is_superuser: false,
    is_verified: true,
    name: `User${i + 1}`,
    gender: 'unknown',
    profile: 'default_profile'
}));

export let options = {
    scenarios: {
        websocket_message_test: {
            executor: 'ramping-vus',
            startVUs: 10,
            stages: [
                { duration: '5m', target: 500 },
            ],
            gracefulRampDown: '0s',
        },
    },
};

// 로그인 후 웹소켓 연결 및 메시지 전송 테스트
export default function () {
    const user = users[__VU % users.length]; // 가상 사용자 번호로 배열 인덱스 선택

    // 1. 로그인 요청을 통해 토큰 획득
    const loginUrl = 'http://localhost/api/v1/auth/jwt/login';
    const loginHeaders = { 'Content-Type': 'application/x-www-form-urlencoded' };
    const loginPayload = `grant_type=password&username=${user.email}&password=${user.password}`;

    const loginRes = http.post(loginUrl, loginPayload, { headers: loginHeaders });
    const token = loginRes.json('access_token');

    check(loginRes, {
        'login successful': (res) => res.status === 200,
        'token received': () => token !== undefined,
    });

    if (!token) {
        fail('Unable to obtain token');
    }

    // 2. 웹소켓 연결 및 메시지 수신 대기
    const wsUrl = 'ws://localhost/api/v1/events/connect';
    const response = ws.connect(wsUrl, {
        headers: {
            'Sec-WebSocket-Protocol': token, // 웹소켓 연결 시 Sec-WebSocket-Protocol로 토큰 전송
        },
    }, function (socket) {
        socket.on('open', function () {
            console.log(`WebSocket connection opened for ${user.email}`);

            // 3. 메시지 전송 요청 (웹소켓 연결 후 API 호출)
            const messageUrl = 'http://localhost/api/v1/messages/send/stream/1?lifetime_seconds=3600';
            const messageHeaders = {
                'accept': 'application/json',
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': `Bearer ${token}`, // 인증 토큰 추가
            };
            const messagePayload = 'message_content=string1';

            const messageRes = http.post(messageUrl, messagePayload, { headers: messageHeaders });

            check(messageRes, {
                'message sent successfully': (res) => res.status === 200,
            });

            // 4. 메시지 수신 확인
            socket.on('message', (message) => {
                console.log(`Received message for ${user.email}:`, message);
                check(message, {
                    'Received expected response': (msg) => msg.includes('string1'), // 메시지 내용 확인
                });
            });
        });

        socket.on('close', () => console.log(`WebSocket connection closed for ${user.email}`));

        socket.on('error', (e) => {
            console.log(`WebSocket connection error for ${user.email}:`, e);
            fail('WebSocket connection failed');
        });
    });

    check(response, { 'WebSocket connection was successful': (res) => res && res.status === 101 });
    sleep(1);
}

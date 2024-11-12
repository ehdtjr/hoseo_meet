import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep, fail } from 'k6';

// 사용자 계정 생성
const users = Array.from({ length: 500 }, (_, i) => ({
    username: `test${i + 1}@example.com`,
    password: 'testpassword123'
}));

let tokens = {}; // 사용자별 토큰을 저장할 객체

export let options = {
    scenarios: {
        continuous_login: {
            executor: 'constant-vus',  // 지속적으로 로그인 시도
            vus: 50,                   // 동시 사용자 30명 유지
           duration: '10s',            // 1분간 지속
        },
    },
};

// 1. 로그인 시나리오
function loginScenario(userIndex) {
    if (userIndex >= users.length) {
        console.log(`Invalid user index: ${userIndex}`);
        fail(`User index ${userIndex} is out of bounds`);
        return;
    }

    const { username, password } = users[userIndex];
    const loginPayload = `grant_type=password&username=${username}&password=${password}&scope=&client_id=&client_secret=`;
    const loginHeaders = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'accept': 'application/json'
    };

    const start = new Date().getTime();
    const loginRes = http.post('http://127.0.0.1:8000/api/v1/auth/jwt/login?lifetime_seconds=3600', loginPayload, { headers: loginHeaders });
    const duration = new Date().getTime() - start;

    console.log(`Login duration for user ${username}: ${duration}ms`);

    if (loginRes.status === 200 && loginRes.body) {
        try {
            const responseBody = JSON.parse(loginRes.body);
            tokens[username] = responseBody.access_token;
            check(tokens[username], { 'token is present': (t) => t !== undefined });
        } catch (error) {
            console.log(`Failed to parse login response for user ${username}: ${loginRes.body}`);
            fail(`Parsing error: ${error.message}`);
        }
    } else {
        console.log(`Login failed for user ${username}: ${loginRes.status} - ${loginRes.body}`);
        fail(`Login failed with status ${loginRes.status}`);
    }
    sleep(1);
}

// 2. WebSocket 연결 시나리오
function websocketScenario(userIndex) {
    const { username } = users[userIndex];
    const token = tokens[username];

    if (!token) {
        fail(`Token not found for user ${username}. Did the loginScenario run successfully?`);
    }

    const url = 'ws://127.0.0.1:8000/api/v1/events/connect';
    const wsHeaders = { 'Sec-WebSocket-Protocol': token };

    const start = new Date().getTime();
    const res = ws.connect(url, { headers: wsHeaders }, function (socket) {
        socket.on('open', () => {
            console.log(`WebSocket connection established for user: ${username}`);
        });

        socket.on('message', (msg) => {
            console.log(`Received message for user ${username}: ${msg}`);
        });

        socket.on('close', () => {
            console.log(`WebSocket connection closed for user: ${username}`);
        });

        socket.on('error', (e) => {
            console.log(`WebSocket error for user ${username}: ${e.error()}`);
            fail(`WebSocket connection failed for user ${username}`);
        });

        socket.setTimeout(() => socket.close(), 60000);
    });
    const duration = new Date().getTime() - start;
    console.log(`WebSocket duration for user ${username}: ${duration}ms`);

    check(res, { 'WebSocket connection successful': (r) => r && r.status === 101 });
    sleep(1);
}

// 3. 메시지 전송 시나리오
function sendMessageScenario(userIndex) {
    const { username } = users[userIndex];
    const token = tokens[username];

    if (!token) {
        fail(`Token not found for user ${username}. Did the loginScenario run successfully?`);
    }

    const authHeaders = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/x-www-form-urlencoded' };
    const stream_id = 2;
    const messagePayload = 'message_content=Hello, this is a test message!';

    const start = new Date().getTime();
    const sendMessageRes = http.post(
        `http://127.0.0.1:8000/api/v1/messages/send/stream/${stream_id}`,
        messagePayload,
        { headers: authHeaders }
    );
    const duration = new Date().getTime() - start;
    console.log(`Message send duration for user ${username}: ${duration}ms`);

    check(sendMessageRes, { 'message sent successfully': (res) => res.status === 200 });
    sleep(1);
}

// 4. /test/ping 엔드포인트 테스트 시나리오
function pingScenario() {
    const start = new Date().getTime();
    const pingRes = http.get('http://127.0.0.1:8000/api/v1/test/ping');
    const duration = new Date().getTime() - start;

    console.log(`Ping duration: ${duration}ms`);

    check(pingRes, {
        'ping successful': (res) => res.status === 200,
        'response time below 200ms': (res) => duration < 200
    });
    sleep(1);
}

// 전체 시나리오: 로그인 -> WebSocket 연결 -> 메시지 전송
// 전체 시나리오: 로그인 -> WebSocket 연결 -> 메시지 전송
export default function () {
    const userIndex = __VU - 1;
    loginScenario(userIndex);
    //pingScenario();
    //websocketScenario(userIndex);
    //sendMessageScenario(userIndex);
}

import http from 'k6/http';
import { check, sleep} from 'k6';

export let options = {
    scenarios: {
        ping_test: {
            executor: 'constant-vus',
            vus: 500,
            duration: '10m', // 1분 동안 테스트 수행
            exec: 'pingScenario', // ping 테스트 시나리오 함수
        },
    },
};

// /api/v1/test/ping 엔드포인트 부하 테스트 시나리오
export function pingScenario() {
    const url = 'http://127.0.0.1/api/v1/test/ping';
    const headers = { 'accept': 'application/json' };

    const res = http.get(url, { headers: headers });

    // 응답 상태와 본문을 확인
    const success = check(res, {
        'status is 200': (r) => r && r.status === 200,
        'response body is correct': (r) => {
            try {
                const body = r.json();
                return body && body.message === 'pong';
            } catch (e) {
                console.log(`Error parsing JSON: ${e.message}`);
                return false;
            }
        },
    });

    if (!success) {
        console.log(`Ping request failed: ${res.status} - ${res.body}`);
    }
    sleep(1);
}

from locust import User, between, task


class WebSocketUser(User):
    wait_time = between(1, 5)  # 요청 사이의 대기 시간 (1초에서 5초 사이)

    @task
    def connect_to_ws(self):
        with self.client.websocket_connect("/connect") as ws:
            # WebSocket 연결 후 메시지 송수신
            ws.send_json({"type": "ping"})
            while True:
                try:
                    message = ws.receive_text(timeout=5)
                    if message:
                        print(f"Received message: {message}")
                except Exception as e:
                    print(f"Connection closed or error occurred: {e}")
                    break

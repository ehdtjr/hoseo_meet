from prometheus_client import Gauge

# WebSocket 연결된 접속자 수를 추적하는 Gauge 메트릭 생성
connected_websockets = Gauge("connected_websockets", "Number of active WebSocket connections")
#!/bin/bash

BASE_URL="https://www.campus-meet.shop"
DURATION=300  # 5분 동안 테스트
MAX_CONCURRENT_USERS=1000
SURGE_DURATION=60  # 트래픽 급증 지속 시간 (초)

# 엔드포인트 목록
ENDPOINTS=(
    "/api/chat"
    "/api/v1/auth/me"
    "/api/v1/auth/verify-email"
    "/docs"
)

start_time=$(date +%s)
end_time=$((start_time + DURATION))

run_test() {
    local concurrent=$1
    local endpoint=$2
    ab -c $concurrent -n $((concurrent * 2)) -t 30 "${BASE_URL}${endpoint}" > /dev/null 2>&1 &
}

get_current_users() {
    local current_time=$1
    local elapsed_time=$((current_time - start_time))
    local cycle=$((elapsed_time / SURGE_DURATION))
    
    if [ $((cycle % 2)) -eq 0 ]; then
        echo $MAX_CONCURRENT_USERS
    else
        echo $((MAX_CONCURRENT_USERS / 10))
    fi
}

while [ $(date +%s) -lt $end_time ]; do
    current_time=$(date +%s)
    current_users=$(get_current_users $current_time)

    for endpoint in "${ENDPOINTS[@]}"; do
        users_per_endpoint=$((current_users / ${#ENDPOINTS[@]}))
        run_test $users_per_endpoint $endpoint
    done

    echo "Current time: $(date), Active users: $current_users"
    sleep 15
done

wait
echo "Load test completed."
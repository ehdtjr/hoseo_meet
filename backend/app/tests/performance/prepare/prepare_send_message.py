import requests
import json
import sys

USERS_COUNT = 300
STREAM_COUNT = 30  # 한 방에 10명씩 총 30개의 방
USERS_PER_STREAM = USERS_COUNT // STREAM_COUNT  # 300 // 30 = 10

login_url = 'http://localhost/api/v1/auth/jwt/login'
create_stream_url = 'http://localhost/api/v1/stream/create/'
subscribe_url = 'http://localhost/api/v1/users/me/subscriptions'

users = [{
    "email": f"test{i+1}@vision.hoseo.edu",
    "password": "test123"
} for i in range(USERS_COUNT)]

def main():
    # 1. 모든 유저 로그인 및 토큰 획득
    token_map = {}
    for i, user in enumerate(users):
        login_payload = {
            "grant_type": "password",
            "username": user["email"],
            "password": user["password"]
        }
        headers = {"Content-Type": "application/x-www-form-urlencoded"}
        res = requests.post(login_url, data=login_payload, headers=headers)
        if res.status_code != 200:
            print(f"Failed to login {user['email']}, status: {res.status_code}", file=sys.stderr)
            continue
        data = res.json()
        token = data.get('access_token')
        if token:
            token_map[user["email"]] = token
        else:
            print(f"No token for {user['email']}", file=sys.stderr)

    if len(token_map) == 0:
        print("No tokens obtained. Check credentials.", file=sys.stderr)
        sys.exit(1)

    # 방 생성용 유저를 첫 번째 유저로 가정
    creator_email = users[0]["email"]
    creator_token = token_map.get(creator_email)
    if not creator_token:
        # 첫 번째 유저에게 토큰이 없다면 토큰 있는 유저 아무나 선택
        any_user_with_token = next((u for u in token_map.keys()), None)
        if not any_user_with_token:
            print("No available token to create streams.", file=sys.stderr)
            sys.exit(1)
        creator_email = any_user_with_token
        creator_token = token_map[creator_email]

    create_headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {creator_token}'
    }

    # 2. 30개 방 생성
    stream_ids = []
    for i in range(STREAM_COUNT):
        create_payload = {
            "name": f"Stream-{i+1}",
            "type": "배달"
        }
        res = requests.post(create_stream_url, json=create_payload, headers=create_headers)
        if res.status_code != 201:
            print(f"Failed to create stream {i+1}, status: {res.status_code}", file=sys.stderr)
            sys.exit(1)
        data = res.json()
        stream_id = data.get('id')
        if not stream_id:
            print(f"No id returned for stream {i+1}", file=sys.stderr)
            sys.exit(1)
        # 생성한 유저는 자동 구독이므로 별도 처리 불필요
        stream_ids.append(stream_id)

    # 3. 유저를 30개 그룹으로 나누어 각 그룹을 한 방에 구독 (한 방당 10명)
    for i, user in enumerate(users):
        # 방 생성용 유저(creator_email)은 이미 구독 상태이므로 스킵
        if user["email"] == creator_email:
            continue

        token = token_map.get(user["email"])
        if not token:
            continue
        stream_index = i // USERS_PER_STREAM
        assigned_stream_id = stream_ids[stream_index]

        sub_payload = {"stream_id": assigned_stream_id}
        headers = {
            "Content-Type": "application/json",
            "Authorization": f'Bearer {token}'
        }
        sub_res = requests.post(subscribe_url, json=sub_payload, headers=headers)
        if sub_res.status_code != 200:
            print(f"User {user['email']} failed to subscribe to stream {assigned_stream_id}, status: {sub_res.status_code}", file=sys.stderr)

    # 결과 저장
    result_data = {
        "streamIds": stream_ids
    }
    with open('streams_and_tokens.json', 'w') as f:
        json.dump(result_data, f, indent=2)
    print("Pre-step completed. Data saved to streams_and_tokens.json")


if __name__ == "__main__":
    main()

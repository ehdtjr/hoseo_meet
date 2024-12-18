import requests
import json
import sys
import logging
from typing import Dict, List

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='[%(levelname)s] %(message)s')

# 상수 설정
BASE_URL = 'http://localhost/api/v1'
LOGIN_URL = f'{BASE_URL}/auth/jwt/login'
CREATE_STREAM_URL = f'{BASE_URL}/stream/create/'
SUBSCRIBE_URL = f'{BASE_URL}/users/me/subscriptions'

USERS_COUNT = 300
STREAM_COUNT = 30  # 한 방에 10명씩, 총 30개의 방
USERS_PER_STREAM = USERS_COUNT // STREAM_COUNT  # 300 // 30 = 10

USERS = [{
    "email": f"test{i + 1}@vision.hoseo.edu",
    "password": "test123"
} for i in range(USERS_COUNT)]


def login_all_users(users: List[Dict[str, str]]) -> Dict[str, str]:
    """ 모든 유저 로그인하여 토큰 맵을 반환 """
    token_map = {}
    for user in users:
        login_payload = {
            "grant_type": "password",
            "username": user["email"],
            "password": user["password"]
        }
        headers = {"Content-Type": "application/x-www-form-urlencoded"}

        try:
            res = requests.post(LOGIN_URL, data=login_payload, headers=headers,
                                timeout=5)
        except requests.RequestException as e:
            logging.error(f"{user['email']} 로그인 요청 중 오류 발생: {e}")
            continue

        if res.status_code != 200:
            logging.error(f"{user['email']} 로그인 실패, 상태코드: {res.status_code}")
            continue

        data = res.json()
        token = data.get('access_token')
        if token:
            token_map[user["email"]] = token
        else:
            logging.error(f"{user['email']} 토큰 획득 실패")

    if not token_map:
        logging.error("단 한 명의 토큰도 획득하지 못했습니다. 자격 증명을 확인하세요.")
        sys.exit(1)

    return token_map


def create_streams(token: str, count: int) -> List[str]:
    """ 지정한 토큰을 사용하여 count 개의 스트림을 생성하고 스트림 ID 리스트 반환 """
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {token}'
    }
    stream_ids = []

    for i in range(count):
        create_payload = {
            "name": f"Stream-{i + 1}",
            "type": "배달"
        }
        try:
            res = requests.post(CREATE_STREAM_URL, json=create_payload,
                                headers=headers, timeout=5)
        except requests.RequestException as e:
            logging.error(f"스트림 {i + 1} 생성 요청 중 오류 발생: {e}")
            continue

        if res.status_code != 201:
            logging.error(f"스트림 {i + 1} 생성 실패, 상태코드: {res.status_code}")
            continue

        data = res.json()
        stream_id = data.get('id')
        if not stream_id:
            logging.error(f"스트림 {i + 1} ID 없음")
            continue

        logging.info(f"스트림 {i + 1} 생성 성공: ID={stream_id}")
        stream_ids.append(stream_id)

    if len(stream_ids) < count:
        logging.warning(f"요청한 {count}개 중 {len(stream_ids)}개의 스트림만 생성되었습니다.")

    return stream_ids


def subscribe_users_to_streams(users: List[Dict[str, str]],
                               token_map: Dict[str, str], stream_ids: List[str],
                               creator_email: str):
    """
    유저들을 30개 그룹으로 나누어 각 그룹을 해당 스트림에 구독시킨다.
    이미 스트림 생성자인 경우 생략.
    """
    for i, user in enumerate(users):
        if user["email"] == creator_email:
            continue  # 스트림 생성자는 이미 자동 구독 상태

        token = token_map.get(user["email"])
        if not token:
            logging.warning(f"{user['email']} 구독 불가: 토큰 없음")
            continue

        # 배정할 스트림 결정
        stream_index = i // USERS_PER_STREAM
        if stream_index >= len(stream_ids):
            logging.warning(f"{user['email']}에게 할당할 스트림이 부족합니다.")
            continue

        assigned_stream_id = stream_ids[stream_index]
        sub_payload = {"stream_id": assigned_stream_id}
        headers = {
            "Content-Type": "application/json",
            "Authorization": f'Bearer {token}'
        }

        try:
            sub_res = requests.post(SUBSCRIBE_URL, json=sub_payload,
                                    headers=headers, timeout=5)
        except requests.RequestException as e:
            logging.error(f"{user['email']} 구독 요청 중 오류: {e}")
            continue

        if sub_res.status_code != 200:
            logging.error(
                f"{user['email']} 스트림 {assigned_stream_id} 구독 실패, 상태코드: {sub_res.status_code}")
        else:
            logging.info(f"{user['email']} 스트림 {assigned_stream_id} 구독 성공")


def save_results(stream_ids: List[str],
                 filename: str = 'streams_and_tokens.json'):
    """ 결과(스트림 IDs)를 파일에 저장 """
    result_data = {
        "streamIds": stream_ids
    }
    with open(filename, 'w') as f:
        json.dump(result_data, f, indent=2)
    logging.info(f"결과가 {filename}에 저장되었습니다.")


def main():
    # 1. 모든 유저 로그인 및 토큰 획득
    token_map = login_all_users(USERS)

    # 방 생성용 유저를 첫 번째 유저로 가정
    creator_email = USERS[0]["email"]
    creator_token = token_map.get(creator_email)

    # 첫 번째 유저에게 토큰이 없는 경우 다른 유저 아무나 사용
    if not creator_token:
        any_user_with_token = next(iter(token_map.keys()), None)
        if not any_user_with_token:
            logging.error("스트림 생성할 토큰이 없습니다.")
            sys.exit(1)
        creator_email = any_user_with_token
        creator_token = token_map[creator_email]

    # 2. 30개 방 생성
    stream_ids = create_streams(creator_token, STREAM_COUNT)
    if not stream_ids:
        logging.error("스트림을 단 하나도 생성하지 못했습니다.")
        sys.exit(1)

    # 3. 유저 스트림 구독
    subscribe_users_to_streams(USERS, token_map, stream_ids, creator_email)

    # 4. 결과 저장
    save_results(stream_ids)

    logging.info("사전 준비 단계 완료.")


if __name__ == "__main__":
    main()

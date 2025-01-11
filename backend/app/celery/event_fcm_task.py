from pyfcm import FCMNotification
from app.celery.worker import app

fcm = FCMNotification(
    service_account_file="hoseo-meet-firebase.json",
    project_id="hoseo-meet-7918f"
)

@app.task
def send_multicast_task(token_ids, title, body, data_dict):
    # APNs(iOS)용 설정 예시
    apns_config = {
        "payload": {
            "aps": {
                "alert": {
                    "title": title,
                    "body": body
                },
                "sound": "default"
            }
        }
    }

    # 여러 토큰에 대한 params_list 구성
    params_list = []
    for token_id in token_ids:
        params_list.append({
            "fcm_token": token_id,
            "notification_title": title,
            "notification_body": body,
            "data_payload": data_dict,
            "apns_config": apns_config,  # 추가
        })

    fcm.async_notify_multiple_devices(params_list=params_list)

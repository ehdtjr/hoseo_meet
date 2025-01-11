from pyfcm import FCMNotification

from app.celery.worker import app

fcm = FCMNotification(service_account_file="hoseo-meet-firebase.json",
                      project_id="hoseo-meet-7918f")


@app.task
def send_multicast_task(token_ids, title, body, data_dict):
    fcm.async_notify_multiple_devices(
        params_list=[
            {
                "fcm_token": token_id,
                "notification_title": title,
                "notification_body": body,
                "data_payload": data_dict,
            }
            for token_id in token_ids
        ]
    )
"""Bound blocking provider calls to a process that can be stopped and reaped."""
import asyncio
import json
import os
import sys
from contextlib import suppress

from pyfcm import FCMNotification

from app.schemas.message import MessageResponse


class FCMDeliveryError(Exception):
    pass


async def _finish_cleanup(task):
    while not task.done():
        try:
            await asyncio.shield(task)
        except asyncio.CancelledError:
            continue
    return task.result()


def send_fcm(token: str, payload: str) -> None:
    message = MessageResponse.model_validate_json(payload)
    fcm = FCMNotification(service_account_file="hoseo-meet-firebase.json",
                          project_id="hoseo-meet-7918f")
    result = fcm.notify(
        fcm_token=token, notification_title="새로운 메시지",
        notification_body=message.content,
        data_payload={"type": "stream", "data": payload,
                      "message_id": str(message.id)},
        apns_config={"payload": {"aps": {"sound": "default"}}},
        timeout=15,
    )
    if not isinstance(result, dict) or not result.get("name"):
        raise FCMDeliveryError("FCM did not acknowledge delivery")


async def send_fcm_isolated(tokens: list[str], payload: str, *, timeout=25, command=None):
    command = command or (
        sys.executable, "-m", "app.scripts.deliver_message_fcm", str(os.getpid()))
    launch = asyncio.create_task(asyncio.create_subprocess_exec(
        *command, stdin=asyncio.subprocess.PIPE,
        # Never forward SDK output: it can contain credentials or message data.
        stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL))
    try:
        process = await asyncio.shield(launch)
    except asyncio.CancelledError:
        # Cancellation can arrive after the OS spawned a child but before the
        # asyncio process handle is returned. Keep ownership of that child too.
        process = await _finish_cleanup(launch)
        if process.returncode is None:
            with suppress(ProcessLookupError):
                process.kill()
        await _finish_cleanup(asyncio.create_task(process.communicate()))
        raise
    communication = asyncio.create_task(process.communicate(
        json.dumps({"tokens": tokens, "payload": payload}).encode()))
    try:
        await asyncio.wait_for(asyncio.shield(communication), timeout=timeout)
        if process.returncode != 0:
            raise FCMDeliveryError("FCM process failed")
    finally:
        # Do not release the outbox row lock until the process (including its
        # provider threads) is gone, even when the caller is cancelled twice.
        if process.returncode is None:
            with suppress(ProcessLookupError):
                process.kill()
        await _finish_cleanup(communication)

"""Private subprocess entrypoint; message/token data travels over stdin only."""
import ctypes
import json
import os
import signal
import sys
from concurrent.futures import ThreadPoolExecutor


def guard_parent(parent_pid: int):
    if sys.platform.startswith("linux"):
        # API workers run in Linux containers. Do not leave an active sender
        # behind after a worker crash releases its PostgreSQL lock.
        if ctypes.CDLL(None, use_errno=True).prctl(1, signal.SIGKILL, 0, 0, 0) != 0:
            raise OSError("Cannot bind FCM process lifetime to its parent")
    if os.getppid() != parent_pid:
        raise RuntimeError("FCM parent exited")


def main():
    guard_parent(int(sys.argv[1]))
    from app.service.message_fcm import send_fcm

    request = json.load(sys.stdin)
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = [executor.submit(send_fcm, token, request["payload"])
                   for token in request["tokens"]]
        for future in futures:
            future.result()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # The parent records a fixed FCMDeliveryError, never raw SDK exceptions.
        sys.exit(1)

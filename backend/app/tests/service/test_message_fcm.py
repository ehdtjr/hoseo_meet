import asyncio
import json
import sys
from unittest import IsolatedAsyncioTestCase
from unittest.mock import patch

from app.service.message_fcm import FCMDeliveryError, send_fcm, send_fcm_isolated


class TestMessageFCM(IsolatedAsyncioTestCase):
    async def test_cancellation_during_launch_keeps_ownership_of_child(self):
        processes = []
        created, release = asyncio.Event(), asyncio.Event()
        original = asyncio.create_subprocess_exec

        async def delayed_launch(*args, **kwargs):
            process = await original(*args, **kwargs)
            processes.append(process)
            created.set()
            await release.wait()
            return process

        with patch("app.service.message_fcm.asyncio.create_subprocess_exec", side_effect=delayed_launch):
            task = asyncio.create_task(send_fcm_isolated(
                ["synthetic"], "private body", command=[sys.executable, "-c",
                "import sys,time; sys.stdin.read(); time.sleep(60)"]))
            await asyncio.wait_for(created.wait(), timeout=5)
            task.cancel()
            await asyncio.sleep(0)
            self.assertFalse(task.done())
            task.cancel()  # repeated cancellation must not abandon cleanup
            release.set()
            with self.assertRaises(asyncio.CancelledError):
                await task
        self.assertIsNotNone(processes[0].returncode)

    async def test_cancel_reaps_process_before_returning(self):
        processes = []
        created = asyncio.Event()
        original = asyncio.create_subprocess_exec

        async def capture(*args, **kwargs):
            process = await original(*args, **kwargs)
            processes.append(process)
            created.set()
            return process

        with patch("app.service.message_fcm.asyncio.create_subprocess_exec", side_effect=capture):
            task = asyncio.create_task(send_fcm_isolated(
                ["synthetic"], "private body", command=[sys.executable, "-c",
                "import sys,time; sys.stdin.read(); time.sleep(60)"]))
            await asyncio.wait_for(created.wait(), timeout=5)
            task.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await task
        self.assertIsNotNone(processes[0].returncode)

    async def test_child_failure_does_not_expose_output(self):
        with self.assertRaises(FCMDeliveryError) as caught:
            await send_fcm_isolated(["synthetic"], "private body", command=[
                sys.executable, "-c",
                "import sys; sys.stdin.read(); print('PRIVATE_TOKEN', file=sys.stderr); sys.exit(1)"])
        self.assertNotIn("PRIVATE_TOKEN", str(caught.exception))

    async def test_payload_and_tokens_are_sent_over_stdin(self):
        await send_fcm_isolated(["token-one", "token-two"], "private body", command=[
            sys.executable, "-c",
            "import json,sys; r=json.load(sys.stdin); "
            "assert r == {'tokens':['token-one','token-two'], 'payload':'private body'}"])

    def test_provider_acknowledgement_and_message_id(self):
        payload = json.dumps(dict(id=42, sender_id=1, recipient_id=7,
                                  stream_id=7, content="synthetic", type=1,
                                  date_sent="2026-11-06T00:00:00Z", unread_count=2))
        with patch("app.service.message_fcm.FCMNotification") as factory:
            provider = factory.return_value
            provider.notify.return_value = {}
            with self.assertRaises(FCMDeliveryError):
                send_fcm("synthetic-token", payload)
            provider.notify.return_value = {"name": "projects/test/messages/42"}
            send_fcm("synthetic-token", payload)
            self.assertEqual(provider.notify.call_args.kwargs["data_payload"]["message_id"], "42")

"""GC regression tests against the dedicated Redis used by the backend suite."""
import os
import time
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest.mock import Mock, patch
from uuid import uuid4

import pytest
import redis

from app.celery.tasks import garbage_collection


@pytest.fixture
def gc_redis():
    client = redis.Redis.from_url(
        os.environ.get("TEST_REDIS_URL", "redis://localhost:6380"),
        decode_responses=True,
        socket_timeout=5,
        socket_connect_timeout=5,
    )
    client.ping()  # A missing test server must fail, not silently skip coverage.
    prefix = f"queue:gc-test:{uuid4().hex}:"
    try:
        yield client, prefix
    finally:
        keys = list(client.scan_iter(match=f"{prefix}*"))
        if keys:
            client.delete(*keys)
        client.close()


@pytest.mark.parametrize("timeout_secs", [0, 60, 120])
def test_idle_policy_and_exact_retention_boundary(gc_redis, timeout_secs):
    client, prefix = gc_redis
    now_ms = int(time.time()) * 1000
    cutoff_ms = now_ms - timeout_secs * 1000
    expired, boundary, recent, active = [
        f"{prefix}{name}" for name in ("expired", "boundary", "recent", "active")
    ]
    client.xadd(expired, {"data": "old"}, id=f"{cutoff_ms - 1}-0")
    client.xadd(boundary, {"data": "boundary"}, id=f"{cutoff_ms}-0")
    client.xadd(recent, {"data": "recent"}, id=f"{cutoff_ms + 1}-0")
    client.xadd(active, {"data": "old"}, id=f"{cutoff_ms - 1}-0")
    client.xadd(active, {"data": "new"}, id=f"{now_ms}-0")

    with patch("app.celery.tasks.time.time", return_value=now_ms / 1000):
        garbage_collection(client, timeout_secs=timeout_secs)
        garbage_collection(client, timeout_secs=timeout_secs)

    assert not client.exists(expired)
    assert client.xlen(boundary) == 1
    assert client.xlen(recent) == 1
    assert client.xlen(active) == 2  # Retention is per idle queue, not per entry.


def test_empty_streams_use_the_last_generated_id(gc_redis):
    client, prefix = gc_redis
    now_ms = int(time.time()) * 1000
    never_used, old_empty, recent_empty = [
        f"{prefix}{name}" for name in ("never-used", "old-empty", "recent-empty")
    ]
    client.xgroup_create(never_used, "test-group", mkstream=True)
    old_id = client.xadd(old_empty, {"data": "old"}, id=f"{now_ms - 60_001}-0")
    recent_id = client.xadd(recent_empty, {"data": "new"}, id=f"{now_ms}-0")
    client.xdel(old_empty, old_id)
    client.xdel(recent_empty, recent_id)

    with patch("app.celery.tasks.time.time", return_value=now_ms / 1000):
        garbage_collection(client)

    assert not client.exists(never_used, old_empty)
    assert client.exists(recent_empty)
    assert client.xlen(recent_empty) == 0


def test_missing_and_non_stream_keys_do_not_abort_gc(gc_redis):
    client, prefix = gc_redis
    missing, string_key, expired = [
        f"{prefix}{name}" for name in ("missing", "string", "expired")
    ]
    client.set(string_key, "keep")
    client.xadd(expired, {"data": "old"}, id="1-0")
    # Keys can disappear or change type between SCAN and the atomic check.
    with patch.object(client, "scan_iter", return_value=iter([missing, string_key, expired])):
        garbage_collection(client)

    assert client.get(string_key) == "keep"
    assert not client.exists(expired)


def test_duplicate_scan_results_preserve_recreated_stream(gc_redis):
    client, prefix = gc_redis
    key = f"{prefix}duplicate"
    client.xadd(key, {"data": "old"}, id="1-0")

    def repeated_keys():
        yield key
        assert not client.exists(key)
        client.xadd(key, {"data": "new"})
        yield key

    with patch.object(client, "scan_iter", return_value=repeated_keys()):
        garbage_collection(client)
    garbage_collection(client)

    assert [data for _, data in client.xrange(key)] == [{"data": "new"}]


def test_event_published_at_the_old_check_delete_gap_survives(gc_redis):
    client, prefix = gc_redis
    key = f"{prefix}race"
    client.xadd(key, {"data": "old"}, id="1-0")
    original_xinfo = client.xinfo_stream
    original_evalsha = client.evalsha
    published_ids = []

    def publish_once():
        if not published_ids:
            published_ids.append(client.xadd(key, {"data": "new"}))

    def read_then_publish(*args, **kwargs):
        info = original_xinfo(*args, **kwargs)
        publish_once()  # Reproduces the legacy XINFO -> XADD -> DELETE race.
        return info

    def publish_then_check(*args, **kwargs):
        publish_once()  # The replacement checks the new event inside the script.
        return original_evalsha(*args, **kwargs)

    with (
        patch.object(client, "xinfo_stream", side_effect=read_then_publish),
        patch.object(client, "evalsha", side_effect=publish_then_check),
    ):
        garbage_collection(client)

    assert len(published_ids) == 1
    assert client.xrange(key, min=published_ids[0]) == [
        (published_ids[0], {"data": "new"})
    ]


def test_concurrent_collectors_and_publisher_preserve_all_new_events(gc_redis):
    client, prefix = gc_redis
    keys = [f"{prefix}{index}" for index in range(100)]
    with client.pipeline() as pipe:
        for key in keys:
            pipe.xadd(key, {"data": "old"}, id="1-0")
        pipe.execute()
    start = Barrier(3)

    def collect():
        start.wait(timeout=10)
        for _ in range(5):
            garbage_collection(client)

    def publish():
        start.wait(timeout=10)
        published = []
        # The thread-safe pool uses separate connections for concurrent commands.
        for index in range(3):
            for key in keys:
                data = {"data": f"new-{index}"}
                published.append((key, client.xadd(key, data), data))
        return published

    with ThreadPoolExecutor(max_workers=3) as executor:
        collectors = [executor.submit(collect) for _ in range(2)]
        publisher = executor.submit(publish)
        published = publisher.result(timeout=30)
        for collector in collectors:
            collector.result(timeout=30)

    for key, event_id, data in published:
        assert client.xrange(key, min=event_id, max=event_id) == [(event_id, data)]


def test_gc_uses_incremental_scan():
    client = Mock()
    client.scan_iter.return_value = iter([])
    garbage_collection(client)
    client.scan_iter.assert_called_once_with(match="queue:*", count=100)
    client.keys.assert_not_called()


def test_negative_retention_is_rejected():
    with pytest.raises(ValueError, match="timeout_secs"):
        garbage_collection(None, timeout_secs=-1)

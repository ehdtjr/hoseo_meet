import asyncio
import threading
from contextlib import ExitStack
from unittest import TestCase
from unittest.mock import Mock, patch

import requests
from sqlalchemy import create_engine, event, func, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.orm import sessionmaker

from app.celery import tag_task as task
from app.crud.chat_bot import ChatBotMessageCRUD
from app.models import ChatBotMessage, Tag, User, UserTag, UserTaggingCheckpoint
from app.schemas.chat_bot import ChatBotMessageBase
from app.tests.conftest import BaseTest, SQLALCHEMY_TEST_DATABASE_URL, TestSessionLocal


class TestTagging(BaseTest):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        url = make_url(SQLALCHEMY_TEST_DATABASE_URL).set(drivername="postgresql+psycopg2")
        self.engine = create_engine(url)
        self.sessions = sessionmaker(self.engine, expire_on_commit=False)
        self.addCleanup(self.engine.dispose)
        # An unexpected real provider call is always a test failure.
        self.guards = ExitStack()
        self.addCleanup(self.guards.close)
        for name in ("requests.post", "requests.get", "openai.chat.completions.create"):
            self.guards.enter_context(patch(
                f"app.celery.tag_task.{name}",
                side_effect=AssertionError("Real AI calls are forbidden"),
            ))
        self.users = [self.new_user(i) for i in range(2)]

    def new_user(self, index):
        with self.sessions() as db:
            user = User(
                email=f"tagging-{index}@example.com", name=f"Tagging {index}",
                gender="other", hashed_password="synthetic",
                is_active=True, is_verified=True, is_superuser=False,
            )
            db.add(user)
            db.commit()
            return user.id

    def conversation(self, user, answers=("answer one", "answer two"), closed=True):
        with self.sessions() as db:
            ids = []
            for i, answer in enumerate(answers):
                db.add(ChatBotMessage(user_id=user, role="assistant", content=f"question {i}?"))
                row = ChatBotMessage(user_id=user, role="user", content=answer)
                db.add(row)
                db.flush()
                ids.append(row.id)
            if closed:
                db.add(ChatBotMessage(user_id=user, role="assistant", content=task.CONVERSATION_END))
            db.commit()
            return ids

    def process(self, user):
        with self.sessions() as db:
            task.process_user_for_tagging(db, user)

    def progress(self, user):
        with self.sessions() as db:
            row = db.get(UserTaggingCheckpoint, user)
            db.expunge(row)
            return row

    def candidates(self):
        with self.sessions() as db:
            return task.check_not_tag_user(db)

    def tags(self, user):
        with self.sessions() as db:
            return list(db.execute(
                select(Tag.name).join(UserTag).where(UserTag.user_id == user)
            ).scalars())

    async def test_partial_provider_failure_resumes_only_unprocessed_qa(self):
        user = self.users[0]
        answer_ids = self.conversation(user)
        with patch.object(task, "analyze_qa_and_extract_keyword", side_effect=[
            {"keyword": "커피"}, RuntimeError("private provider detail"),
        ]):
            with self.assertRaises(RuntimeError):
                self.process(user)
        checkpoint = self.progress(user)
        self.assertEqual(checkpoint.last_message_id, answer_ids[0])
        self.assertEqual(checkpoint.status, "failed")
        self.assertEqual(checkpoint.last_error, "RuntimeError")
        self.assertEqual(self.tags(user), ["커피"])
        self.assertEqual(self.candidates(), [user])
        with patch.object(task, "analyze_qa_and_extract_keyword", return_value={"keyword": "음악"}) as analyze:
            self.process(user)
            analyze.assert_called_once_with("question 1?", "answer two")
            self.process(user)
            self.assertEqual(analyze.call_count, 1)
        self.assertCountEqual(self.tags(user), ["커피", "음악"])
        self.assertEqual(self.progress(user).status, "completed")
        self.assertEqual(self.candidates(), [])

    async def test_no_tag_result_has_a_checkpoint_and_is_not_reanalyzed(self):
        user = self.users[0]
        ids = self.conversation(user)
        with patch.object(task, "analyze_qa_and_extract_keyword", side_effect=[None, RuntimeError()]):
            with self.assertRaises(RuntimeError):
                self.process(user)
        self.assertEqual(self.progress(user).last_message_id, ids[0])
        with patch.object(task, "analyze_qa_and_extract_keyword", return_value=None) as analyze:
            self.process(user)
            self.process(user)
            analyze.assert_called_once_with("question 1?", "answer two")
        self.assertEqual(self.tags(user), [])
        self.assertEqual(self.candidates(), [])

    async def test_worker_interruption_resumes_from_running_checkpoint(self):
        user = self.users[0]
        ids = self.conversation(user)
        with patch.object(task, "analyze_qa_and_extract_keyword", side_effect=[
            {"keyword": "커피"}, SystemExit("synthetic worker interruption"),
        ]):
            with self.assertRaises(SystemExit):
                self.process(user)
        # A worker interruption bypasses ordinary error handling entirely.
        self.assertEqual(self.progress(user).status, "running")
        self.assertEqual(self.progress(user).last_message_id, ids[0])
        self.assertEqual(self.candidates(), [user])
        with patch.object(task, "analyze_qa_and_extract_keyword", return_value={"keyword": "커피"}) as analyze:
            self.process(user)
            analyze.assert_called_once_with("question 1?", "answer two")
        self.assertEqual(self.tags(user), ["커피"])
        self.assertEqual(self.progress(user).status, "completed")

    async def test_db_failure_rolls_back_tag_and_cursor_and_next_user_runs(self):
        first, second = self.users
        self.conversation(first, answers=("first",))
        self.conversation(second, answers=("second",))
        original = task.save_user_tag

        def fail_after_tag_flush(db, user, keyword, score):
            original(db, user, keyword, score)
            if user == first:
                # A genuine PostgreSQL exception leaves the transaction aborted.
                db.execute(text("SELECT definitely_missing_tagging_function()"))

        used_sessions = []
        original_process = task.process_user_for_tagging

        def process(db, user):
            used_sessions.append(db)
            return original_process(db, user)

        with (
            patch.object(task.settings, "AI_ENABLED", True),
            patch.object(task, "sync_session_maker", self.sessions),
            patch.object(task, "process_user_for_tagging", side_effect=process),
            patch.object(task, "analyze_qa_and_extract_keyword", return_value={"keyword": "커피"}),
            patch.object(task, "save_user_tag", side_effect=fail_after_tag_flush),
        ):
            task.process_user_tag.run()
        self.assertIsNot(used_sessions[0], used_sessions[1])
        self.assertEqual(self.tags(first), [])
        self.assertEqual(self.progress(first).last_message_id, 0)
        self.assertEqual(self.progress(first).status, "failed")
        self.assertEqual(self.tags(second), ["커피"])
        self.assertEqual(self.progress(second).status, "completed")
        with patch.object(task, "analyze_qa_and_extract_keyword", return_value={"keyword": "커피"}):
            self.process(first)
        self.assertEqual(self.tags(first), ["커피"])

    async def test_repeated_keywords_and_legacy_tags_are_idempotent(self):
        user = self.users[0]
        self.conversation(user)
        with self.sessions() as db:
            tag = Tag(name="커피")
            db.add(tag)
            db.flush()
            db.add(UserTag(user_id=user, tag_id=tag.id, score=0.75))
            db.commit()
        self.assertEqual(self.candidates(), [user])
        with patch.object(task, "analyze_qa_and_extract_keyword", return_value={"keyword": "커피"}):
            self.process(user)
            self.process(user)
        self.assertEqual(self.tags(user), ["커피"])
        with self.sessions() as db:
            self.assertEqual(db.scalar(select(UserTag.score)), 0.75)

    async def test_version_change_reanalyzes_and_keeps_existing_tags(self):
        user = self.users[0]
        self.conversation(user, answers=("first",))
        with patch.object(task, "analyze_qa_and_extract_keyword", return_value={"keyword": "커피"}):
            self.process(user)
        with (
            patch.object(task, "ANALYSIS_VERSION", "qa-keyword-v2"),
            patch.object(task, "analyze_qa_and_extract_keyword", return_value={"keyword": "음악"}) as analyze,
        ):
            self.assertEqual(self.candidates(), [user])
            self.process(user)
            self.assertEqual(analyze.call_count, 1)
            self.assertEqual(self.candidates(), [])
        self.assertEqual(self.progress(user).analysis_version, "qa-keyword-v2")
        self.assertCountEqual(self.tags(user), ["커피", "음악"])

    async def test_new_conversation_only_analyzes_new_pairs_after_closure(self):
        user = self.users[0]
        self.conversation(user, answers=("first",))
        with patch.object(task, "analyze_qa_and_extract_keyword", return_value=None):
            self.process(user)
        self.conversation(user, answers=("new answer",), closed=False)
        self.assertEqual(self.candidates(), [])
        with self.sessions() as db:
            db.add(ChatBotMessage(user_id=user, role="assistant", content=task.CONVERSATION_END))
            db.commit()
        self.assertEqual(self.candidates(), [user])
        with patch.object(task, "analyze_qa_and_extract_keyword", return_value=None) as analyze:
            self.process(user)
            analyze.assert_called_once_with("question 0?", "new answer")

    async def test_empty_closed_conversation_completes_without_ai(self):
        user = self.users[0]
        self.conversation(user, answers=())
        with patch.object(task, "analyze_qa_and_extract_keyword") as analyze:
            self.process(user)
            analyze.assert_not_called()
        self.assertEqual(self.progress(user).status, "completed")

    async def test_lost_commit_ack_does_not_duplicate_or_reanalyze_saved_qa(self):
        user = self.users[0]
        self.conversation(user, answers=("first",))
        with self.sessions() as db:
            original_commit = db.commit
            commits = 0

            def commit_then_fail():
                nonlocal commits
                original_commit()
                commits += 1
                if commits == 2:
                    raise RuntimeError("lost acknowledgement")

            with (
                patch.object(db, "commit", side_effect=commit_then_fail),
                patch.object(task, "analyze_qa_and_extract_keyword", return_value={"keyword": "커피"}) as analyze,
            ):
                with self.assertRaises(RuntimeError):
                    task.process_user_for_tagging(db, user)
                self.process(user)
                self.assertEqual(analyze.call_count, 1)
        self.assertEqual(self.tags(user), ["커피"])
        self.assertEqual(self.progress(user).status, "completed")

    async def test_concurrent_workers_skip_busy_user_and_do_not_duplicate_tags(self):
        user = self.users[0]
        self.conversation(user)
        entered, release = threading.Event(), threading.Event()

        def analyze(*args):
            entered.set()
            if not release.wait(10):
                raise AssertionError("Worker was not released")
            return {"keyword": "커피"}

        with patch.object(task, "analyze_qa_and_extract_keyword", side_effect=analyze) as mock:
            worker = asyncio.create_task(asyncio.to_thread(self.process, user))
            try:
                self.assertTrue(await asyncio.to_thread(entered.wait, 5))
                await asyncio.wait_for(asyncio.to_thread(self.process, user), 5)
            finally:
                release.set()
                await worker
            self.assertEqual(mock.call_count, 2)  # exactly two distinct QAs
        self.assertEqual(self.tags(user), ["커피"])
        self.assertEqual(self.progress(user).status, "completed")

    async def test_different_users_share_one_new_keyword_under_concurrency(self):
        for user in self.users:
            self.conversation(user, answers=("first",))
        barrier = threading.Barrier(2)

        def analyze(*args):
            barrier.wait(timeout=5)
            return {"keyword": "커피"}

        with patch.object(task, "analyze_qa_and_extract_keyword", side_effect=analyze):
            await asyncio.gather(*(asyncio.to_thread(self.process, user) for user in self.users))
        with self.sessions() as db:
            self.assertEqual(db.scalar(select(func.count()).select_from(Tag)), 1)
        for user in self.users:
            self.assertEqual(self.tags(user), ["커피"])

    async def test_first_checkpoint_initializers_skip_before_conflicting_insert(self):
        user = self.users[0]
        self.conversation(user, answers=("answer",))
        initial_read, resume_initializer, release_analysis = [
            threading.Event() for _ in range(3)
        ]
        first_thread = [None]

        def pause_initial_read(conn, cursor, statement, parameters, context, many):
            if (threading.get_ident() == first_thread[0]
                    and statement.startswith("SELECT user_tagging_checkpoint.user_id")
                    and cursor.rowcount == 0):
                initial_read.set()
                if not resume_initializer.wait(10):
                    raise AssertionError("Initializer was not released")

        def first_worker():
            first_thread[0] = threading.get_ident()
            self.process(user)

        def analyze(*args):
            if not release_analysis.wait(10):
                raise AssertionError("Analysis was not released")
            return {"keyword": "커피"}

        event.listen(self.engine, "after_cursor_execute", pause_initial_read)
        try:
            with patch.object(task, "analyze_qa_and_extract_keyword", side_effect=analyze) as mock:
                first = asyncio.create_task(asyncio.to_thread(first_worker))
                second = None
                try:
                    self.assertTrue(await asyncio.to_thread(initial_read.wait, 5))
                    second = asyncio.create_task(asyncio.to_thread(self.process, user))
                    # The first initializer has not inserted anything yet.
                    # Another worker must skip, rather than race its INSERT.
                    await asyncio.wait_for(asyncio.shield(second), 2)
                    mock.assert_not_called()
                finally:
                    resume_initializer.set()
                    release_analysis.set()
                    await first
                    if second is not None:
                        await second
                self.assertEqual(mock.call_count, 1)
        finally:
            event.remove(self.engine, "after_cursor_execute", pause_initial_read)
        self.assertEqual(self.tags(user), ["커피"])

    async def test_message_writer_cannot_commit_closure_before_earlier_answer(self):
        user = self.users[0]
        self.conversation(user, answers=(), closed=False)
        crud = ChatBotMessageCRUD()
        await crud.create(self.db, ChatBotMessageBase(
            user_id=user, role="assistant", content="late question?"
        ))
        flushed, release, closing_started = [asyncio.Event() for _ in range(3)]
        closing_pid = []

        async def delayed_answer():
            async with TestSessionLocal() as db:
                commit = db.commit

                async def delay_commit():
                    # Allocate the answer's ID, then hold the transaction open.
                    await db.flush()
                    flushed.set()
                    await release.wait()
                    await commit()

                with patch.object(db, "commit", side_effect=delay_commit):
                    await crud.create(db, ChatBotMessageBase(
                        user_id=user, role="user", content="late answer"
                    ))

        async def closing_message():
            async with TestSessionLocal() as db:
                closing_pid.append(await db.scalar(text("SELECT pg_backend_pid()")))
                closing_started.set()
                await crud.create(db, ChatBotMessageBase(
                    user_id=user, role="assistant", content=task.CONVERSATION_END
                ))

        def closing_is_waiting():
            with self.engine.connect() as connection:
                return connection.scalar(text(
                    "SELECT EXISTS (SELECT 1 FROM pg_stat_activity "
                    "WHERE pid = :pid AND wait_event_type = 'Lock' "
                    "AND wait_event = 'advisory')"
                ), {"pid": closing_pid[0]})

        first = asyncio.create_task(delayed_answer())
        second = None
        try:
            await asyncio.wait_for(flushed.wait(), 5)
            second = asyncio.create_task(closing_message())
            await asyncio.wait_for(closing_started.wait(), 5)
            for _ in range(100):
                if second.done() or await asyncio.to_thread(closing_is_waiting):
                    break
                await asyncio.sleep(0.025)
            self.assertFalse(second.done(), "Closure committed before the earlier answer")
            self.assertTrue(await asyncio.to_thread(closing_is_waiting))
            # The task must see the previous question, never a closing marker
            # ahead of this uncommitted answer, so it cannot skip that answer.
            with patch.object(task, "analyze_qa_and_extract_keyword") as analyze:
                await asyncio.to_thread(self.process, user)
                analyze.assert_not_called()
            self.assertNotEqual(self.progress(user).status, "completed")
        finally:
            release.set()
            await first
            if second is not None:
                await second
        self.assertEqual(self.candidates(), [user])
        with patch.object(task, "analyze_qa_and_extract_keyword", return_value={"keyword": "커피"}) as analyze:
            await asyncio.to_thread(self.process, user)
            analyze.assert_called_once_with("late question?", "late answer")
        self.assertEqual(self.tags(user), ["커피"])
        self.assertEqual(self.progress(user).status, "completed")

    async def test_message_write_lock_does_not_block_a_different_user(self):
        crud = ChatBotMessageCRUD()
        async with TestSessionLocal() as first:
            commit = first.commit

            async def flush_only():
                await first.flush()

            with patch.object(first, "commit", side_effect=flush_only):
                await crud.create(first, ChatBotMessageBase(
                    user_id=self.users[0], role="user", content="uncommitted"
                ))
            async with TestSessionLocal() as second:
                await asyncio.wait_for(crud.create(second, ChatBotMessageBase(
                    user_id=self.users[1], role="user", content="other user"
                )), 3)
            await commit()

    async def test_qa_query_preserves_immediate_message_adjacency(self):
        user = self.users[0]
        with self.sessions() as db:
            db.add_all([
                ChatBotMessage(user_id=user, role=role, content=content)
                for role, content in [
                    ("user", "greeting"), ("assistant", "unanswered?"),
                    ("assistant", "actual question?"), ("user", "actual answer"),
                    ("user", "extra answer"), ("assistant", "second question?"),
                    ("user", "second answer"), ("assistant", task.CONVERSATION_END),
                ]
            ])
            db.commit()
        with patch.object(task, "analyze_qa_and_extract_keyword", return_value=None) as analyze:
            self.process(user)
        self.assertEqual([call.args for call in analyze.call_args_list], [
            ("actual question?", "actual answer"),
            ("second question?", "second answer"),
        ])

    async def test_long_conversation_transfers_linear_number_of_message_rows(self):
        user = self.users[0]
        self.conversation(user, answers=tuple(f"answer {i}" for i in range(100)))
        returned_rows = []

        def count_rows(conn, cursor, statement, parameters, context, many):
            if statement.startswith("SELECT") and "FROM chat_bot_message" in statement:
                returned_rows.append(cursor.rowcount)

        event.listen(self.engine, "after_cursor_execute", count_rows)
        try:
            with patch.object(task, "analyze_qa_and_extract_keyword", return_value=None) as analyze:
                self.process(user)
                self.assertEqual(analyze.call_count, 100)
        finally:
            event.remove(self.engine, "after_cursor_execute", count_rows)
        self.assertLessEqual(sum(returned_rows), 300)
        self.assertEqual(self.progress(user).status, "completed")

    async def test_disabled_task_opens_no_session_and_makes_no_ai_call(self):
        with (
            patch.object(task.settings, "AI_ENABLED", False),
            patch.object(task, "sync_session_maker") as sessions,
            patch.object(task, "analyze_qa_and_extract_keyword") as analyze,
        ):
            task.process_user_tag.run()
        sessions.assert_not_called()
        analyze.assert_not_called()


class TestTaggingProviders(TestCase):
    def test_sentiment_http_failure_is_retryable(self):
        with patch.object(task.requests, "post", side_effect=requests.Timeout):
            with self.assertRaises(requests.Timeout):
                task.analyze_sentiment("synthetic")

    def test_missing_request_id_is_retryable(self):
        with patch.object(task.requests, "post", return_value=Mock(json=lambda: {})):
            with self.assertRaises(task.TaggingAnalysisError):
                task.analyze_sentiment("synthetic")

    def test_failed_malformed_and_timed_out_sentiment_is_retryable(self):
        results = [
            {"status": "FAILED"}, {"status": "CANCELLED"},
            {"status": "COMPLETED", "output": {}},
            {"status": "COMPLETED", "output": {"sentiment": -1}},
            {"status": "COMPLETED", "output": {"sentiment": "1"}},
            {"status": "IN_PROGRESS"},
        ]
        for result in results:
            with (
                self.subTest(result=result),
                patch.object(task.requests, "post", return_value=Mock(json=lambda: {"id": "synthetic"})),
                patch.object(task.requests, "get", return_value=Mock(json=lambda: result)),
                patch.object(task.time, "sleep"),
            ):
                with self.assertRaises(task.TaggingAnalysisError):
                    task.analyze_sentiment("synthetic")

    def test_valid_neutral_or_differing_sentiment_is_a_no_tag_result(self):
        for sentiments in ([0, 1], [2, 2]):
            with (
                patch.object(task, "analyze_sentiment", side_effect=sentiments),
                patch.object(task, "keyword_with_sbert_then_gpt") as keyword,
            ):
                self.assertIsNone(task.analyze_qa_and_extract_keyword("q", "a"))
                keyword.assert_not_called()

    def test_legacy_negative_error_result_is_not_treated_as_no_tag(self):
        with patch.object(task, "analyze_sentiment", side_effect=[-1, 1]):
            with self.assertRaises(task.TaggingAnalysisError):
                task.analyze_qa_and_extract_keyword("q", "a")

    def test_invalid_keyword_is_retryable(self):
        for value in (None, "", "not a candidate"):
            response = Mock(choices=[Mock(message=Mock(content=value))])
            with patch.object(task.openai.chat.completions, "create", return_value=response):
                with self.assertRaises(task.TaggingAnalysisError):
                    task.keyword_with_sbert_then_gpt("synthetic")

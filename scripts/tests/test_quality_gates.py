import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from check_static_analysis import compare  # noqa: E402
from check_test_reports import check  # noqa: E402
from collections import Counter  # noqa: E402


class TestReports(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'report'

    def test_backend_success_missing_skipped_failed_error_empty_and_bad_report(self):
        required = ['suite.Class::failure_path']
        for child in ('', '<skipped/>', '<failure/>', '<error/>'):
            self.path.write_text('<testsuite><testcase classname="suite.Class" '
                                 f'name="failure_path">{child}</testcase></testsuite>')
            if not child:
                self.assertEqual(check('backend', self.path, required), 1)
                with self.assertRaises(ValueError):
                    check('backend', self.path, ['suite.Class::removed_test'])
            else:
                with self.assertRaises(ValueError):
                    check('backend', self.path, required)
        self.path.write_text('<testsuite/>')
        with self.assertRaises(ValueError):
            check('backend', self.path, required)

    def events(self, **done):
        return [
            {'type': 'suite', 'suite': {'id': 0, 'path': '/repo/test/failure_test.dart'}},
            {'type': 'testStart', 'test': {'id': 1, 'suiteID': 0, 'name': 'failure path'}},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'skipped': False, **done},
            {'type': 'done', 'success': True},
        ]

    def write(self, events):
        self.path.write_text('\n'.join(json.dumps(e) for e in events))

    def test_flutter_success_and_missing_required_test(self):
        self.write([[{'event': 'test.startedProcess', 'params': {}}], *self.events()])
        self.assertEqual(check('flutter', self.path, ['test/failure_test.dart::failure path']), 1)
        with self.assertRaises(ValueError):
            check('flutter', self.path, ['test/failure_test.dart::deleted test'])

    def test_flutter_skip_failure_error_empty_and_truncated_reports(self):
        events = self.events()
        for report in (self.events(skipped=True), self.events(result='failure'),
                       self.events(hidden=True), events[:-1], [], [events[-1]],
                       events + [{'type': 'error', 'error': 'load failure'}]):
            with self.subTest(report=report):
                self.write(report)
                with self.assertRaises(ValueError):
                    check('flutter', self.path, [])

    def test_static_baseline_rejects_new_rule_new_file_and_count_growth(self):
        baseline = {'old.py|F401': 2}
        self.assertFalse(compare(Counter({'old.py|F401': 1}), baseline))
        for current in ({'old.py|F401': 3}, {'new.py|F401': 1}, {'old.py|F821': 1}):
            self.assertTrue(compare(Counter(current), baseline))

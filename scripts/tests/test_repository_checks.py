"""Real temporary Git repositories prove tracked-file coverage and CLI failures."""
import csv
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
sys.path.insert(0, str(ROOT / 'backend'))
from app.scripts.rental_csv import FIELDS, read_rentals  # noqa: E402


class TestTrackedChecks(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)

    def track(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        subprocess.run(['git', 'add', '-f', '--', name], cwd=self.root, check=True)
        return path

    def run_check(self, script):
        return subprocess.run([sys.executable, str(ROOT / 'scripts' / script)],
                              cwd=self.root, capture_output=True, text=True)

    def test_conflicts_in_tracked_ignored_unicode_csv_and_diff3(self):
        self.track('.gitignore', b'*.csv\n')
        for index, marker in enumerate(('<' * 7 + ' HEAD', '=' * 7,
                                        '>' * 7 + ' branch', '|' * 7 + ' base')):
            with self.subTest(marker=index):
                self.track('자료 with spaces.csv', ('header\n' + marker + '\n').encode())
                result = self.run_check('check_conflicts.py')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('자료 with spaces.csv:2', result.stderr)

    def test_clean_text_binary_and_deleted_files(self):
        self.track('clean.md', b'# title\nordinary text\n')
        self.track('binary.bin', b'\0' + b'<' * 7 + b' HEAD\n')
        self.track('deleted.md', b'clean\n').unlink()
        self.assertEqual(self.run_check('check_conflicts.py').returncode, 0)
        self.assertEqual(self.run_check('check_secrets.py').returncode, 0)

    def test_every_synthetic_credential_format_is_rejected_without_echoing(self):
        markers = [
            b'-----BEGIN ' + b'PRIVATE KEY-----',
            b'-----BEGIN ' + b'RSA PRIVATE KEY-----',
            b'-----BEGIN ' + b'EC PRIVATE KEY-----',
            b'-----BEGIN ' + b'OPENSSH PRIVATE KEY-----',
            b'AKIA' + b'Z' * 16,
            b'{"type": "' + b'service_account"}',
            b'sk-proj-' + b'synthetic' * 5,
        ]
        for marker in markers:
            with self.subTest(marker_length=len(marker)):
                self.track('synthetic.txt', marker)
                result = self.run_check('check_secrets.py')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('synthetic.txt', result.stderr)
                self.assertNotIn(marker.decode(), result.stdout + result.stderr)

    def test_credential_filenames_are_rejected(self):
        for name in ('.env', 'nested/key.pem', 'nested/key.key'):
            self.track(name, b'synthetic placeholder')
        self.assertNotEqual(self.run_check('check_secrets.py').returncode, 0)


class TestRentalValidation(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'synthetic.csv'
        self.row = ['Synthetic room', 'Synthetic address', '', '', '', '', '',
                    'quoted, comment', 'back', '36.74', '127.07']

    def write(self, rows, header=FIELDS):
        with self.path.open('w', newline='') as output:
            csv.writer(output).writerows([header, *rows])

    def test_synthetic_columns_quoted_comment_and_coordinates(self):
        self.write([self.row])
        rows = read_rentals(self.path)
        self.assertEqual(rows[0]['comment'], 'quoted, comment')
        self.assertEqual(rows[0]['longitude'], '127.07')
        self.assertEqual(set(rows[0]), set(FIELDS))

    def test_tracked_seed_has_canonical_header_and_83_unique_rows(self):
        self.assertEqual(len(read_rentals(ROOT / 'backend/last_rental_data.csv')), 83)

    def test_malformed_header_missing_extra_columns_duplicate_and_empty(self):
        self.write([self.row], header=FIELDS[:-1])
        with self.assertRaises(ValueError):
            read_rentals(self.path)
        for rows in ([self.row[:-1]], [self.row + ['extra']],
                     [self.row, self.row], [], [list(FIELDS)]):
            with self.subTest(rows=rows):
                self.write(rows)
                with self.assertRaises(ValueError):
                    read_rentals(self.path)

    def test_bad_coordinates_and_empty_required_fields(self):
        for index, values in ((9, ('NaN', 'inf', '91', '-91', 'bad', '')),
                              (10, ('NaN', 'inf', '181', '-181', 'bad', '')),
                              (0, ('', ' ')), (1, ('', ' ')), (8, ('', ' '))):
            for value in values:
                row = self.row.copy()
                row[index] = value
                self.write([row])
                with self.subTest(index=index, value=value), self.assertRaises(ValueError):
                    read_rentals(self.path)

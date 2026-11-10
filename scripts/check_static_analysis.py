"""Reject analyzer errors and increases in per-file/rule diagnostic counts."""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def diagnostics(kind: str, executable: str) -> Counter:
    if kind == 'backend':
        run = subprocess.run(
            [executable, 'check', '--no-cache', 'backend', 'scripts', '--output-format=json'],
            cwd=ROOT, capture_output=True, text=True,
        )
        if run.returncode not in (0, 1):
            raise ValueError('Ruff failed to run: ' + run.stderr)
        issues = json.loads(run.stdout)
        counts = Counter()
        for issue in issues:
            if issue['code'] in ('E999', None):
                raise ValueError('Python syntax/analyzer error: ' + issue['filename'])
            name = Path(issue['filename']).relative_to(ROOT).as_posix()
            counts[f"{name}|{issue['code']}"] += 1
        return counts
    run = subprocess.run(
        [executable, 'analyze', '--format=machine'],
        cwd=ROOT / 'frontend/app', capture_output=True, text=True,
    )
    if run.returncode not in (0, 1, 2, 3):
        raise ValueError('Dart analyzer failed to run')
    counts = Counter()
    for line in (run.stdout + run.stderr).splitlines():
        fields = line.split('|', 7)
        if len(fields) != 8 or fields[0] not in ('ERROR', 'WARNING', 'INFO'):
            raise ValueError('Unexpected Dart analyzer output: ' + line)
        severity, _, code, filename, *_ = fields
        if severity == 'ERROR':
            raise ValueError(f'Dart analyzer error: {filename} {code}')
        name = Path(filename).relative_to(ROOT).as_posix()
        counts[f'{name}|{severity}|{code}'] += 1
    if run.returncode and not counts:
        raise ValueError('Dart analyzer failed without diagnostics')
    return counts


def compare(current: Counter, baseline: dict) -> Counter:
    return current - Counter(baseline)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=('backend', 'flutter'))
    parser.add_argument('--executable', required=True)
    parser.add_argument('--write-baseline', action='store_true')
    args = parser.parse_args()
    current = diagnostics(args.kind, args.executable)
    path = ROOT / f'scripts/baselines/{args.kind}.json'
    if args.write_baseline:
        path.parent.mkdir(exist_ok=True)
        path.write_text(json.dumps(dict(sorted(current.items())), indent=2) + '\n')
    else:
        excess = compare(current, json.loads(path.read_text()))
        if excess:
            raise SystemExit('New static diagnostics:\n' + json.dumps(excess, indent=2))
    print(f'{args.kind}: {sum(current.values())} baseline diagnostics; no new diagnostics or errors')

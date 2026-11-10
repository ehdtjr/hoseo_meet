"""Require successful, non-skipped execution of the failure-path contract."""
import argparse
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def backend_results(path: Path) -> set[str]:
    cases = list(ET.parse(path).getroot().iter('testcase'))
    if not cases:
        raise ValueError('Empty backend test report')
    passed = set()
    for case in cases:
        if any(case.find(tag) is not None for tag in ('skipped', 'failure', 'error')):
            raise ValueError('Backend report contains skipped/failed/error tests')
        passed.add(case.attrib['classname'] + '::' + case.attrib['name'])
    return passed


def flutter_results(path: Path) -> set[str]:
    suites, tests, completed, hidden = {}, {}, set(), set()
    done = False
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        event = json.loads(line)
        # Flutter also writes daemon process notifications to --machine stdout.
        if isinstance(event, list) and event and all(
            isinstance(item, dict) and item.get('event') == 'test.startedProcess'
            for item in event
        ):
            continue
        if not isinstance(event, dict):
            raise ValueError('Unexpected Flutter runner output')
        kind = event.get('type')
        if kind == 'suite':
            suite = event['suite']
            suites[suite['id']] = suite['path'].replace('\\', '/')
        elif kind == 'testStart':
            test = event['test']
            if test.get('metadata', {}).get('skip'):
                raise ValueError('Flutter report contains a skipped test')
            tests[test['id']] = test
        elif kind == 'testDone':
            if event.get('skipped') or event['result'] != 'success':
                raise ValueError('Flutter report contains skipped/failed/error tests')
            completed.add(event['testID'])
            if event.get('hidden'):
                hidden.add(event['testID'])
        elif kind == 'error':
            raise ValueError('Flutter runner reported an error')
        elif kind == 'done':
            done = event.get('success') is True
    if not done or not completed or set(tests) != completed:
        raise ValueError('Empty or incomplete Flutter test report')
    passed = set()
    for test_id in completed - hidden:
        test = tests[test_id]
        path = suites[test['suiteID']]
        # Loading events have hidden=true and are not actual test execution.
        relative = 'test/' + path.split('/test/', 1)[1]
        passed.add(relative + '::' + test['name'])
    if not passed:
        raise ValueError('Flutter report contains no visible test executions')
    return passed


def check(kind: str, path: Path, required: list[str]) -> int:
    passed = (flutter_results if kind == 'flutter' else backend_results)(path)
    missing = set(required) - passed
    if missing:
        raise ValueError('Required tests did not pass: ' + ', '.join(sorted(missing)))
    return len(passed)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=('backend', 'migrations', 'flutter'))
    parser.add_argument('report', type=Path)
    args = parser.parse_args()
    contract = json.loads((ROOT / 'scripts/required_tests.json').read_text())
    count = check(args.kind, args.report, contract[args.kind])
    print(f'{args.kind}: {count} tests passed; required failure paths executed; no skips')

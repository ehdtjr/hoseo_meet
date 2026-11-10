"""Check every tracked text file, including files matched by .gitignore."""
import re
from pathlib import Path

from check_secrets import tracked_files


MARKER = re.compile(rb'^\s*(?:<{7,}(?: .*)?|={7,}|>{7,}(?: .*)?|\|{7,}(?: .*)?)\s*$')


def check(root: Path) -> list[str]:
    errors = []
    for name in tracked_files(root):
        path = root / name
        if not path.is_file():
            continue
        data = path.read_bytes()
        if b'\0' in data:
            continue
        for number, line in enumerate(data.splitlines(), 1):
            if MARKER.fullmatch(line):
                errors.append(f'{name}:{number}')
    return errors


if __name__ == '__main__':
    errors = check(Path.cwd())
    if errors:
        raise SystemExit('Unresolved conflict markers: ' + ', '.join(errors))
    print('Tracked conflict marker checks passed')

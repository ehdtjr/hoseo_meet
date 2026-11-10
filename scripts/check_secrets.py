"""Reject credential files and known private key/token formats in tracked files."""
import os
import re
import subprocess
from pathlib import Path

PATTERNS = [rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', rb'AKIA[0-9A-Z]{16}', rb'"type"\s*:\s*"service_account"', rb'sk-proj-[A-Za-z0-9_-]{30,}']


def tracked_files(root: Path):
    paths = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root)
    for name in filter(None, paths.split(b'\0')):
        yield Path(os.fsdecode(name))


def check(root: Path) -> list[str]:
    errors = []
    for name in tracked_files(root):
        path = root / name
        if not path.is_file():
            continue  # A tracked file may have been deleted in the working tree.
        data = path.read_bytes()
        if (path.name == '.env' or path.suffix in {'.pem', '.key'}
                or any(re.search(pattern, data) for pattern in PATTERNS)):
            errors.append(str(name))
    return errors


if __name__ == '__main__':
    errors = check(Path.cwd())
    if errors:
        raise SystemExit('Potential tracked credentials: ' + ', '.join(sorted(errors)))
    print('Tracked credential checks passed')

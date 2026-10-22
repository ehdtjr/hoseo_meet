"""Reject credential files and known private key/token formats in tracked files."""
import re
import subprocess
from pathlib import Path

paths = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0')
patterns = [rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', rb'AKIA[0-9A-Z]{16}', rb'"type"\s*:\s*"service_account"', rb'sk-proj-[A-Za-z0-9_-]{30,}']
errors = []
for name in filter(None, paths):
    path = Path(name)
    if not path.is_file():
        continue
    if path.name == '.env' or (path.suffix in {'.pem', '.key'}):
        errors.append(name)
    data = path.read_bytes()
    if any(re.search(pattern, data) for pattern in patterns):
        errors.append(name)
if errors:
    raise SystemExit('Potential tracked credentials: ' + ', '.join(sorted(set(errors))))
print('Tracked credential checks passed')

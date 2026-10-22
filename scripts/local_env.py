"""Generate local-only credentials without printing or overwriting secrets."""
import os
from pathlib import Path
import secrets

root = Path(__file__).resolve().parents[1]
content = (root / ".env.example").read_text()
for name in ("SECRET_KEY", "POSTGRES_PASSWORD", "FIRST_SUPERUSER_PASSWORD"):
    content = content.replace(f"{name}=GENERATE_ME", f"{name}={secrets.token_urlsafe(32)}")
fd = os.open(root / ".env", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, "w") as file:
    file.write(content)
print("Created root .env (mode 0600). Existing files are never overwritten.")

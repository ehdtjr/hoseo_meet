# Profile media ownership

`POST /api/v1/users/me/profile` records the server-generated object key, authenticated
uploader, and storage backend in `profile_media`. This table is exclusively for
profile uploads. The URL in `user.profile` is display data: registration and ordinary
user updates cannot create or change upload records, even if they submit extra
fields such as `key`, `uploader_id`, or `storage_backend`.

Replacement locks the user row, commits the new URL and upload record together,
then cleans up the previous recorded key. Storage verifies the profile namespace
and uploader before deleting. Read signatures do not authorize profile deletion;
the legacy URL deletion API rejects the profile namespace. Failed database updates
roll back and attempt to remove only the newly uploaded file. If a commit acknowledgement
is lost, the file is retained because the database may have committed successfully.

Hard deletion of a user cascades to that user's upload record, so the registry does
not block the existing administrator deletion API. S3 URL deletion preserves the
literal key emitted by both upload methods, including percent sequences in filenames
and existing stored URLs.

## Existing database rollout

Before starting the API against an existing database, follow the tracked Alembic
procedure in [database-migrations.md](database-migrations.md), including a verified
backup and `alembic upgrade head`. Revision `20261106_0002` creates the profile
registry. For an unversioned installation, use strict legacy adoption first; do
not stamp a guessed revision. The older `init_profile_media` helper exists only
for compatibility with legacy installations and does not replace tracked upgrades.

Existing profile URLs are not backfilled into the registry: a URL, including one
whose path contains a user ID, is not proof of upload ownership. Those files remain
readable and are retained on replacement. No production media cleanup is included.
If the configured backend changes, an old file in the other backend is retained.
Cleanup failures are logged without private URLs and may leave an orphaned file;
the newly committed profile remains usable.

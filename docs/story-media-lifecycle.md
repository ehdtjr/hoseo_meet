# Story media lifecycle (#27)

Run `alembic upgrade head` before starting the API and workers. Revision
`20261108_0005` adds `story_media`; it does not backfill ownership from URLs.
Back up both the database and media before rollout, following
[database-migrations.md](database-migrations.md). Downgrade is blocked because
losing upload provenance would make cleanup unsafe; restore the matching backups.
Use a coordinated API/worker rollout: older API processes cannot render the new
key-valued story rows. Stop old processes before enabling writes with this release.
Uploads staged by an older release have no ownership record and must be reuploaded.

## Ownership and retention

The upload endpoint still returns `{ "url": "..." }`. It now commits an upload
record with the authenticated owner, backend, generated key and original URL.
Story creation accepts that exact original URL or the stable key, verifies the
owner and locks the record to prevent concurrent reuse. It stores the **key** in
`story_post.image_url`. List, detail and create responses render a URL from the
record and current media base URL. Existing Flutter clients keep their URL contract.
Changing `MEDIA_BASE_URL` does not require updating new story rows; the media route
must also be reachable at the new address. Local signatures depend on the key and
secret, not the host. S3 records render with the current CloudFront domain.

Legacy stories retain their original URL and file. They have no trusted upload
record, so neither URL contents nor a user ID embedded in a path authorize cleanup.
Keep the old origin/proxy available for those URLs, or perform a separately reviewed
mapping migration. This change deliberately does not rewrite existing profile,
restaurant, review or history URLs. Moving between storage backends also requires a
separate data migration; the collector skips records from other backends.

Local uploads copy into a temporary file in the destination directory, fsync it,
then publish a complete file with an exclusive hard link. Copy failures and request
cancellation remove the operation's temporary/new file, without overwriting another
upload. Upload-record flush failure removes only that upload's generated key.
Story creation failure before commit rolls back the room/subscription/story and
returns the already uploaded image to an unclaimed draft. Its original URL remains
usable for the existing editor to retry with the same text overlay. Drafts have a
24-hour grace period measured from the original upload, after which unused images
are collected. This is distinct from an upload-record flush failure: that image
never became a valid draft and is removed immediately. Commit exceptions are
ambiguous: the server can have committed before losing the acknowledgement, so
media is retained. Profile replacement uses the same conservative rule for ambiguous
commit acknowledgements. The draft retry path does not promise idempotent recovery
of a story whose commit succeeded but whose response was lost.

Manual story deletion and the expiration task commit the story removal **before**
file deletion. They preserve the stream, recipient, messages and subscriptions so
existing conversations remain usable. The upload ledger survives story/user deletion
and retains tombstones after successful collection, making retries idempotent.
Storage failures leave a ledger row for the next periodic sweep. Celery's existing
30-minute expiration task also collects old unused and released story uploads.

The candidate query first excludes uploads referenced by an exact story key and
unclaimed uploads still inside their grace period. Published stories therefore do
not trigger repeated searches of messages and history. For remaining candidates,
collection verifies the owner/key namespace and searches application text/JSON
columns, including copied URLs and restaurant/menu history. UUID characters are
matched in both literal and percent-encoded form, so encoding part or all of a UUID
does not hide an otherwise valid read URL. Any reference preserves the file,
including references belonging to other users. The expensive fallback scans remain
necessary for legacy/free-text references on actual orphan candidates.
On PostgreSQL, collection holds the upload row lock plus SHARE table locks during
reference checks and deletion: concurrent claims and legacy writes cannot race with
collection. This can briefly block writes while storage is contacted; run manual
batch collection during a maintenance window. Unknown files, legacy files and
profile files are never eligible. Direct URL deletion rejects the story namespace,
just as it rejects profile uploads. A read signature is not deletion authority.

## Inspect, collect and recover local files

The default command only reports candidates:

```sh
cd backend
python -m app.scripts.collect_story_media
```

For manual collection, stop API/Celery writers, take and verify a consistent database
and complete media-volume backup, then review the dry-run. Production bulk cleanup
requires separate operator authorization. The commands below are a runbook, not an
instruction to execute them on production as part of this patch.

```sh
python -m app.scripts.collect_story_media --apply --backup-dir /backup/story-media/run-001
```

`--apply` requires an external directory tree and local storage. Each candidate is
copied there under its original key before deletion. Repeating a run skips completed
ledger entries. Interrupted copies are removed before any live deletion; an existing
backup must match the live bytes. Keep the full database/media snapshot as the
source for rollback, since a candidate-only backup does not capture story/chat rows.
Periodic/manual-deletion cleanup relies on your regular snapshots and does not
create candidate backups automatically. No automatic backup pruning is included.
For S3, take provider snapshots/version backups and use the same ledger/reference
policy via the worker; this CLI's backup/apply mode is intentionally local-only.

With writers still stopped, restore the matching database snapshot, then restore
missing files from the full media snapshot or candidate copies. For one recorded key:

```sh
python -m app.scripts.collect_story_media \
  --backup-dir /backup/story-media/run-001 \
  --restore-key story_post/123/0123456789abcdef0123456789abcdef_story.webp
```

Restore requires an upload record, validates its owner/key, and refuses to overwrite
a live file. It does not invent story rows, reset claims or clear tombstones. Verify
story responses and media reads against the restored database before restarting
writers. Files restored without a matching referenced story are not a complete
application recovery.

## Validation boundaries

Regression tests use a disposable PostgreSQL/Redis project and temporary media and
backup directories. They inject interrupted/cancelled copies, DB flush failures,
lost commit acknowledgements and storage deletion failures; cover manual deletion,
expiration, reference preservation (including percent-encoded UUIDs in text and JSON),
concurrent claims, URL changes, same-editor retry after a rolled-back creation,
expired draft cleanup, repeated cleanup and exclusive file restore. A PostgreSQL
query-capture regression verifies that three published stories plus a recent draft
perform zero fallback text/history searches during dry-run and apply. Migration tests cover tracked upgrade and schema parity.
These checks do not establish deployment or real AWS/physical-device behavior.

The local verification also exercised the actual CLI in a separate process against
`media_lifecycle_test_db`: `pg_dump -Fc`, dry-run, backup/apply, repeated apply,
`pg_restore --clean --if-exists`, exclusive file restore, then comparison of restored
story/ledger rows and exact image bytes. API, CLI and Celery mapper initialization
are checked independently so importing the API does not hide CLI startup defects.

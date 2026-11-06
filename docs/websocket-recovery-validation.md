# Issue #23: WebSocket recovery validation

## Behavior

- One connection attempt, cancellable handshake timeout, and retry timer per service.
  Disconnect/error retries use 1, 2, 4, 8, 16, then 30 seconds, with ping/pong
  detecting silent broken connections. Successful catch-up resets the backoff.
- Each attempt reads the current authentication state. A token change replaces the
  connection; signing out shuts down locally before awaiting the logout request.
- The room listens before connecting. Every connection reads the newest message ID
  from HTTP and walks forward in inclusive pages of 100. It starts at the oldest
  displayed message to refresh existing receipts as well as the connection gap;
  live traffic cannot replace a still-empty recovery baseline. The first empty local room starts at `oldest`. Live events never move
  this recovery checkpoint. A failed/incomplete page causes another retry.
- Recovered/live messages merge by message ID in ascending order. Duplicate Redis
  event IDs are suppressed in a bounded cache. Recovery uses durable message history
  rather than relying on Redis queue retention or FCM routing.
- Pausing immediately stops the connection and queues a room deactivation. Presence
  requests are serialized so a delayed pause cannot deactivate a resumed room.
  Every connection also restores room presence after Redis expiry/server restart.
- Receipt events trigger coalesced authoritative HTTP snapshots of affected cached
  pages, rather than arithmetic decrements. Counts merge monotonically so delayed
  snapshots/events cannot undo a later read or decrement it twice. A cache gap has
  an exact-anchor fallback; receipt refresh never inserts unknown messages.
- Read requests use the displayed/recovered numeric last ID, `num_after=0`, and
  only the known preceding range. Messages arriving beyond the HTTP watermark
  cannot be marked read by that recovery; live reads acknowledge the exact ID.
- Closing disables heartbeat before initiating the protocol close and keeps the
  transport reader until its close response/error. `closeWebSocket()` and
  `dispose()` return futures; awaited disposal includes protocol/subscription
  cleanup. Delivery and retries stop synchronously. The SDK bounds a missing close
  response with its close timeout. Results arriving after disposal are ignored.
  An auto-disposed room opens with a fresh notifier.

## Automated checks (2026-11-06)

Flutter 3.32.1 / Dart 3.8.1, matching the repository CI baseline:

```sh
cd frontend/app
cp .env.example .env
flutter pub get --enforce-lockfile
flutter test --no-pub --reporter expanded
flutter build bundle --debug --no-pub
```

29 tests passed, including the two existing login widget tests. The new tests cover
established connection closure/error, outages exceeding three attempts, backoff,
current token headers, duplicate frames, late handshakes, handshake timeouts,
cancelling asynchronous authentication, stream completion, retry cancellation,
empty history, multi-page recovery, stalled/failed pages, disposal during recovery,
and room-provider reopening. A notifier test injects a live message ID 351 while
HTTP recovery fails, then verifies IDs 1 through 351 appear exactly once. It also
checks token replacement, pause/resume, and immediate cleanup while remote logout
is deliberately blocked. Fake-clock widget tests reject leftover handshake timers.
The review regression tests additionally cover pause/resume presence ordering,
server-restart presence restoration, all cached receipts without new messages,
delayed and overlapping read snapshots, numeric read bounds, late receipt results
following disposal, and batched receipt refresh with cache holes. A real `dart:io`
WebSocket test records all zone timers and asserts zero active timers after
awaiting established-connection disposal. Presence/receipt tests use synthetic HTTP
responses; they do not establish actual FCM delivery.

Targeted `dart analyze` on changed chat services/repository/providers, tests, and
probe tools reports no issues. The main application debug bundle also builds.

## Android network probe

The checked-in probe uses the production `SocketMessageService`,
`MessageRecoveryService`, and message model with synthetic tokens and history.
Its explicit test settings use a 2-second ping interval, 3-second handshake timeout,
and 0.2-to-2-second retry delays. These are faster than production defaults.

Start a loopback synthetic server, then build a disposable Android app containing
copies of those exact production sources (the builder prints their SHA-256 values):

```sh
dart frontend/app/tool/websocket_probe_server.dart
# In another terminal; requires Flutter 3.32.1 and an Android SDK:
python3 scripts/build_websocket_probe.py --output /tmp/hoseo-ws-probe
```

Install `/tmp/hoseo-ws-probe/build/app/outputs/flutter-apk/app-debug.apk` on an
Android x86_64 emulator and launch `dev.hoseo.probe.campusmeet`. The emulator reaches
the host on `10.0.2.2:18823`. This build uses the Flutter template Android project;
it does not initialize Firebase, maps, real accounts, or the full application.

Test sequence:

1. Confirm `connected` and message 1 in `/status`.
2. Disable both emulator Wi-Fi and mobile data. Wait for the probe's
   `reconnecting` state in logcat.
3. `curl 'http://127.0.0.1:18823/publish?count=350'` while offline.
4. Restore the emulator's original network settings. Confirm the latest report has
   IDs 1..351 exactly once and checkpoint 351. Publish one more message to confirm
   live delivery after recovery.
5. Tap **Rotate token**, then check the accepted `probe-token-two` header in
   `/status`. Exercise Home/app resume and `/disconnect` separately.
6. Tap **Close service**. Confirm no additional accepted connections or messages
   after waiting longer than the probe retry cap and publishing another message.

`curl http://127.0.0.1:18823/status` returns accepted connections and app reports.
All credentials and message bodies in this probe are synthetic.

The full repository Android APK attempt was stopped after 482.5 seconds while
Gradle processed its initial caches/dependencies (exit 143). That attempt is not
reported as a successful full app APK build. The isolated probe and the main app
bundle establish different evidence layers.

The updated isolated APK built successfully in 15.0 seconds using the existing build cache. Android API 35 / x86_64
observations (2026-11-06):

| Scenario | Observed result |
| --- | --- |
| Wi-Fi and mobile data disabled | `reconnecting` in device logcat; server stayed at one accepted connection |
| Publish 350 messages offline, restore networking | IDs 1..351 exactly once, checkpoint 351, automatically connected |
| Publish after recovery | ID 352 delivered live while the HTTP checkpoint remained 351 |
| Rotate authentication | Next accepted header was `probe-token-two` |
| Home/background, publish ID 353, resume | Background disconnected; resume recovered IDs 1..353 and connected |
| Synthetic server closes sockets | Automatically reconnected with the current token |
| Close service, publish ID 354, wait 7 seconds | Client stayed at 353 messages; accepted connections stayed at five; server had zero active sockets |

The original Wi-Fi/mobile-data settings were restored. Exact observations, accepted
headers (synthetic only), final message IDs, current source hashes, and review-fix
checks are in [`evidence/issue-23/review-fixes-network-probe.json`](evidence/issue-23/review-fixes-network-probe.json).
The earlier `network-probe.json` is retained as historical evidence from before
the review fixes; its source hashes describe that earlier implementation.
Physical-device switching, real backend/provider integration, CI, and deployment
are separate checks and are not established by these local results.


## Integration with main before publication

Integrated `origin/main` at `b404e25` (including PRs #31 and #32) before publishing
the WebSocket branch. The merged code preserves authenticated request replay,
failed-draft retry identities, acknowledged-send reconciliation, numeric read
anchors, and the new room/socket disposal guards. Test repository adapters now
return the asynchronous close/dispose futures; the standalone probe builder also
copies the outgoing-message model imported by the merged chat state.

Validation on the integrated tree: 69 Flutter tests passed, locked dependency
resolution passed, targeted analysis reported no issues, and the main application
debug bundle built. The Android network observations above were recorded before
this main integration; the socket/recovery sources are unchanged by the merge.
The merged notifier/authentication/send combination is covered by the full Flutter
suite and subsequent PR CI, rather than a new full-app Android device run.

#!/usr/bin/env python3
"""Build an isolated Android probe from the repository's real connection sources."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', default='flutter')
    parser.add_argument('--output', type=Path, required=True,
                        help='New, empty directory outside the repository')
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1] / 'frontend/app'
    target = args.output.resolve()
    if target.exists() and any(target.iterdir()):
        parser.error('--output must be empty')
    subprocess.run([args.flutter, 'create', '--no-pub', '--platforms=android',
                    '--org', 'dev.hoseo.probe', '--project-name', 'campusmeet',
                    '--empty', str(target)], check=True)
    paths = [
        'lib/features/chat/data/services/socket_message_service.dart',
        'lib/features/chat/data/services/message_recovery_service.dart',
        'lib/features/chat/data/models/chat_message.dart',
        'lib/features/auth/data/models/user.dart',
        'lib/config.dart',
    ]
    for relative in paths:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / relative, destination)
        print(relative, hashlib.sha256(destination.read_bytes()).hexdigest())
    shutil.copyfile(source / 'tool/websocket_network_probe.dart', target / 'lib/main.dart')
    (target / 'pubspec.yaml').write_text('''name: campusmeet
publish_to: none
environment:
  sdk: '>=3.4.3 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  http: 1.4.0
flutter:
  uses-material-design: true
''')
    properties = target / 'android/gradle.properties'
    properties.write_text(properties.read_text() + '''
org.gradle.workers.max=2
org.gradle.parallel=false
org.gradle.vfs.watch=false
''')
    manifest = target / 'android/app/src/debug/AndroidManifest.xml'
    manifest.write_text(manifest.read_text().replace(
        '</manifest>', '<application android:usesCleartextTraffic="true" />\n</manifest>'))
    subprocess.run([args.flutter, 'pub', 'get'], cwd=target, check=True)
    subprocess.run([args.flutter, 'build', 'apk', '--debug', '--target-platform',
                    'android-x64'], cwd=target, check=True)
    print(target / 'build/app/outputs/flutter-apk/app-debug.apk')


if __name__ == '__main__':
    main()

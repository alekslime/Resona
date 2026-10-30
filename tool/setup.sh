#!/bin/sh
# One-time setup after cloning: generates the android/, ios/ and web/ folders and adds permissions.
# Needs the Flutter SDK (https://docs.flutter.dev/get-started/install). iOS builds also need a Mac with Xcode.
set -e
cd "$(dirname "$0")/.."

# `flutter create` is meant for new projects, so keep our own files safe while it runs.
rm -rf .setup_backup && mkdir .setup_backup
cp -r lib test pubspec.yaml analysis_options.yaml .setup_backup/

flutter create --project-name resonant --org com.resonant --platforms=android,ios,web .

rm -rf lib test pubspec.yaml analysis_options.yaml
cp -r .setup_backup/lib .setup_backup/test .setup_backup/pubspec.yaml .setup_backup/analysis_options.yaml .
rm -rf .setup_backup

python3 tool/patch_platforms.py .
flutter pub get
echo
echo "Done. Next:  cd backend && npm install && cp .env.example .env   (add your Meta key)"
echo "Then:        flutter test && flutter run --dart-define=API_BASE=http://<your-computer's-ip>:3000"

# flutter clean
# flutter pub get
dart run flutter_launcher_icons
echo "Starting build process..."
if flutter build apk --dart-define-from-file=.env -v --release; then
  echo "Application built successfully!"
  cp build/app/outputs/flutter-apk/app-release.apk ./cardinyoli.apk
  date
  echo "Application copied successfully!"
fi
# flutter clean

# BookFood Android release

## 1. Create the upload keystore once

Keep the generated `.jks` file and passwords in a secure backup. Losing the upload key can block future updates.

```powershell
keytool -genkeypair -v -keystore C:\\secure\\bookfood-upload-keystore.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Copy `android/key.properties.example` to `android/key.properties` and replace the placeholders. Never commit the keystore or `key.properties`.

## 2. Build against production

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release `
  --dart-define=API_BASE_URL=https://api.your-domain.com/api
```

For direct client testing:

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=https://api.your-domain.com/api
```

## 3. Acceptance checks

- Fresh installation and owner login/session restoration
- QR scan and complete employee order
- Foreground, background, and normally closed-app notification
- Order status and payment/Pay Later updates
- Logout and notification-token removal
- Invalid/expired session handling
- No HTTP traffic or local API address in the release build

The Play Store deliverable is normally `build/app/outputs/bundle/release/app-release.aab`.

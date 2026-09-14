# Push notification setup

## Flutter project

Run these commands from the folder containing `pubspec.yaml`:

```powershell
flutter pub add firebase_core
flutter pub add firebase_messaging
flutter pub add flutter_local_notifications
dart pub global run flutterfire_cli:flutterfire configure
flutter clean
flutter pub get
```

Keep the generated `lib/firebase_options.dart` and place
`google-services.json` at `android/app/google-services.json`.

## Backend

Run from the `backend` folder:

```powershell
npm install
```

Download the service-account JSON from Firebase Console:
Project settings > Service accounts > Generate new private key.

Keep that JSON outside the project and Git. For local PowerShell development:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\secure\firebase-service-account.json"
npm run dev
```

The owner must open the app once, sign in, and allow notifications. Test a new
employee order while the owner app is closed normally. Android force-stop blocks
notifications until the app is opened again.

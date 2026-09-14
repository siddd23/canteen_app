# Professional dashboard update

This package replaces the project's current `lib` folder.

## Included

- Shared responsive dashboard shell.
- Desktop sidebar and mobile bottom navigation.
- Real owner/canteen data loading.
- Real Super Admin owner-status totals.
- Responsive metric and content grids.
- Approval and rejection dialogs.
- Loading, error, empty and expired-session states.
- Consistent production-style colors and component theming.

## Test

From the Flutter project root:

```powershell
dart format lib
flutter analyze
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api
```

The Node.js backend must be running before the dashboards are tested.

## Current scope

Orders, menu management, notifications and platform settings are presented as
future module destinations because their backend APIs do not exist yet. The
dashboard does not display invented business data for those modules.

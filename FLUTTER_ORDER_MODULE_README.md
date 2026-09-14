# Flutter owner Orders workspace

The Orders destination now loads authenticated owner orders for the selected
canteen and provides:

- Pending, Accepted, Delivered and Pay Later counts;
- Active/status/payment filters;
- employee, office, item, note and total details;
- Accept, Reject and Mark Delivered actions;
- Paid, Pay Later and Payment Received actions;
- responsive one/two-column layouts and pull-to-refresh;
- session expiry and API error handling.

After copying `lib`, run:

```powershell
dart format lib
flutter analyze
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api
```

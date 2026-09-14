# BookFood client acceptance checklist

Record device, Android version, tester, date, result, and evidence for every test.

## Authentication and access

- Owner registration creates a pending account.
- Super Admin can approve or reject the owner.
- Only an approved owner can access owner modules.
- Login remains active after reopening the app.
- Password change invalidates the previous session.
- Logout removes the local session and notification token.

## Canteen, office, and menu

- Owner can create and update a canteen.
- Owner can register an office and connect only owned canteens.
- QR opens the correct office and canteen menu.
- Menu categories, prices, availability, and images display correctly.

## Ordering and fulfilment

- Employee can add items, change quantity, and place an order.
- Backend recalculates prices and totals; client values cannot override them.
- Owner receives the order live without refresh.
- Owner receives foreground, background, and normally closed-app notification.
- Employee tracking displays every permitted order-status update.
- Invalid tracking credentials do not expose order information.

## Billing and Pay Later

- Paid and Pay Later choices are recorded correctly.
- Employee-wise pending orders and combined balance are accurate.
- Settlement marks only the intended owner's matching Pay Later orders as paid.
- Sales and order-history filters return correct totals and records.

## Release acceptance

- Release build connects only to the HTTPS production API.
- No debug banner, debug signing, local IP, test account, or private secret remains.
- Core flows work after a fresh install and after an app upgrade.
- Client signs off on the tested AAB version/build number.

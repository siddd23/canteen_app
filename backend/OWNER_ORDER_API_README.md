# Owner order management API

All endpoints require an approved `canteen_owner` JWT and restrict records by
`ownerId` from the authenticated token.

```http
GET /api/orders?canteenId=CANTEEN_ID
PATCH /api/orders/:orderId/status
PATCH /api/orders/:orderId/payment
```

Status body examples:

```json
{ "status": "Accepted" }
{ "status": "Rejected" }
{ "status": "Delivered" }
```

Valid order transitions are `Pending -> Accepted -> Delivered` or
`Pending -> Rejected`.

Payment can be recorded only after delivery:

```json
{ "status": "Paid" }
{ "status": "PayLater" }
```

A Pay Later order remains in the same Orders collection and can subsequently be
marked Paid, preventing separate debt records from becoming inconsistent.
# Employee Pay Later accounts

Pay Later is exposed as a separate owner workspace. Delivered Pay Later orders
are grouped by a normalized employee identity made from name and mobile number.
The grouped total is always calculated from the underlying outstanding orders.

```http
GET /api/orders/pay-later?canteenId=:canteenId
PATCH /api/orders/pay-later/settle
```

The settle endpoint marks every outstanding bill for the supplied employee and
canteen as paid. Owners can still mark one individual order as paid through the
existing order payment endpoint.
# Owner dashboard summary

The dashboard uses one owner-protected, canteen-scoped aggregation endpoint:

```http
GET /api/orders/dashboard-summary?canteenId=:canteenId
```

It returns today's order count, pending and active orders, delivered sales for
the current Indian business day, available menu-item count, and the current
Pay Later outstanding balance. The backend derives every value from MongoDB;
Flutter does not calculate financial totals from downloaded orders.
# Live order notifications

Owners poll a lightweight checkpoint endpoint while the Flutter app is open:

```http
GET /api/orders/notifications
GET /api/orders/notifications?after=:serverCheckpoint
```

The first request establishes a server-time checkpoint without replaying old
orders. Later requests return only orders created after that checkpoint. The
query is scoped to the authenticated owner across all of their canteens. The
Flutter Orders workspace refreshes silently every 12 seconds and polling pauses
when the application is not active.
# Order history

The owner History workspace uses a paginated, owner-scoped endpoint:

```http
GET /api/orders/history
```

Supported filters are `canteenId`, `status`, `paymentStatus`, `dateFrom`,
`dateTo`, `search`, `page`, and `limit`. Search covers employee name, mobile,
office name/code, canteen name, and order number. Dates use Indian business-day
boundaries. The Flutter notification handler also plays a dependency-free
two-tone system alert when new orders arrive while the owner app is active.

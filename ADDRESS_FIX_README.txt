BOOKFOOD — SAVED EMPLOYEE ADDRESSES

Apply BOTH archives to the SAME backend and Flutter app build. Keep your existing .env, node_modules, assets, pubspec.yaml and platform directories.

NEW API ENDPOINTS (requires employee customer JWT):
  GET    /api/customers/addresses
  POST   /api/customers/addresses
  PATCH  /api/customers/addresses/:id
  PATCH  /api/customers/addresses/:id/default
  DELETE /api/customers/addresses/:id

Flutter:
  Checkout now selects a saved address. First-time users add an address once.
  Employee > Profile > Saved addresses allows viewing, editing, deleting,
  setting a default and adding more addresses.
  Address is persisted in MongoDB before the employee can submit the order.

Backend:
  Customer.savedAddresses is an array of account-linked address subdocuments.
  Legacy Customer.deliveryAddress / latest customer-linked order are imported
  on first GET addresses if there are no saved addresses yet.
  Existing backend login rate limit settings are preserved.

Verification:
  1. Backend: start updated server and login as employee.
  2. Open Profile > Saved addresses; Add Work address and save.
  3. Logout/login; saved addresses should still show that entry.
  4. Go Checkout; it should preselect the default saved address.
  5. Place order; return for another order, saved address remains.
  6. Change/delete address in Profile; checkout reflects update.

Tooling: Node syntax checks passed on changed server JS files. Flutter SDK,
MongoDB and the running application were not available for live testing.

# Socket.IO Real-Time Orders

The HTTP server now also runs a Socket.IO server on `/socket.io`.

## Authentication

- Owner clients connect with `auth: { token: JWT }` and join a private owner room.
- Employee tracking clients connect with `auth: { orderNumber, trackingToken }`
  and join only that verified order room.

## Events

- `order:new`: sent only to the owner who owns the new order.
- `order:updated`: sent to the owner and the employee's verified tracking room.
- `realtime:ready`: confirms an authenticated socket connection.

Socket CORS uses the same `CORS_ORIGINS` allowlist as the REST API. The Flutter
client keeps existing HTTP polling as a fallback for reconnection or temporary
network failures.

Browser system notifications are supported after the owner clicks the
notification bell and grants permission. Android/iOS notifications while the
app is completely closed require Firebase Cloud Messaging credentials and
platform configuration files; those secrets are intentionally not fabricated.

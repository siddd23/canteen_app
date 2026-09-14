# BookFood backend deployment checklist

## Required values

- `NODE_ENV=production`
- `PORT` (normally injected by the host)
- `APP_BASE_URL=https://api.your-domain.com`
- `MONGODB_URI` for the production MongoDB database
- `JWT_SECRET` (cryptographically random, minimum 32 characters)
- `JWT_EXPIRES_IN=7d`
- `SUPER_ADMIN_NAME`, `SUPER_ADMIN_EMAIL`, `SUPER_ADMIN_PASSWORD`
- `CORS_ORIGINS` containing only approved HTTPS web origins
- `TRUST_PROXY=1` when behind one trusted reverse proxy
- One Firebase credential method from `.env.example`

## Before deployment

1. Rotate any secret ever shared in a ZIP, message, or repository.
2. Do not upload `.env`, service-account JSON, `node_modules`, or logs.
3. Run `npm ci`, `npm run verify`, and `npm audit --omit=dev` in CI.
4. Create a least-privilege MongoDB user for this application only.
5. Restrict database network access to the hosting platform where supported.

## Verification after deployment

1. `GET /api/health` returns HTTP 200 and reports `database: connected`.
2. Owner login/session restoration and Super Admin approval work.
3. QR ordering, Socket.IO updates, and FCM notifications work.
4. Unapproved owners cannot access protected routes.
5. Disallowed browser origins receive a CORS error.

## Flutter production build

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.your-domain.com/api
```

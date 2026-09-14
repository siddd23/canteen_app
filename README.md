# Owner Profile and Settings Module

## Added

- Owner profile and business information editing
- Duplicate email and mobile protection
- Secure current-password verification and password change
- Automatic logout after a password change
- Previously issued JWT sessions become invalid after a password change
- New-order sound preference
- Pay Later enable/disable preference, enforced by the backend
- Default preparation time used when menu items do not specify one
- Audit entries for profile, preference, and password changes
- Settings destination in the owner dashboard and account-menu shortcut

## APIs

- `GET /api/account/profile`
- `PATCH /api/account/profile`
- `PATCH /api/account/preferences`
- `PATCH /api/account/password`

All account endpoints require an approved canteen-owner JWT.

# Flutter owner Menu workspace

## Included

- Real owner Menu destination in the existing responsive dashboard.
- Canteen-specific menu loading.
- Category creation and editing.
- Menu-item creation and editing.
- Availability toggles.
- Category filtering and item search.
- API-derived summary cards.
- Responsive item cards with image fallbacks.
- Vegetarian and non-vegetarian indicators.
- Loading, error and useful empty states.
- Session-expiry handling consistent with Offices and Dashboard.
- Clean heading hierarchy without repeated decorative subtitles.

## Backend routes used

```text
GET   /api/canteens/:canteenId/menu
POST  /api/canteens/:canteenId/menu/categories
PATCH /api/canteens/:canteenId/menu/categories/:categoryId
POST  /api/canteens/:canteenId/menu/items
PATCH /api/canteens/:canteenId/menu/items/:itemId
PATCH /api/canteens/:canteenId/menu/items/:itemId/availability
```

## Verify locally

Keep the backend running, then execute:

```powershell
dart format lib
flutter analyze
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:5000/api
```

Test in this order:

1. Sign in as an approved owner.
2. Open **Menu**.
3. Select a canteen.
4. Create a category.
5. Create a menu item in that category.
6. Edit the category and item.
7. Toggle item availability.
8. Switch canteens and confirm their menus remain separate.

Image entry currently uses a public HTTP/HTTPS URL. Managed image upload can be added as a separate storage module later.

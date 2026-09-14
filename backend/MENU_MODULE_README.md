# Canteen owner menu API

All endpoints require an approved canteen-owner JWT:

```text
Authorization: Bearer OWNER_TOKEN
```

The API verifies that `canteenId`, categories and items belong to the logged-in owner.

## 1. Create a category

```http
POST /api/canteens/:canteenId/menu/categories
```

```json
{
  "name": "Main Course",
  "displayOrder": 1,
  "status": "Active"
}
```

## 2. Create a menu item

```http
POST /api/canteens/:canteenId/menu/items
```

```json
{
  "categoryId": "CATEGORY_MONGODB_ID",
  "name": "Paneer Tikka",
  "description": "Chargrilled paneer with capsicum and onion",
  "price": 180,
  "foodType": "Vegetarian",
  "preparationTime": 20,
  "imageUrl": "https://example.com/paneer-tikka.jpg",
  "isAvailable": true
}
```

## 3. Get the complete owner menu

```http
GET /api/canteens/:canteenId/menu
```

The response contains `canteen`, `categories`, `items` and calculated `summary` counts.

## 4. Update a category

```http
PATCH /api/canteens/:canteenId/menu/categories/:categoryId
```

Send any of `name`, `displayOrder` or `status`.

## 5. Update an item

```http
PATCH /api/canteens/:canteenId/menu/items/:itemId
```

Send any editable item fields. A changed category is validated against the same canteen.

## 6. Toggle availability

```http
PATCH /api/canteens/:canteenId/menu/items/:itemId/availability
```

```json
{
  "isAvailable": false
}
```

Categories and items are not permanently deleted because future orders will reference them.

## Verification

```powershell
npm install
npm run dev
```

Test category creation before item creation because every item requires a valid category.

# Employee order creation API

## Public endpoint

```http
POST /api/public/orders
Content-Type: application/json
```

```json
{
  "officeCode": "OFC-8F2A10BC",
  "canteenId": "CANTEEN_MONGODB_ID",
  "customerName": "Aarav Sharma",
  "mobile": "9876543210",
  "customerNote": "Less spicy",
  "items": [
    {
      "menuItemId": "MENU_ITEM_MONGODB_ID",
      "quantity": 2
    }
  ]
}
```

The endpoint verifies the active office, assigned canteen, owner, active menu
category and item availability. It ignores client prices and totals, loads the
current prices from MongoDB and stores snapshots for order history.

New orders are created with:

```text
orderStatus: Pending
paymentStatus: Unpaid
```

Online payment is intentionally not used. Paid or Pay Later will be recorded by
the canteen owner after delivery in the owner order-management module.

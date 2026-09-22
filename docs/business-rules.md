# Business Rules

## Customers and Addresses

- A customer email must be unique.
- An order's shipping and billing addresses must belong to the order's customer.
- Blocked or inactive customers cannot place new orders through `place_order()`.

## Products and Suppliers

- Product SKU must be unique.
- Product unit price cannot be negative.
- A supplier-product pair is unique.
- Lead time must be between 1 and 90 days.

## Inventory

- Inventory is tracked by warehouse and product.
- Inventory quantity cannot be negative.
- Every stock movement should create an `inventory_transactions` row.
- Valid transaction types are `PURCHASE`, `SALE`, `RETURN`, and `ADJUSTMENT`.
- Sale transactions use negative quantity deltas.
- Purchase, return, and positive adjustment transactions use positive quantity deltas.

## Orders

- An order must contain at least one item.
- Order item quantity must be positive.
- Order item unit price is stored as a snapshot so historical orders do not change when catalog prices change.
- `place_order()` rolls back the entire order if any item has insufficient stock.
- Only orders with completed payment should be shipped or delivered.

## Payments

- Payment amount cannot be negative.
- Each order has one payment record in this version.
- Failed payments can exist for cancelled or unsuccessful orders.

## Shipping

- A shipment belongs to one order.
- Tracking number must be unique.
- Delivered date cannot be earlier than shipped date.

## Returns and Refunds

- Only delivered orders can be returned through `process_return()`.
- The return window is 30 days from delivered date.
- A return item must refer to an item from the same order.
- Return quantity cannot exceed purchased quantity after previous accepted returns.
- Accepted returns restock inventory.
- A refund must refer to a valid return and valid payment.

## Trigger Rationale

| Trigger | Event | Why it exists |
|---|---|---|
| `trg_inventory_before_insert` | Before insert on `inventory` | Gives a clear database-level error if someone attempts to create negative stock. |
| `trg_inventory_before_update` | Before update on `inventory` | Protects inventory from becoming negative even if writes bypass stored procedures. |
| `trg_return_items_before_insert` | Before insert on `return_items` | Ensures the returned item belongs to the returned order and the return quantity does not exceed purchased quantity. |
| `trg_refunds_after_update` | After update on `refunds` | Automatically marks the related return as `REFUNDED` when a refund becomes completed. |

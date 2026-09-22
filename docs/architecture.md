# Architecture

The project models an operational e-commerce database. It is designed for backend transaction processing rather than BI dashboards.

## Modules

| Module | Responsibility |
|---|---|
| Customer Management | Stores customer profile and owned billing/shipping addresses. |
| Product Management | Stores product catalog and category hierarchy. |
| Supplier Management | Maps suppliers to products with lead times and purchase pricing. |
| Inventory Management | Tracks stock by warehouse and records every stock movement. |
| Order Management | Stores order headers and line items with price snapshots. |
| Payment Management | Stores one payment record per order. |
| Shipping | Stores one shipment/tracking record per shipped order. |
| Returns and Refunds | Validates returned items against original order items and records refunds. |

## Transaction Flow

`place_order()` is the main write path.

1. Validate customer and addresses.
2. Parse JSON order items into a temporary table.
3. Validate products and quantities.
4. Start a transaction.
5. Insert order header and order lines.
6. Deduct inventory with a conditional update.
7. Insert inventory movement history.
8. Recalculate and store order total.
9. Insert pending payment.
10. Commit.

If stock is insufficient or any validation fails, the procedure rolls back and returns a message through the output parameter.

## Return Flow

`process_return()` validates that:

- The order was delivered.
- The return is within the allowed window.
- The order item belongs to the order.
- The requested return quantity does not exceed purchased quantity minus previous accepted returns.
- A completed payment exists.

Then it creates the return, return item, inventory restock transaction, and pending refund inside one transaction.

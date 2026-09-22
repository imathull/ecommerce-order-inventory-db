# Database Design

## Design Goals

- Keep the schema understandable for interviews.
- Normalize data to practical 3NF.
- Use constraints for integrity instead of relying only on application code.
- Store operational facts needed by a backend system.
- Keep analytics queries possible, but not make analytics the main purpose.

## Normalization Notes

- Customer addresses are separated from customers because a customer can have multiple addresses.
- Categories are separated from products and support a self-referencing hierarchy.
- Suppliers and products are many-to-many, so `supplier_products` stores the relationship.
- Inventory is stored per `(warehouse_id, product_id)` because the same product can exist in many warehouses.
- Orders and order items are separated because one order contains multiple products.
- Returns and return items are separated because one return can contain multiple original order lines.
- Refunds are separate from returns because refund processing has its own status, reference, and timestamp.

## Stored Totals

`orders.order_total` is stored even though it can be calculated from `order_items`. In operational systems this is common because:

- The total is used frequently by payment and customer service workflows.
- The line item price is a historical snapshot.
- The stored total is recalculated by controlled procedures and can be checked with `fn_order_total()`.

## Keys

- Most tables use surrogate integer primary keys for simple joins and backend references.
- `inventory` uses a composite primary key `(warehouse_id, product_id)` because one row represents stock for exactly one product at one warehouse.
- `supplier_products` uses a composite primary key `(supplier_id, product_id)` because the relationship itself is the entity.

## Constraints

Important constraints include:

- Unique customer email.
- Unique product SKU.
- Unique shipment tracking number.
- Non-negative prices, totals, payments, refunds, and inventory quantities.
- Foreign keys between orders, customers, addresses, order items, products, warehouses, returns, and refunds.

## Views

- `vw_order_summary`: application/customer-service order lookup.
- `vw_customer_order_history`: customer support and account history.
- `vw_product_inventory_status`: stock availability and low-stock monitoring.
- `vw_pending_shipments`: fulfilment queue.
- `vw_return_summary`: return/refund status tracking.

## Index Strategy

Indexes are created for common access patterns:

- Customer order history: `orders(customer_id, order_date)`.
- Order lifecycle queues: `orders(order_status, order_date)`.
- Product sales queries: `order_items(product_id, order_id)`.
- Warehouse fulfilment: `order_items(warehouse_id, product_id, order_id)`.
- Payment exceptions: `payments(payment_status, paid_at)`.
- Shipment queue: `shipments(shipment_status, estimated_delivery_at)`.
- Inventory lookup: `inventory(product_id, quantity_on_hand)`.

The project avoids indexing every column because indexes speed up reads but increase write cost and storage.

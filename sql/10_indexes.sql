USE ecommerce_order_inventory_db;

-- Performance demonstration query before adding a status/date payment index.
-- On MySQL 8.0.18+, replace EXPLAIN with EXPLAIN ANALYZE to see actual execution metrics.
EXPLAIN
SELECT
    p.payment_id,
    p.order_id,
    p.payment_status,
    p.paid_at,
    o.order_total
FROM payments p
JOIN orders o ON o.order_id = p.order_id
WHERE p.payment_status = 'FAILED'
  AND p.paid_at IS NULL;

CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date);
CREATE INDEX idx_orders_status_date ON orders(order_status, order_date);
CREATE INDEX idx_order_items_product_order ON order_items(product_id, order_id);
CREATE INDEX idx_order_items_warehouse_product_order ON order_items(warehouse_id, product_id, order_id);
CREATE INDEX idx_payments_status_paid_at ON payments(payment_status, paid_at);
CREATE INDEX idx_shipments_status_eta ON shipments(shipment_status, estimated_delivery_at);
CREATE INDEX idx_returns_order_status_date ON `returns`(order_id, return_status, return_date);
CREATE INDEX idx_return_items_order_item ON return_items(order_item_id);
CREATE INDEX idx_inventory_product_quantity ON inventory(product_id, quantity_on_hand);
CREATE INDEX idx_inventory_transactions_product_date ON inventory_transactions(product_id, created_at);
CREATE INDEX idx_inventory_transactions_warehouse_product_date ON inventory_transactions(warehouse_id, product_id, created_at);
CREATE INDEX idx_products_category_status ON products(category_id, product_status);

-- Same query after idx_payments_status_paid_at.
-- Expected plan change: MySQL can use payment_status/paid_at to narrow payments before joining orders.
-- Do not hard-code timing claims; results depend on local hardware and table statistics.
EXPLAIN
SELECT
    p.payment_id,
    p.order_id,
    p.payment_status,
    p.paid_at,
    o.order_total
FROM payments p
JOIN orders o ON o.order_id = p.order_id
WHERE p.payment_status = 'FAILED'
  AND p.paid_at IS NULL;

ANALYZE TABLE customers, orders, order_items, payments, shipments, products, inventory, `returns`, return_items, refunds;

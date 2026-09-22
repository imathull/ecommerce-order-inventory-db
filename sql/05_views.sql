USE ecommerce_order_inventory_db;

CREATE OR REPLACE VIEW vw_order_summary AS
SELECT
    o.order_id,
    o.order_date,
    o.order_status,
    o.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    COUNT(oi.order_item_id) AS item_count,
    SUM(oi.quantity) AS total_units,
    o.order_total,
    p.payment_status,
    p.payment_method,
    s.shipment_status,
    s.tracking_number
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
LEFT JOIN payments p ON p.order_id = o.order_id
LEFT JOIN shipments s ON s.order_id = o.order_id
GROUP BY
    o.order_id, o.order_date, o.order_status, o.customer_id,
    c.first_name, c.last_name, c.email, o.order_total,
    p.payment_status, p.payment_method, s.shipment_status, s.tracking_number;

CREATE OR REPLACE VIEW vw_customer_order_history AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    o.order_id,
    o.order_date,
    o.order_status,
    o.order_total,
    p.payment_status,
    s.shipment_status
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
LEFT JOIN payments p ON p.order_id = o.order_id
LEFT JOIN shipments s ON s.order_id = o.order_id;

CREATE OR REPLACE VIEW vw_product_inventory_status AS
SELECT
    p.product_id,
    p.sku,
    p.product_name,
    c.category_name,
    SUM(i.quantity_on_hand) AS total_quantity_on_hand,
    SUM(i.reorder_level) AS total_reorder_level,
    CASE
        WHEN SUM(i.quantity_on_hand) = 0 THEN 'OUT_OF_STOCK'
        WHEN SUM(i.quantity_on_hand) <= SUM(i.reorder_level) THEN 'LOW_STOCK'
        ELSE 'IN_STOCK'
    END AS inventory_status,
    COUNT(DISTINCT CASE WHEN i.quantity_on_hand > 0 THEN i.warehouse_id END) AS stocked_warehouse_count
FROM products p
JOIN categories c ON c.category_id = p.category_id
LEFT JOIN inventory i ON i.product_id = p.product_id
GROUP BY p.product_id, p.sku, p.product_name, c.category_name;

CREATE OR REPLACE VIEW vw_pending_shipments AS
SELECT
    o.order_id,
    o.order_date,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    o.order_total,
    s.shipment_id,
    s.carrier,
    s.tracking_number,
    s.shipment_status,
    s.estimated_delivery_at
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
LEFT JOIN shipments s ON s.order_id = o.order_id
WHERE o.order_status IN ('PAID', 'SHIPPED')
  AND (s.shipment_id IS NULL OR s.shipment_status <> 'DELIVERED');

CREATE OR REPLACE VIEW vw_return_summary AS
SELECT
    r.return_id,
    r.order_id,
    r.return_date,
    r.return_status,
    r.reason,
    COUNT(ri.return_item_id) AS returned_line_count,
    SUM(ri.quantity) AS returned_units,
    COALESCE(SUM(ri.quantity * oi.unit_price * (1 - oi.discount_percent / 100)), 0) AS estimated_return_value,
    rf.refund_status,
    rf.refund_amount,
    rf.refunded_at
FROM `returns` r
JOIN return_items ri ON ri.return_id = r.return_id
JOIN order_items oi ON oi.order_item_id = ri.order_item_id
LEFT JOIN refunds rf ON rf.return_id = r.return_id
GROUP BY
    r.return_id, r.order_id, r.return_date, r.return_status,
    r.reason, rf.refund_status, rf.refund_amount, rf.refunded_at;

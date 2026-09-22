USE ecommerce_order_inventory_db;

-- 1. INNER JOIN: paid orders with customer and payment details.
SELECT
    o.order_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    o.order_date,
    o.order_total,
    p.payment_method
FROM orders o
INNER JOIN customers c ON c.customer_id = o.customer_id
INNER JOIN payments p ON p.order_id = o.order_id
WHERE p.payment_status = 'COMPLETED'
ORDER BY o.order_date DESC
LIMIT 20;

-- 2. LEFT JOIN: customers who have never placed an order.
SELECT c.customer_id, c.email, c.customer_status
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- 3. Multi-table join: complete order history with products.
SELECT
    o.order_id,
    o.order_date,
    c.email,
    p.sku,
    p.product_name,
    oi.quantity,
    oi.unit_price,
    oi.discount_percent,
    w.warehouse_name
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN warehouses w ON w.warehouse_id = oi.warehouse_id
ORDER BY o.order_date DESC, o.order_id, oi.order_item_id
LIMIT 50;

-- 4. Aggregation with HAVING: repeat customers by completed or shipped activity.
SELECT
    c.customer_id,
    c.email,
    COUNT(o.order_id) AS order_count,
    SUM(o.order_total) AS gross_order_value
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status IN ('PAID', 'SHIPPED', 'DELIVERED', 'RETURNED')
GROUP BY c.customer_id, c.email
HAVING COUNT(o.order_id) >= 3
ORDER BY order_count DESC, gross_order_value DESC;

-- 5. Aggregate product performance: top products by quantity sold.
SELECT
    p.product_id,
    p.sku,
    p.product_name,
    SUM(oi.quantity) AS units_sold
FROM products p
JOIN order_items oi ON oi.product_id = p.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status <> 'CANCELLED'
GROUP BY p.product_id, p.sku, p.product_name
ORDER BY units_sold DESC
LIMIT 10;

-- 6. Top products by revenue after line-level discounts.
SELECT
    p.product_id,
    p.product_name,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100)), 2) AS net_revenue
FROM products p
JOIN order_items oi ON oi.product_id = p.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status <> 'CANCELLED'
GROUP BY p.product_id, p.product_name
ORDER BY net_revenue DESC
LIMIT 10;

-- 7. CASE expression: classify customers by lifetime value.
SELECT
    c.customer_id,
    c.email,
    fn_customer_lifetime_value(c.customer_id) AS lifetime_value,
    CASE
        WHEN fn_customer_lifetime_value(c.customer_id) >= 100000 THEN 'PREMIUM'
        WHEN fn_customer_lifetime_value(c.customer_id) >= 50000 THEN 'GROWING'
        WHEN fn_customer_lifetime_value(c.customer_id) > 0 THEN 'NEW_OR_OCCASIONAL'
        ELSE 'NO_PAID_ORDERS'
    END AS customer_segment
FROM customers c
ORDER BY lifetime_value DESC
LIMIT 25;

-- 8. Non-correlated subquery: orders larger than average order value.
SELECT order_id, customer_id, order_date, order_total
FROM orders
WHERE order_total > (
    SELECT AVG(order_total)
    FROM orders
    WHERE order_status <> 'CANCELLED'
)
ORDER BY order_total DESC
LIMIT 20;

-- 9. Correlated subquery: highest-value order for each customer.
SELECT o.order_id, o.customer_id, o.order_total, o.order_date
FROM orders o
WHERE o.order_total = (
    SELECT MAX(o2.order_total)
    FROM orders o2
    WHERE o2.customer_id = o.customer_id
)
ORDER BY o.order_total DESC;

-- 10. CTE: monthly order volume and average order value.
WITH monthly_orders AS (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m-01') AS order_month,
        COUNT(*) AS order_count,
        ROUND(AVG(order_total), 2) AS average_order_value
    FROM orders
    WHERE order_status <> 'CANCELLED'
    GROUP BY DATE_FORMAT(order_date, '%Y-%m-01')
)
SELECT *
FROM monthly_orders
ORDER BY order_month;

-- 11. CTE: products with low inventory by total stock.
WITH inventory_rollup AS (
    SELECT
        product_id,
        SUM(quantity_on_hand) AS total_stock,
        SUM(reorder_level) AS total_reorder_level
    FROM inventory
    GROUP BY product_id
)
SELECT p.sku, p.product_name, ir.total_stock, ir.total_reorder_level
FROM inventory_rollup ir
JOIN products p ON p.product_id = ir.product_id
WHERE ir.total_stock <= ir.total_reorder_level
ORDER BY ir.total_stock;

-- 12. Recursive CTE: category tree with depth and path.
WITH RECURSIVE category_tree AS (
    SELECT
        category_id,
        parent_category_id,
        category_name,
        0 AS depth,
        CAST(category_name AS CHAR(500)) AS category_path
    FROM categories
    WHERE parent_category_id IS NULL
    UNION ALL
    SELECT
        c.category_id,
        c.parent_category_id,
        c.category_name,
        ct.depth + 1,
        CONCAT(ct.category_path, ' > ', c.category_name)
    FROM categories c
    JOIN category_tree ct ON ct.category_id = c.parent_category_id
)
SELECT *
FROM category_tree
ORDER BY category_path;

-- 13. ROW_NUMBER(): most recent order per customer.
WITH ranked_orders AS (
    SELECT
        o.*,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC, order_id DESC) AS rn
    FROM orders o
)
SELECT customer_id, order_id, order_date, order_status, order_total
FROM ranked_orders
WHERE rn = 1;

-- 14. RANK(): rank products by revenue with ties preserved.
WITH product_revenue AS (
    SELECT
        p.category_id,
        p.product_id,
        p.product_name,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100)), 2) AS revenue
    FROM products p
    JOIN order_items oi ON oi.product_id = p.product_id
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status <> 'CANCELLED'
    GROUP BY p.category_id, p.product_id, p.product_name
)
SELECT
    c.category_name,
    product_name,
    revenue,
    RANK() OVER (PARTITION BY category_id ORDER BY revenue DESC) AS revenue_rank
FROM product_revenue pr
JOIN categories c ON c.category_id = pr.category_id
ORDER BY c.category_name, revenue_rank;

-- 15. DENSE_RANK(): dense product ranking within each category.
WITH product_units AS (
    SELECT
        p.category_id,
        p.product_id,
        p.product_name,
        SUM(oi.quantity) AS units_sold
    FROM products p
    JOIN order_items oi ON oi.product_id = p.product_id
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status <> 'CANCELLED'
    GROUP BY p.category_id, p.product_id, p.product_name
)
SELECT
    c.category_name,
    product_name,
    units_sold,
    DENSE_RANK() OVER (PARTITION BY category_id ORDER BY units_sold DESC) AS category_dense_rank
FROM product_units pu
JOIN categories c ON c.category_id = pu.category_id
ORDER BY c.category_name, category_dense_rank;

-- 16. LAG(): compare current month revenue with previous month.
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m-01') AS order_month,
        SUM(order_total) AS revenue
    FROM orders
    WHERE order_status <> 'CANCELLED'
    GROUP BY DATE_FORMAT(order_date, '%Y-%m-01')
)
SELECT
    order_month,
    revenue,
    LAG(revenue) OVER (ORDER BY order_month) AS previous_month_revenue,
    revenue - LAG(revenue) OVER (ORDER BY order_month) AS revenue_change
FROM monthly_revenue
ORDER BY order_month;

-- 17. LEAD(): show next order date for each customer order.
SELECT
    customer_id,
    order_id,
    order_date,
    LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS next_order_date
FROM orders
ORDER BY customer_id, order_date;

-- 18. Running revenue by month.
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m-01') AS order_month,
        SUM(order_total) AS revenue
    FROM orders
    WHERE order_status <> 'CANCELLED'
    GROUP BY DATE_FORMAT(order_date, '%Y-%m-01')
)
SELECT
    order_month,
    revenue,
    SUM(revenue) OVER (ORDER BY order_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_revenue
FROM monthly_revenue
ORDER BY order_month;

-- 19. Orders with failed payments.
SELECT o.order_id, o.order_date, o.order_status, p.payment_status, p.amount
FROM orders o
JOIN payments p ON p.order_id = o.order_id
WHERE p.payment_status = 'FAILED'
ORDER BY o.order_date DESC;

-- 20. Orders that have not shipped.
SELECT o.order_id, o.order_date, o.order_status, o.order_total
FROM orders o
LEFT JOIN shipments s ON s.order_id = o.order_id
WHERE o.order_status IN ('PAID', 'CONFIRMED')
  AND s.shipment_id IS NULL
ORDER BY o.order_date;

-- 21. Warehouse inventory status.
SELECT
    w.warehouse_name,
    COUNT(i.product_id) AS stocked_products,
    SUM(i.quantity_on_hand) AS total_units,
    SUM(CASE WHEN i.quantity_on_hand <= i.reorder_level THEN 1 ELSE 0 END) AS low_stock_sku_count
FROM warehouses w
JOIN inventory i ON i.warehouse_id = w.warehouse_id
GROUP BY w.warehouse_id, w.warehouse_name
ORDER BY total_units DESC;

-- 22. Products available across multiple warehouses.
SELECT
    p.sku,
    p.product_name,
    COUNT(DISTINCT i.warehouse_id) AS available_warehouses,
    SUM(i.quantity_on_hand) AS total_stock
FROM products p
JOIN inventory i ON i.product_id = p.product_id
WHERE i.quantity_on_hand > 0
GROUP BY p.product_id, p.sku, p.product_name
HAVING COUNT(DISTINCT i.warehouse_id) >= 2
ORDER BY available_warehouses DESC, total_stock DESC;

-- 23. Products frequently returned.
SELECT
    p.product_id,
    p.product_name,
    COUNT(DISTINCT r.return_id) AS return_count,
    SUM(ri.quantity) AS returned_units
FROM products p
JOIN order_items oi ON oi.product_id = p.product_id
JOIN return_items ri ON ri.order_item_id = oi.order_item_id
JOIN `returns` r ON r.return_id = ri.return_id
GROUP BY p.product_id, p.product_name
ORDER BY returned_units DESC, return_count DESC;

-- 24. Customers with returned orders.
SELECT DISTINCT
    c.customer_id,
    c.email,
    r.return_id,
    r.return_status,
    rf.refund_status
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN `returns` r ON r.order_id = o.order_id
LEFT JOIN refunds rf ON rf.return_id = r.return_id
ORDER BY c.customer_id;

-- 25. Inactive customers: no orders in the last 180 days.
SELECT
    c.customer_id,
    c.email,
    MAX(o.order_date) AS last_order_date
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.email
HAVING last_order_date IS NULL
    OR last_order_date < DATE_SUB(CURDATE(), INTERVAL 180 DAY)
ORDER BY last_order_date;

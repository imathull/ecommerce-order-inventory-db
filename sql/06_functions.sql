USE ecommerce_order_inventory_db;

DELIMITER $$

DROP FUNCTION IF EXISTS fn_order_total $$
CREATE FUNCTION fn_order_total(p_order_id BIGINT)
RETURNS DECIMAL(12,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2);

    SELECT COALESCE(ROUND(SUM(quantity * unit_price * (1 - discount_percent / 100)), 2), 0)
    INTO v_total
    FROM order_items
    WHERE order_id = p_order_id;

    RETURN v_total;
END $$

DROP FUNCTION IF EXISTS fn_customer_lifetime_value $$
CREATE FUNCTION fn_customer_lifetime_value(p_customer_id INT)
RETURNS DECIMAL(12,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_paid_total DECIMAL(12,2);
    DECLARE v_refunded_total DECIMAL(12,2);

    SELECT COALESCE(SUM(p.amount), 0)
    INTO v_paid_total
    FROM orders o
    JOIN payments p ON p.order_id = o.order_id
    WHERE o.customer_id = p_customer_id
      AND p.payment_status IN ('COMPLETED', 'REFUNDED');

    SELECT COALESCE(SUM(rf.refund_amount), 0)
    INTO v_refunded_total
    FROM orders o
    JOIN `returns` r ON r.order_id = o.order_id
    JOIN refunds rf ON rf.return_id = r.return_id
    WHERE o.customer_id = p_customer_id
      AND rf.refund_status = 'COMPLETED';

    RETURN v_paid_total - v_refunded_total;
END $$

DROP FUNCTION IF EXISTS fn_inventory_status $$
CREATE FUNCTION fn_inventory_status(p_product_id INT, p_warehouse_id INT)
RETURNS VARCHAR(20)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_quantity INT;
    DECLARE v_reorder_level INT;

    SELECT quantity_on_hand, reorder_level
    INTO v_quantity, v_reorder_level
    FROM inventory
    WHERE product_id = p_product_id
      AND warehouse_id = p_warehouse_id;

    RETURN CASE
        WHEN v_quantity IS NULL THEN 'NOT_STOCKED'
        WHEN v_quantity = 0 THEN 'OUT_OF_STOCK'
        WHEN v_quantity <= v_reorder_level THEN 'LOW_STOCK'
        ELSE 'IN_STOCK'
    END;
END $$

DELIMITER ;

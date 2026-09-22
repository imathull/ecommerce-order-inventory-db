USE ecommerce_order_inventory_db;

DELIMITER $$

DROP PROCEDURE IF EXISTS place_order $$
CREATE PROCEDURE place_order(
    IN p_customer_id INT,
    IN p_shipping_address_id INT,
    IN p_billing_address_id INT,
    IN p_warehouse_id INT,
    IN p_items JSON,
    IN p_payment_method VARCHAR(20),
    OUT p_order_id BIGINT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_count INT DEFAULT 0;
    DECLARE v_item_count INT DEFAULT 0;
    DECLARE v_rows_changed INT DEFAULT 0;
    DECLARE v_order_total DECIMAL(12,2) DEFAULT 0;
    DECLARE v_sqlstate CHAR(5);
    DECLARE v_errno INT;
    DECLARE v_text TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_errno = MYSQL_ERRNO,
            v_text = MESSAGE_TEXT;
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS tmp_place_order_items;
        SET p_order_id = NULL;
        SET p_message = CONCAT('Order failed: ', v_text);
    END;

    SET p_order_id = NULL;
    SET p_message = NULL;

    IF p_items IS NULL OR JSON_VALID(p_items) = 0 OR JSON_LENGTH(p_items) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order must contain at least one item';
    END IF;

    IF p_payment_method NOT IN ('CARD', 'UPI', 'NET_BANKING', 'WALLET', 'COD') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unsupported payment method';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM customers
    WHERE customer_id = p_customer_id
      AND customer_status = 'ACTIVE';

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer does not exist or is not active';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM customer_addresses
    WHERE customer_id = p_customer_id
      AND address_id IN (p_shipping_address_id, p_billing_address_id);

    IF v_count < CASE WHEN p_shipping_address_id = p_billing_address_id THEN 1 ELSE 2 END THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Billing or shipping address does not belong to the customer';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM warehouses
    WHERE warehouse_id = p_warehouse_id
      AND is_active = TRUE;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Warehouse does not exist or is inactive';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_place_order_items;
    CREATE TEMPORARY TABLE tmp_place_order_items (
        product_id INT PRIMARY KEY,
        quantity INT NOT NULL
    ) ENGINE=Memory;

    INSERT INTO tmp_place_order_items (product_id, quantity)
    SELECT product_id, SUM(quantity)
    FROM JSON_TABLE(
        p_items,
        '$[*]' COLUMNS (
            product_id INT PATH '$.product_id' ERROR ON EMPTY ERROR ON ERROR,
            quantity INT PATH '$.quantity' ERROR ON EMPTY ERROR ON ERROR
        )
    ) AS jt
    GROUP BY product_id;

    SELECT COUNT(*) INTO v_item_count FROM tmp_place_order_items;

    IF v_item_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order must contain at least one valid item';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM tmp_place_order_items
    WHERE quantity <= 0;

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order item quantity must be positive';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM tmp_place_order_items toi
    LEFT JOIN products p
      ON p.product_id = toi.product_id
     AND p.product_status = 'ACTIVE'
    WHERE p.product_id IS NULL;

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'One or more products are invalid or inactive';
    END IF;

    START TRANSACTION;

    INSERT INTO orders (
        customer_id, shipping_address_id, billing_address_id, order_status, order_total
    )
    VALUES (p_customer_id, p_shipping_address_id, p_billing_address_id, 'CONFIRMED', 0);

    SET p_order_id = LAST_INSERT_ID();

    INSERT INTO order_items (
        order_id, product_id, warehouse_id, quantity, unit_price, discount_percent
    )
    SELECT p_order_id, toi.product_id, p_warehouse_id, toi.quantity, p.unit_price, 0
    FROM tmp_place_order_items toi
    JOIN products p ON p.product_id = toi.product_id;

    UPDATE inventory inv
    JOIN tmp_place_order_items toi
      ON toi.product_id = inv.product_id
    SET inv.quantity_on_hand = inv.quantity_on_hand - toi.quantity
    WHERE inv.warehouse_id = p_warehouse_id
      AND inv.quantity_on_hand >= toi.quantity;

    SET v_rows_changed = ROW_COUNT();

    IF v_rows_changed <> v_item_count THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient inventory for one or more products';
    END IF;

    INSERT INTO inventory_transactions (
        warehouse_id, product_id, transaction_type, quantity_delta, reference_type, reference_id, notes
    )
    SELECT p_warehouse_id, product_id, 'SALE', -quantity, 'ORDER', p_order_id, 'Placed through place_order procedure'
    FROM tmp_place_order_items;

    SELECT fn_order_total(p_order_id) INTO v_order_total;

    UPDATE orders
    SET order_total = v_order_total
    WHERE order_id = p_order_id;

    INSERT INTO payments (
        order_id, payment_method, payment_status, amount, transaction_reference, paid_at
    )
    VALUES (p_order_id, p_payment_method, 'PENDING', v_order_total, NULL, NULL);

    COMMIT;

    DROP TEMPORARY TABLE IF EXISTS tmp_place_order_items;
    SET p_message = CONCAT('Order ', p_order_id, ' created successfully. Payment is pending.');
END $$

DROP PROCEDURE IF EXISTS add_inventory $$
CREATE PROCEDURE add_inventory(
    IN p_product_id INT,
    IN p_warehouse_id INT,
    IN p_quantity INT,
    IN p_transaction_type VARCHAR(20),
    IN p_notes VARCHAR(255),
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_count INT DEFAULT 0;
    DECLARE v_sqlstate CHAR(5);
    DECLARE v_errno INT;
    DECLARE v_text TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_errno = MYSQL_ERRNO,
            v_text = MESSAGE_TEXT;
        ROLLBACK;
        SET p_message = CONCAT('Inventory update failed: ', v_text);
    END;

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory addition quantity must be positive';
    END IF;

    IF p_transaction_type NOT IN ('PURCHASE', 'ADJUSTMENT') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'add_inventory supports only PURCHASE or ADJUSTMENT';
    END IF;

    SELECT COUNT(*) INTO v_count FROM products WHERE product_id = p_product_id;
    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product does not exist';
    END IF;

    SELECT COUNT(*) INTO v_count FROM warehouses WHERE warehouse_id = p_warehouse_id AND is_active = TRUE;
    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Warehouse does not exist or is inactive';
    END IF;

    START TRANSACTION;

    INSERT INTO inventory (warehouse_id, product_id, quantity_on_hand, reorder_level, safety_stock)
    VALUES (p_warehouse_id, p_product_id, p_quantity, 10, 5)
    ON DUPLICATE KEY UPDATE quantity_on_hand = quantity_on_hand + VALUES(quantity_on_hand);

    INSERT INTO inventory_transactions (
        warehouse_id, product_id, transaction_type, quantity_delta, reference_type, reference_id, notes
    )
    VALUES (p_warehouse_id, p_product_id, p_transaction_type, p_quantity, 'MANUAL_ADJUSTMENT', NULL, p_notes);

    COMMIT;

    SET p_message = 'Inventory updated successfully';
END $$

DROP PROCEDURE IF EXISTS update_order_status $$
CREATE PROCEDURE update_order_status(
    IN p_order_id BIGINT,
    IN p_new_status VARCHAR(20),
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_payment_status VARCHAR(20);

    SELECT o.order_status, p.payment_status
    INTO v_current_status, v_payment_status
    FROM orders o
    LEFT JOIN payments p ON p.order_id = o.order_id
    WHERE o.order_id = p_order_id;

    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order does not exist';
    END IF;

    IF p_new_status NOT IN ('PENDING', 'CONFIRMED', 'PAID', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'RETURNED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid order status';
    END IF;

    IF p_new_status IN ('SHIPPED', 'DELIVERED') AND v_payment_status <> 'COMPLETED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only paid orders can be shipped or delivered';
    END IF;

    IF v_current_status IN ('CANCELLED', 'RETURNED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Terminal order status cannot be changed';
    END IF;

    UPDATE orders
    SET order_status = p_new_status
    WHERE order_id = p_order_id;

    SET p_message = CONCAT('Order status updated from ', v_current_status, ' to ', p_new_status);
END $$

DROP PROCEDURE IF EXISTS process_return $$
CREATE PROCEDURE process_return(
    IN p_order_id BIGINT,
    IN p_order_item_id BIGINT,
    IN p_quantity INT,
    IN p_reason VARCHAR(255),
    OUT p_return_id BIGINT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_order_item_order_id BIGINT;
    DECLARE v_product_id INT;
    DECLARE v_warehouse_id INT;
    DECLARE v_purchased_qty INT;
    DECLARE v_already_returned_qty INT DEFAULT 0;
    DECLARE v_available_qty INT DEFAULT 0;
    DECLARE v_unit_price DECIMAL(10,2);
    DECLARE v_discount DECIMAL(5,2);
    DECLARE v_payment_id BIGINT;
    DECLARE v_refund_amount DECIMAL(12,2);
    DECLARE v_delivered_at DATETIME;
    DECLARE v_sqlstate CHAR(5);
    DECLARE v_errno INT;
    DECLARE v_text TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_errno = MYSQL_ERRNO,
            v_text = MESSAGE_TEXT;
        ROLLBACK;
        SET p_return_id = NULL;
        SET p_message = CONCAT('Return failed: ', v_text);
    END;

    SET p_return_id = NULL;

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return quantity must be positive';
    END IF;

    SELECT s.delivered_at
    INTO v_delivered_at
    FROM orders o
    JOIN shipments s ON s.order_id = o.order_id
    WHERE o.order_id = p_order_id
      AND o.order_status IN ('DELIVERED', 'RETURNED')
      AND s.shipment_status = 'DELIVERED';

    IF v_delivered_at IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only delivered orders can be returned';
    END IF;

    IF DATEDIFF(CURDATE(), DATE(v_delivered_at)) > 30 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return window has expired';
    END IF;

    SELECT oi.order_id, oi.product_id, oi.warehouse_id, oi.quantity, oi.unit_price, oi.discount_percent
    INTO v_order_item_order_id, v_product_id, v_warehouse_id, v_purchased_qty, v_unit_price, v_discount
    FROM order_items oi
    WHERE oi.order_item_id = p_order_item_id;

    IF v_order_item_order_id IS NULL OR v_order_item_order_id <> p_order_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order item does not belong to the order';
    END IF;

    SELECT COALESCE(SUM(ri.quantity), 0)
    INTO v_already_returned_qty
    FROM return_items ri
    JOIN `returns` r ON r.return_id = ri.return_id
    WHERE ri.order_item_id = p_order_item_id
      AND r.return_status <> 'REJECTED';

    SET v_available_qty = v_purchased_qty - v_already_returned_qty;

    IF p_quantity > v_available_qty THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return quantity exceeds available purchased quantity';
    END IF;

    SELECT payment_id
    INTO v_payment_id
    FROM payments
    WHERE order_id = p_order_id
      AND payment_status = 'COMPLETED'
    LIMIT 1;

    IF v_payment_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Completed payment not found for order';
    END IF;

    SET v_refund_amount = ROUND(p_quantity * v_unit_price * (1 - v_discount / 100), 2);

    START TRANSACTION;

    INSERT INTO `returns` (order_id, return_status, reason)
    VALUES (p_order_id, 'APPROVED', p_reason);

    SET p_return_id = LAST_INSERT_ID();

    INSERT INTO return_items (return_id, order_item_id, quantity, item_condition)
    VALUES (p_return_id, p_order_item_id, p_quantity, 'OPENED');

    UPDATE inventory
    SET quantity_on_hand = quantity_on_hand + p_quantity
    WHERE warehouse_id = v_warehouse_id
      AND product_id = v_product_id;

    INSERT INTO inventory_transactions (
        warehouse_id, product_id, transaction_type, quantity_delta, reference_type, reference_id, notes
    )
    VALUES (v_warehouse_id, v_product_id, 'RETURN', p_quantity, 'RETURN', p_return_id, 'Return accepted through process_return procedure');

    INSERT INTO refunds (return_id, payment_id, refund_status, refund_amount)
    VALUES (p_return_id, v_payment_id, 'PENDING', v_refund_amount);

    UPDATE orders
    SET order_status = 'RETURNED'
    WHERE order_id = p_order_id;

    COMMIT;

    SET p_message = CONCAT('Return ', p_return_id, ' approved. Refund is pending.');
END $$

DROP PROCEDURE IF EXISTS process_refund $$
CREATE PROCEDURE process_refund(
    IN p_refund_id BIGINT,
    IN p_refund_reference VARCHAR(80),
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_return_id BIGINT;
    DECLARE v_status VARCHAR(20);

    SELECT return_id, refund_status
    INTO v_return_id, v_status
    FROM refunds
    WHERE refund_id = p_refund_id;

    IF v_return_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Refund does not exist';
    END IF;

    IF v_status = 'COMPLETED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Refund is already completed';
    END IF;

    START TRANSACTION;

    UPDATE refunds
    SET refund_status = 'COMPLETED',
        refund_reference = p_refund_reference,
        refunded_at = CURRENT_TIMESTAMP
    WHERE refund_id = p_refund_id;

    UPDATE `returns`
    SET return_status = 'REFUNDED'
    WHERE return_id = v_return_id;

    COMMIT;

    SET p_message = CONCAT('Refund ', p_refund_id, ' completed.');
END $$

DELIMITER ;

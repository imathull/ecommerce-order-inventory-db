USE ecommerce_order_inventory_db;

DELIMITER $$

DROP PROCEDURE IF EXISTS run_database_integrity_tests $$
CREATE PROCEDURE run_database_integrity_tests()
BEGIN
    DECLARE v_failed BOOLEAN DEFAULT FALSE;
    DECLARE v_before_count INT DEFAULT 0;
    DECLARE v_after_count INT DEFAULT 0;
    DECLARE v_address_id INT;
    DECLARE v_order_id BIGINT;
    DECLARE v_message VARCHAR(255);

    DROP TEMPORARY TABLE IF EXISTS test_results;
    CREATE TEMPORARY TABLE test_results (
        test_name VARCHAR(120) NOT NULL,
        result ENUM('PASS', 'FAIL') NOT NULL,
        detail VARCHAR(255) NOT NULL
    ) ENGINE=Memory;

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_failed = TRUE;
        SET v_failed = FALSE;
        START TRANSACTION;
        INSERT INTO customer_addresses (customer_id, line1, city, state, postal_code)
        VALUES (999999, 'Invalid FK Street', 'Test City', 'Test State', '000000');
        IF v_failed THEN
            ROLLBACK;
            INSERT INTO test_results VALUES ('invalid customer foreign key', 'PASS', 'Rejected address for missing customer');
        ELSE
            ROLLBACK;
            INSERT INTO test_results VALUES ('invalid customer foreign key', 'FAIL', 'Invalid address was accepted');
        END IF;
    END;

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_failed = TRUE;
        SET v_failed = FALSE;
        START TRANSACTION;
        INSERT INTO customers (first_name, last_name, email)
        VALUES ('Duplicate', 'Email', 'customer001@example.test');
        IF v_failed THEN
            ROLLBACK;
            INSERT INTO test_results VALUES ('duplicate unique email', 'PASS', 'Rejected duplicate customer email');
        ELSE
            ROLLBACK;
            INSERT INTO test_results VALUES ('duplicate unique email', 'FAIL', 'Duplicate email was accepted');
        END IF;
    END;

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_failed = TRUE;
        SET v_failed = FALSE;
        START TRANSACTION;
        INSERT INTO products (category_id, sku, product_name, unit_price)
        VALUES (1, 'BAD-NEGATIVE-PRICE', 'Invalid Negative Price Product', -10.00);
        IF v_failed THEN
            ROLLBACK;
            INSERT INTO test_results VALUES ('negative product price', 'PASS', 'Rejected negative product price');
        ELSE
            ROLLBACK;
            INSERT INTO test_results VALUES ('negative product price', 'FAIL', 'Negative price was accepted');
        END IF;
    END;

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_failed = TRUE;
        SET v_failed = FALSE;
        START TRANSACTION;
        INSERT INTO order_items (order_id, product_id, warehouse_id, quantity, unit_price)
        VALUES (1, 1, 1, 0, 100.00);
        IF v_failed THEN
            ROLLBACK;
            INSERT INTO test_results VALUES ('invalid order item quantity', 'PASS', 'Rejected zero quantity order item');
        ELSE
            ROLLBACK;
            INSERT INTO test_results VALUES ('invalid order item quantity', 'FAIL', 'Zero quantity was accepted');
        END IF;
    END;

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_failed = TRUE;
        SET v_failed = FALSE;
        START TRANSACTION;
        INSERT INTO products (category_id, sku, product_name, unit_price)
        VALUES (1, 'SKU-0001', 'Duplicate SKU Product', 100.00);
        IF v_failed THEN
            ROLLBACK;
            INSERT INTO test_results VALUES ('duplicate product sku', 'PASS', 'Rejected duplicate product SKU');
        ELSE
            ROLLBACK;
            INSERT INTO test_results VALUES ('duplicate product sku', 'FAIL', 'Duplicate SKU was accepted');
        END IF;
    END;

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_failed = TRUE;
        SET v_failed = FALSE;
        START TRANSACTION;
        UPDATE inventory
        SET quantity_on_hand = -1
        WHERE warehouse_id = 1
          AND product_id = 1;
        IF v_failed THEN
            ROLLBACK;
            INSERT INTO test_results VALUES ('negative inventory update', 'PASS', 'Trigger rejected negative inventory');
        ELSE
            ROLLBACK;
            INSERT INTO test_results VALUES ('negative inventory update', 'FAIL', 'Negative inventory was accepted');
        END IF;
    END;

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_failed = TRUE;
        SET v_failed = FALSE;
        START TRANSACTION;
        INSERT INTO `returns` (order_id, return_status, reason)
        VALUES (1, 'APPROVED', 'Intentional invalid return item test');

        INSERT INTO return_items (return_id, order_item_id, quantity)
        SELECT LAST_INSERT_ID(), oi.order_item_id, 1
        FROM order_items oi
        WHERE oi.order_id <> 1
        LIMIT 1;

        IF v_failed THEN
            ROLLBACK;
            INSERT INTO test_results VALUES ('invalid returned order item', 'PASS', 'Trigger rejected return item from another order');
        ELSE
            ROLLBACK;
            INSERT INTO test_results VALUES ('invalid returned order item', 'FAIL', 'Return item from another order was accepted');
        END IF;
    END;

    BEGIN
        SET v_failed = FALSE;
        SELECT MIN(address_id) INTO v_address_id
        FROM customer_addresses
        WHERE customer_id = 1;

        SELECT COUNT(*) INTO v_before_count FROM orders;

        CALL place_order(
            1,
            v_address_id,
            v_address_id,
            1,
            JSON_ARRAY(JSON_OBJECT('product_id', 1, 'quantity', 999999)),
            'CARD',
            v_order_id,
            v_message
        );

        SELECT COUNT(*) INTO v_after_count FROM orders;

        IF v_order_id IS NULL AND v_before_count = v_after_count THEN
            INSERT INTO test_results VALUES ('insufficient inventory rollback', 'PASS', v_message);
        ELSE
            INSERT INTO test_results VALUES ('insufficient inventory rollback', 'FAIL', 'Failed order left an order row behind');
        END IF;
    END;

    BEGIN
        SELECT MIN(address_id) INTO v_address_id
        FROM customer_addresses
        WHERE customer_id = 1;

        CALL place_order(
            1,
            v_address_id,
            v_address_id,
            1,
            JSON_ARRAY(
                JSON_OBJECT('product_id', 1, 'quantity', 1),
                JSON_OBJECT('product_id', 2, 'quantity', 2)
            ),
            'UPI',
            v_order_id,
            v_message
        );

        IF v_order_id IS NOT NULL
           AND EXISTS (SELECT 1 FROM orders WHERE order_id = v_order_id AND order_total = fn_order_total(v_order_id))
           AND EXISTS (SELECT 1 FROM payments WHERE order_id = v_order_id AND payment_status = 'PENDING') THEN
            INSERT INTO test_results VALUES ('valid place_order transaction', 'PASS', v_message);
        ELSE
            INSERT INTO test_results VALUES ('valid place_order transaction', 'FAIL', COALESCE(v_message, 'Order was not created correctly'));
        END IF;
    END;

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_failed = TRUE;
        SET v_failed = FALSE;
        START TRANSACTION;
        INSERT INTO refunds (return_id, payment_id, refund_status, refund_amount)
        VALUES (999999, 1, 'PENDING', 100.00);
        IF v_failed THEN
            ROLLBACK;
            INSERT INTO test_results VALUES ('invalid refund foreign key', 'PASS', 'Rejected refund for missing return');
        ELSE
            ROLLBACK;
            INSERT INTO test_results VALUES ('invalid refund foreign key', 'FAIL', 'Invalid refund was accepted');
        END IF;
    END;

    SELECT * FROM test_results ORDER BY test_name;
END $$

DELIMITER ;

CALL run_database_integrity_tests();
DROP PROCEDURE run_database_integrity_tests;

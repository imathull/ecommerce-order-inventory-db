USE ecommerce_order_inventory_db;

DELIMITER $$

DROP PROCEDURE IF EXISTS seed_ecommerce_data $$
CREATE PROCEDURE seed_ecommerce_data()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE j INT DEFAULT 1;
    DECLARE v_customer_id INT;
    DECLARE v_address_id INT;
    DECLARE v_order_id BIGINT;
    DECLARE v_order_status VARCHAR(20);
    DECLARE v_order_date DATETIME;
    DECLARE v_item_count INT;
    DECLARE v_product_id INT;
    DECLARE v_warehouse_id INT;
    DECLARE v_quantity INT;
    DECLARE v_unit_price DECIMAL(10,2);
    DECLARE v_discount DECIMAL(5,2);
    DECLARE v_return_id BIGINT;
    DECLARE v_order_item_id BIGINT;
    DECLARE v_payment_id BIGINT;
    DECLARE v_refund_amount DECIMAL(12,2);

    START TRANSACTION;

    INSERT INTO categories (category_name, slug) VALUES
        ('Electronics', 'electronics'),
        ('Home Appliances', 'home-appliances'),
        ('Fashion', 'fashion'),
        ('Books', 'books'),
        ('Personal Care', 'personal-care'),
        ('Sports', 'sports');

    INSERT INTO categories (parent_category_id, category_name, slug) VALUES
        (1, 'Mobiles', 'mobiles'),
        (1, 'Laptops', 'laptops'),
        (2, 'Kitchen', 'kitchen'),
        (3, 'Footwear', 'footwear');

    WHILE i <= 120 DO
        INSERT INTO customers (first_name, last_name, email, phone, customer_status)
        VALUES (
            CONCAT('Customer', LPAD(i, 3, '0')),
            CONCAT('Test', LPAD(((i * 7) % 37) + 1, 2, '0')),
            CONCAT('customer', LPAD(i, 3, '0'), '@example.test'),
            CONCAT('+91-90000-', LPAD(i, 5, '0')),
            CASE WHEN i % 41 = 0 THEN 'INACTIVE' ELSE 'ACTIVE' END
        );

        INSERT INTO customer_addresses (
            customer_id, address_type, line1, city, state, postal_code, country, is_default
        )
        VALUES (
            i,
            'BOTH',
            CONCAT('Flat ', ((i * 13) % 240) + 1, ', Test Residency'),
            ELT((i % 6) + 1, 'Bengaluru', 'Hyderabad', 'Pune', 'Chennai', 'Mumbai', 'Delhi'),
            ELT((i % 6) + 1, 'Karnataka', 'Telangana', 'Maharashtra', 'Tamil Nadu', 'Maharashtra', 'Delhi'),
            CONCAT('56', LPAD(i, 4, '0')),
            'India',
            TRUE
        );

        IF i % 3 = 0 THEN
            INSERT INTO customer_addresses (
                customer_id, address_type, line1, city, state, postal_code, country, is_default
            )
            VALUES (
                i,
                'SHIPPING',
                CONCAT('House ', ((i * 17) % 300) + 1, ', Sample Layout'),
                ELT((i % 5) + 1, 'Jaipur', 'Kolkata', 'Ahmedabad', 'Kochi', 'Lucknow'),
                ELT((i % 5) + 1, 'Rajasthan', 'West Bengal', 'Gujarat', 'Kerala', 'Uttar Pradesh'),
                CONCAT('40', LPAD(i, 4, '0')),
                'India',
                FALSE
            );
        END IF;

        SET i = i + 1;
    END WHILE;

    INSERT INTO suppliers (supplier_name, contact_email, phone, city, supplier_status) VALUES
        ('Northstar Electronics Supply', 'northstar@example.test', '+91-88000-00001', 'Delhi', 'ACTIVE'),
        ('BrightByte Distributors', 'brightbyte@example.test', '+91-88000-00002', 'Bengaluru', 'ACTIVE'),
        ('UrbanStep Wholesale', 'urbanstep@example.test', '+91-88000-00003', 'Mumbai', 'ACTIVE'),
        ('KitchenKart B2B', 'kitchenkart@example.test', '+91-88000-00004', 'Pune', 'ACTIVE'),
        ('PageTurner Publishing Supply', 'pageturner@example.test', '+91-88000-00005', 'Kolkata', 'ACTIVE'),
        ('FitZone Sports Trade', 'fitzone@example.test', '+91-88000-00006', 'Chennai', 'ACTIVE'),
        ('CareWell Personal Products', 'carewell@example.test', '+91-88000-00007', 'Hyderabad', 'ACTIVE'),
        ('Apex Laptop Parts', 'apexlaptop@example.test', '+91-88000-00008', 'Noida', 'ACTIVE'),
        ('HomeEase Appliances', 'homeease@example.test', '+91-88000-00009', 'Ahmedabad', 'ACTIVE'),
        ('SmartGear Imports', 'smartgear@example.test', '+91-88000-00010', 'Kochi', 'ACTIVE'),
        ('MetroStyle Apparel', 'metrostyle@example.test', '+91-88000-00011', 'Surat', 'ACTIVE'),
        ('ValueSource Trading', 'valuesource@example.test', '+91-88000-00012', 'Indore', 'ACTIVE');

    INSERT INTO warehouses (warehouse_name, city, state, postal_code) VALUES
        ('BLR Fulfilment Center', 'Bengaluru', 'Karnataka', '560100'),
        ('NCR Fulfilment Center', 'Gurugram', 'Haryana', '122001'),
        ('MUM Distribution Hub', 'Mumbai', 'Maharashtra', '400072'),
        ('HYD Fulfilment Center', 'Hyderabad', 'Telangana', '500081');

    SET i = 1;
    WHILE i <= 60 DO
        INSERT INTO products (category_id, sku, product_name, description, unit_price, product_status)
        VALUES (
            ((i - 1) % 10) + 1,
            CONCAT('SKU-', LPAD(i, 4, '0')),
            CONCAT(
                ELT(((i - 1) % 10) + 1, 'Smartphone', 'Laptop', 'Mixer Grinder', 'Running Shoe', 'Wireless Earbud', 'Backpack', 'Novel', 'Face Wash', 'Yoga Mat', 'Coffee Maker'),
                ' Model ',
                LPAD(i, 2, '0')
            ),
            CONCAT('Synthetic catalog item ', i, ' used for database testing.'),
            ROUND(199 + ((i * 137) % 45000) / 10, 2),
            CASE WHEN i % 53 = 0 THEN 'INACTIVE' ELSE 'ACTIVE' END
        );
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= 60 DO
        INSERT INTO supplier_products (
            supplier_id, product_id, supplier_sku, lead_time_days, last_purchase_price, is_primary_supplier
        )
        VALUES
            (((i * 3) % 12) + 1, i, CONCAT('SUP-', LPAD(((i * 3) % 12) + 1, 2, '0'), '-', LPAD(i, 4, '0')), ((i * 2) % 14) + 3, ROUND((SELECT unit_price FROM products WHERE product_id = i) * 0.62, 2), TRUE),
            (((i * 3 + 1) % 12) + 1, i, CONCAT('ALT-', LPAD(((i * 3 + 1) % 12) + 1, 2, '0'), '-', LPAD(i, 4, '0')), ((i * 3) % 21) + 5, ROUND((SELECT unit_price FROM products WHERE product_id = i) * 0.68, 2), FALSE);
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= 4 DO
        SET j = 1;
        WHILE j <= 60 DO
            INSERT INTO inventory (warehouse_id, product_id, quantity_on_hand, reorder_level, safety_stock)
            VALUES (i, j, 360 + ((i * 37 + j * 19) % 140), 25 + (j % 10), 10 + (j % 5));
            INSERT INTO inventory_transactions (
                warehouse_id, product_id, transaction_type, quantity_delta, reference_type, reference_id, notes
            )
            VALUES (i, j, 'PURCHASE', 360 + ((i * 37 + j * 19) % 140), 'SUPPLIER_RECEIPT', NULL, 'Initial warehouse stocking');
            SET j = j + 1;
        END WHILE;
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= 550 DO
        SET v_customer_id = ((i * 17) % 120) + 1;
        SELECT MIN(address_id) INTO v_address_id
        FROM customer_addresses
        WHERE customer_id = v_customer_id;

        SET v_order_status = CASE
            WHEN i % 23 = 0 THEN 'CANCELLED'
            WHEN i % 11 = 0 THEN 'PENDING'
            WHEN i % 4 = 0 THEN 'DELIVERED'
            WHEN i % 5 = 0 THEN 'SHIPPED'
            ELSE 'PAID'
        END;
        SET v_order_date = DATE_ADD('2025-03-09', INTERVAL i DAY);

        INSERT INTO orders (
            customer_id, shipping_address_id, billing_address_id, order_date, order_status, order_total
        )
        VALUES (v_customer_id, v_address_id, v_address_id, v_order_date, v_order_status, 0);

        SET v_order_id = LAST_INSERT_ID();
        SET v_item_count = 1 + (i % 4);
        SET j = 1;

        WHILE j <= v_item_count DO
            SET v_product_id = ((i * 7 + j * 11) % 60) + 1;
            SET v_warehouse_id = ((i + j) % 4) + 1;
            SET v_quantity = 1 + ((i + j) % 3);
            SELECT unit_price INTO v_unit_price FROM products WHERE product_id = v_product_id;
            SET v_discount = CASE WHEN (i + j) % 10 = 0 THEN 5.00 ELSE 0.00 END;

            INSERT INTO order_items (
                order_id, product_id, warehouse_id, quantity, unit_price, discount_percent
            )
            VALUES (v_order_id, v_product_id, v_warehouse_id, v_quantity, v_unit_price, v_discount);

            SET j = j + 1;
        END WHILE;

        UPDATE orders o
        SET order_total = (
            SELECT ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100)), 2)
            FROM order_items oi
            WHERE oi.order_id = o.order_id
        )
        WHERE o.order_id = v_order_id;

        IF v_order_status <> 'CANCELLED' THEN
            UPDATE inventory inv
            JOIN order_items oi
              ON oi.warehouse_id = inv.warehouse_id
             AND oi.product_id = inv.product_id
            SET inv.quantity_on_hand = inv.quantity_on_hand - oi.quantity
            WHERE oi.order_id = v_order_id;

            INSERT INTO inventory_transactions (
                warehouse_id, product_id, transaction_type, quantity_delta, reference_type, reference_id, notes
            )
            SELECT warehouse_id, product_id, 'SALE', -quantity, 'ORDER', v_order_id, 'Seed order stock deduction'
            FROM order_items
            WHERE order_id = v_order_id;
        END IF;

        INSERT INTO payments (
            order_id, payment_method, payment_status, amount, transaction_reference, paid_at
        )
        SELECT
            v_order_id,
            ELT((i % 5) + 1, 'CARD', 'UPI', 'NET_BANKING', 'WALLET', 'COD'),
            CASE
                WHEN v_order_status = 'CANCELLED' THEN 'FAILED'
                WHEN v_order_status = 'PENDING' THEN 'PENDING'
                ELSE 'COMPLETED'
            END,
            CASE WHEN v_order_status = 'CANCELLED' THEN 0 ELSE order_total END,
            CASE
                WHEN v_order_status = 'PENDING' THEN NULL
                ELSE CONCAT('PAY-', LPAD(v_order_id, 8, '0'))
            END,
            CASE
                WHEN v_order_status IN ('PAID', 'SHIPPED', 'DELIVERED') THEN DATE_ADD(v_order_date, INTERVAL 5 MINUTE)
                ELSE NULL
            END
        FROM orders
        WHERE order_id = v_order_id;

        IF v_order_status IN ('SHIPPED', 'DELIVERED') THEN
            INSERT INTO shipments (
                order_id, carrier, tracking_number, shipment_status, shipped_at, estimated_delivery_at, delivered_at
            )
            VALUES (
                v_order_id,
                ELT((i % 4) + 1, 'BlueDart', 'Delhivery', 'Ecom Express', 'DTDC'),
                CONCAT('TRK', LPAD(v_order_id, 10, '0')),
                CASE WHEN v_order_status = 'DELIVERED' THEN 'DELIVERED' ELSE 'IN_TRANSIT' END,
                DATE_ADD(v_order_date, INTERVAL 1 DAY),
                DATE_ADD(v_order_date, INTERVAL 5 DAY),
                CASE WHEN v_order_status = 'DELIVERED' THEN DATE_ADD(v_order_date, INTERVAL 4 DAY) ELSE NULL END
            );
        END IF;

        IF v_order_status = 'DELIVERED' AND i % 6 = 0 THEN
            SELECT oi.order_item_id, p.payment_id,
                   ROUND(oi.unit_price * (1 - oi.discount_percent / 100), 2)
            INTO v_order_item_id, v_payment_id, v_refund_amount
            FROM order_items oi
            JOIN payments p ON p.order_id = oi.order_id
            WHERE oi.order_id = v_order_id
            ORDER BY oi.order_item_id
            LIMIT 1;

            INSERT INTO `returns` (order_id, return_date, return_status, reason)
            VALUES (v_order_id, DATE_ADD(v_order_date, INTERVAL 7 DAY), 'REFUNDED', 'Customer changed preference');

            SET v_return_id = LAST_INSERT_ID();

            INSERT INTO return_items (return_id, order_item_id, quantity, item_condition)
            VALUES (v_return_id, v_order_item_id, 1, CASE WHEN i % 12 = 0 THEN 'OPENED' ELSE 'UNOPENED' END);

            UPDATE inventory inv
            JOIN order_items oi
              ON oi.warehouse_id = inv.warehouse_id
             AND oi.product_id = inv.product_id
            SET inv.quantity_on_hand = inv.quantity_on_hand + 1
            WHERE oi.order_item_id = v_order_item_id;

            INSERT INTO inventory_transactions (
                warehouse_id, product_id, transaction_type, quantity_delta, reference_type, reference_id, notes
            )
            SELECT warehouse_id, product_id, 'RETURN', 1, 'RETURN', v_return_id, 'Seed return stock addition'
            FROM order_items
            WHERE order_item_id = v_order_item_id;

            INSERT INTO refunds (
                return_id, payment_id, refund_status, refund_amount, refund_reference, refunded_at
            )
            VALUES (
                v_return_id,
                v_payment_id,
                'COMPLETED',
                v_refund_amount,
                CONCAT('REF-', LPAD(v_return_id, 8, '0')),
                DATE_ADD(v_order_date, INTERVAL 8 DAY)
            );

            UPDATE orders SET order_status = 'RETURNED' WHERE order_id = v_order_id;
        END IF;

        SET i = i + 1;
    END WHILE;

    COMMIT;
END $$

DELIMITER ;

CALL seed_ecommerce_data();
DROP PROCEDURE seed_ecommerce_data;

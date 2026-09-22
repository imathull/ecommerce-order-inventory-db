USE ecommerce_order_inventory_db;

ALTER TABLE customer_addresses
    ADD CONSTRAINT fk_customer_addresses_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE categories
    ADD CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_category_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL;

ALTER TABLE products
    ADD CONSTRAINT fk_products_category
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE supplier_products
    ADD CONSTRAINT fk_supplier_products_supplier
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    ADD CONSTRAINT fk_supplier_products_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE inventory
    ADD CONSTRAINT fk_inventory_warehouse
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    ADD CONSTRAINT fk_inventory_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE inventory_transactions
    ADD CONSTRAINT fk_inventory_transactions_inventory
    FOREIGN KEY (warehouse_id, product_id) REFERENCES inventory(warehouse_id, product_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE orders
    ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    ADD CONSTRAINT fk_orders_shipping_address
    FOREIGN KEY (customer_id, shipping_address_id) REFERENCES customer_addresses(customer_id, address_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    ADD CONSTRAINT fk_orders_billing_address
    FOREIGN KEY (customer_id, billing_address_id) REFERENCES customer_addresses(customer_id, address_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE order_items
    ADD CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    ADD CONSTRAINT fk_order_items_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    ADD CONSTRAINT fk_order_items_inventory
    FOREIGN KEY (warehouse_id, product_id) REFERENCES inventory(warehouse_id, product_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE payments
    ADD CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE shipments
    ADD CONSTRAINT fk_shipments_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE `returns`
    ADD CONSTRAINT fk_returns_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE return_items
    ADD CONSTRAINT fk_return_items_return
    FOREIGN KEY (return_id) REFERENCES `returns`(return_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    ADD CONSTRAINT fk_return_items_order_item
    FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE refunds
    ADD CONSTRAINT fk_refunds_return
    FOREIGN KEY (return_id) REFERENCES `returns`(return_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    ADD CONSTRAINT fk_refunds_payment
    FOREIGN KEY (payment_id) REFERENCES payments(payment_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

-- Triggers to enforce that a category cannot be its own parent.
-- MySQL 8.4 disallows CHECK constraints that reference an AUTO_INCREMENT column
-- (category_id). Use triggers to enforce the rule instead, preserving the
-- parent-child hierarchy and keeping foreign keys intact.

DELIMITER $$
CREATE TRIGGER trg_categories_no_self_parent_before_insert
BEFORE INSERT ON categories
FOR EACH ROW
BEGIN
    IF NEW.parent_category_id IS NOT NULL AND NEW.parent_category_id = NEW.category_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'chk_categories_not_self_parent: category cannot be its own parent';
    END IF;
END$$
CREATE TRIGGER trg_categories_no_self_parent_after_insert
AFTER INSERT ON categories
FOR EACH ROW
BEGIN
    IF NEW.parent_category_id IS NOT NULL AND NEW.parent_category_id = NEW.category_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'chk_categories_not_self_parent: category cannot be its own parent';
    END IF;
END$$

CREATE TRIGGER trg_categories_no_self_parent_before_update
BEFORE UPDATE ON categories
FOR EACH ROW
BEGIN
    IF NEW.parent_category_id IS NOT NULL AND NEW.parent_category_id = NEW.category_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'chk_categories_not_self_parent: category cannot be its own parent';
    END IF;
END$$
DELIMITER ;

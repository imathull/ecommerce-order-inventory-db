USE ecommerce_order_inventory_db;

DELIMITER $$

DROP TRIGGER IF EXISTS trg_inventory_before_insert $$
CREATE TRIGGER trg_inventory_before_insert
BEFORE INSERT ON inventory
FOR EACH ROW
BEGIN
    IF NEW.quantity_on_hand < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory quantity cannot be negative';
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_inventory_before_update $$
CREATE TRIGGER trg_inventory_before_update
BEFORE UPDATE ON inventory
FOR EACH ROW
BEGIN
    IF NEW.quantity_on_hand < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory quantity cannot be negative';
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_return_items_before_insert $$
CREATE TRIGGER trg_return_items_before_insert
BEFORE INSERT ON return_items
FOR EACH ROW
BEGIN
    DECLARE v_return_order_id BIGINT;
    DECLARE v_item_order_id BIGINT;
    DECLARE v_purchased_qty INT;
    DECLARE v_already_returned_qty INT;

    SELECT order_id
    INTO v_return_order_id
    FROM `returns`
    WHERE return_id = NEW.return_id;

    SELECT order_id, quantity
    INTO v_item_order_id, v_purchased_qty
    FROM order_items
    WHERE order_item_id = NEW.order_item_id;

    IF v_return_order_id IS NULL OR v_item_order_id IS NULL OR v_return_order_id <> v_item_order_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Returned item must belong to the returned order';
    END IF;

    SELECT COALESCE(SUM(ri.quantity), 0)
    INTO v_already_returned_qty
    FROM return_items ri
    JOIN `returns` r ON r.return_id = ri.return_id
    WHERE ri.order_item_id = NEW.order_item_id
      AND r.return_status <> 'REJECTED';

    IF NEW.quantity + v_already_returned_qty > v_purchased_qty THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Returned quantity cannot exceed purchased quantity';
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_refunds_after_update $$
CREATE TRIGGER trg_refunds_after_update
AFTER UPDATE ON refunds
FOR EACH ROW
BEGIN
    IF NEW.refund_status = 'COMPLETED' AND OLD.refund_status <> 'COMPLETED' THEN
        UPDATE `returns`
        SET return_status = 'REFUNDED'
        WHERE return_id = NEW.return_id;
    END IF;
END $$

DELIMITER ;

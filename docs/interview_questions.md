# Interview Questions and Answers

## 1. Why did you choose MySQL?

MySQL 8.0 is widely used for backend applications, supports transactions with InnoDB, foreign keys, check constraints, CTEs, window functions, JSON input, views, stored procedures, functions, triggers, and `EXPLAIN`. These features match the project goal of operational database engineering.

## 2. Why did you normalize the database?

Normalization reduces duplicate and inconsistent data. For example, customer addresses are not repeated inside every order; orders reference address rows. Products and suppliers are separated because one supplier can supply many products and one product can have multiple suppliers.

## 3. Is the schema in 3NF?

It is approximately 3NF for practical e-commerce use. Tables store facts about their own entity, and many-to-many relationships are separated into junction tables like `supplier_products`. Stored totals such as `orders.order_total` are intentional operational snapshots controlled by procedures.

## 4. Explain the ER diagram.

Customers place orders. Orders contain order items. Products belong to categories and are stocked in warehouses through inventory rows. Suppliers are linked to products through `supplier_products`. Orders can have payments, shipments, returns, return items, and refunds.

## 5. Why use surrogate primary keys?

Surrogate keys such as `customer_id` and `order_id` are compact, stable, and easy for applications to reference. Natural values like email or SKU can change, so they are unique keys but not primary keys.

## 6. Why does `inventory` use a composite primary key?

One inventory row represents one product in one warehouse. `(warehouse_id, product_id)` naturally identifies that row, so a composite key prevents duplicate stock rows for the same product and warehouse.

## 7. What are foreign keys used for?

Foreign keys prevent invalid references. For example, an `order_item` cannot refer to a missing order or product, and a refund cannot exist without a valid return and payment.

## 8. How do you ensure an order address belongs to the customer?

`orders` has composite foreign keys from `(customer_id, shipping_address_id)` and `(customer_id, billing_address_id)` to `customer_addresses(customer_id, address_id)`.

## 9. Explain the `place_order()` transaction.

It validates customer, addresses, warehouse, products, and quantities. Then it starts a transaction, inserts the order and items, deducts inventory, records inventory transactions, calculates order total, creates a payment, and commits. If any step fails, it rolls back.

## 10. Why are transactions important here?

Order placement changes multiple tables. Without a transaction, the database could create an order but fail to deduct inventory or create payment. A transaction keeps all related changes atomic.

## 11. What happens if inventory is insufficient?

The inventory update checks `quantity_on_hand >= requested_quantity`. If not every item row is updated, the procedure signals an error, rolls back, and returns an error message.

## 12. How would you handle concurrent orders for the same product?

The conditional inventory update is atomic in InnoDB. For very high concurrency, I would add inventory reservation rows or use explicit `SELECT ... FOR UPDATE` locking around the relevant inventory rows.

## 13. Why use a stored procedure?

Order placement and returns require multi-step validations and writes. A stored procedure keeps these rules close to the data and ensures consistent behavior across applications.

## 14. Why use JSON input for `place_order()`?

An order can contain multiple products. JSON lets the caller pass an array of product and quantity pairs in one call, and MySQL 8 can parse it with `JSON_TABLE()`.

## 15. Why use triggers?

Triggers enforce critical rules even if someone bypasses stored procedures. This project uses triggers to prevent negative inventory and invalid return items.

## 16. What are the risks of excessive triggers?

Too many triggers can hide business logic, make debugging harder, create unexpected side effects, and hurt write performance. That is why this project uses only a few integrity-focused triggers.

## 17. Why keep `inventory_transactions`?

`inventory` stores the current stock. `inventory_transactions` stores the movement history, which is needed to audit purchases, sales, returns, and adjustments.

## 18. Why store `unit_price` in `order_items`?

It is a historical price snapshot. If the catalog price changes later, old orders should still show the price charged at purchase time.

## 19. Why store `order_total` if it can be calculated?

Operational systems frequently need the total for payments, invoices, and support lookups. The project also includes `fn_order_total()` to verify or recalculate it from line items.

## 20. Explain a CTE used in this project.

The advanced queries use CTEs for monthly revenue and inventory rollups. A CTE makes intermediate results readable and reusable inside one query.

## 21. Where is a recursive CTE used?

The category tree query uses a recursive CTE to walk parent and child categories and produce a full category path.

## 22. Explain window functions used here.

`ROW_NUMBER()` finds the most recent order per customer. `RANK()` and `DENSE_RANK()` rank products within categories. `LAG()` compares current and previous month revenue. Running totals use `SUM() OVER`.

## 23. Difference between `RANK()` and `ROW_NUMBER()`.

`ROW_NUMBER()` always gives unique sequence numbers. `RANK()` gives the same rank to ties and skips the next rank values after ties.

## 24. Difference between `RANK()` and `DENSE_RANK()`.

Both assign the same rank to ties. `RANK()` leaves gaps after ties; `DENSE_RANK()` does not.

## 25. Why use indexes?

Indexes help MySQL find rows faster for common filters, joins, sorting, and grouping. They are important for order history, payment status, shipment queues, and product inventory lookups.

## 26. How did you decide which columns to index?

Indexes were chosen from actual query patterns: customer order lookups, order status queues, product sales joins, payment exception searches, shipment status filters, and inventory lookups.

## 27. Why not index every column?

Indexes consume storage and slow down inserts, updates, and deletes. A database should index columns that support important queries, joins, constraints, and filters.

## 28. How do you optimize a slow query?

Check the query plan with `EXPLAIN`, verify indexes, reduce unnecessary rows early, avoid selecting unused columns, check join order, update statistics with `ANALYZE TABLE`, and consider rewriting subqueries or adding targeted indexes.

## 29. What does `EXPLAIN` show?

`EXPLAIN` shows how MySQL plans to access tables, possible indexes, chosen indexes, join type, estimated rows, and extra operations like temporary tables or filesort.

## 30. How would you prevent duplicate orders?

In production I would add an idempotency key from the checkout request, store it with a unique constraint, and return the existing order if the same request is retried.

## 31. How are returns validated?

`process_return()` verifies the order was delivered, the return window is valid, the order item belongs to the order, the quantity does not exceed what was purchased, and a completed payment exists.

## 32. Why are refunds separate from returns?

A return is the business approval workflow. A refund is the payment workflow. They have different statuses, timestamps, and external references.

## 33. How would you scale this database for millions of orders?

Use better hardware first, then add covering indexes, archive old orders, partition large tables by date, separate read replicas for reporting, and consider service boundaries for payments or inventory.

## 34. What would you change for high-volume inventory?

I would add reservation tables, idempotency keys, event logs, stricter locking patterns, and possibly split inventory by fulfilment region.

## 35. What is the most interview-worthy part of this project?

The strongest part is the transaction design around `place_order()` and `process_return()`, because it shows practical understanding of integrity, rollback, inventory, and real backend workflows.

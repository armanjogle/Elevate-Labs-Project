CREATE DATABASE inventory_warehouse;
USE inventory_warehouse;

CREATE TABLE units (
  unit_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  abbreviation VARCHAR(10) NOT NULL,
  UNIQUE KEY (abbreviation)
);

CREATE TABLE categories (
  category_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  UNIQUE KEY (name)
);

CREATE TABLE suppliers (
  supplier_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  phone VARCHAR(30),
  email VARCHAR(150),
  address TEXT
);

CREATE TABLE warehouses (
  warehouse_id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(20) NOT NULL,
  name VARCHAR(150) NOT NULL,
  address TEXT,
  UNIQUE KEY (code)
);

CREATE TABLE products (
  product_id INT AUTO_INCREMENT PRIMARY KEY,
  sku VARCHAR(30) NOT NULL,
  name VARCHAR(150) NOT NULL,
  category_id INT,
  unit_id INT NOT NULL,
  reorder_point INT DEFAULT 0 CHECK (reorder_point >= 0),
  reorder_qty   INT DEFAULT 0 CHECK (reorder_qty   >= 0),
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories(category_id),
  CONSTRAINT fk_products_unit     FOREIGN KEY (unit_id)     REFERENCES units(unit_id),
  UNIQUE KEY (sku)
);

CREATE TABLE product_suppliers (
  product_id INT NOT NULL,
  supplier_id INT NOT NULL,
  supplier_sku VARCHAR(50),
  lead_time_days INT DEFAULT 0,
  last_unit_cost DECIMAL(10,2) DEFAULT 0,
  PRIMARY KEY (product_id, supplier_id),
  CONSTRAINT fk_ps_product  FOREIGN KEY (product_id)  REFERENCES products(product_id),
  CONSTRAINT fk_ps_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

CREATE TABLE stock (
  product_id INT NOT NULL,
  warehouse_id INT NOT NULL,
  on_hand INT NOT NULL DEFAULT 0 CHECK (on_hand >= 0),
  reserved INT NOT NULL DEFAULT 0 CHECK (reserved >= 0),
  available INT AS (on_hand - reserved) STORED,
  PRIMARY KEY (product_id, warehouse_id),
  CONSTRAINT fk_stock_product   FOREIGN KEY (product_id)   REFERENCES products(product_id),
  CONSTRAINT fk_stock_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

CREATE TABLE purchase_orders (
  po_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  supplier_id INT NOT NULL,
  warehouse_id INT NOT NULL,
  status ENUM('DRAFT','PLACED','RECEIVED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  ordered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  expected_at DATE NULL,
  notes TEXT,
  CONSTRAINT fk_po_supplier  FOREIGN KEY (supplier_id)  REFERENCES suppliers(supplier_id),
  CONSTRAINT fk_po_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

CREATE TABLE purchase_order_items (
  po_item_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  po_id BIGINT NOT NULL,
  product_id INT NOT NULL,
  ordered_qty INT NOT NULL CHECK (ordered_qty > 0),
  unit_cost DECIMAL(10,2) NOT NULL CHECK (unit_cost >= 0),
  CONSTRAINT fk_poi_po      FOREIGN KEY (po_id)      REFERENCES purchase_orders(po_id) ON DELETE CASCADE,
  CONSTRAINT fk_poi_product FOREIGN KEY (product_id) REFERENCES products(product_id),
  UNIQUE KEY uq_poi (po_id, product_id)
);

CREATE TABLE receipts (
  receipt_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  po_id BIGINT NULL,
  warehouse_id INT NOT NULL,
  received_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reference VARCHAR(50),
  notes TEXT,
  CONSTRAINT fk_receipts_po        FOREIGN KEY (po_id)        REFERENCES purchase_orders(po_id),
  CONSTRAINT fk_receipts_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

CREATE TABLE receipt_items (
  receipt_item_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  receipt_id BIGINT NOT NULL,
  product_id INT NOT NULL,
  qty INT NOT NULL CHECK (qty > 0),
  unit_cost DECIMAL(10,2) NOT NULL CHECK (unit_cost >= 0),
  batch_no VARCHAR(50),
  expiry_date DATE,
  CONSTRAINT fk_ri_receipt FOREIGN KEY (receipt_id) REFERENCES receipts(receipt_id) ON DELETE CASCADE,
  CONSTRAINT fk_ri_product FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE customers (
  customer_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  phone VARCHAR(30),
  email VARCHAR(150),
  address TEXT
);

CREATE TABLE sales_orders (
  so_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT,
  warehouse_id INT NOT NULL,
  status ENUM('DRAFT','CONFIRMED','SHIPPED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  ordered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,
  CONSTRAINT fk_so_customer  FOREIGN KEY (customer_id)  REFERENCES customers(customer_id),
  CONSTRAINT fk_so_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

CREATE TABLE sales_order_items (
  so_item_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  so_id BIGINT NOT NULL,
  product_id INT NOT NULL,
  ordered_qty INT NOT NULL CHECK (ordered_qty > 0),
  unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
  CONSTRAINT fk_soi_so      FOREIGN KEY (so_id)      REFERENCES sales_orders(so_id) ON DELETE CASCADE,
  CONSTRAINT fk_soi_product FOREIGN KEY (product_id) REFERENCES products(product_id),
  UNIQUE KEY uq_soi (so_id, product_id)
);

CREATE TABLE shipments (
  shipment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  so_id BIGINT,
  warehouse_id INT NOT NULL,
  shipped_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reference VARCHAR(50),
  notes TEXT,
  CONSTRAINT fk_ship_so FOREIGN KEY (so_id) REFERENCES sales_orders(so_id),
  CONSTRAINT fk_ship_wh FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

CREATE TABLE shipment_items (
  shipment_item_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  shipment_id BIGINT NOT NULL,
  product_id INT NOT NULL,
  qty INT NOT NULL CHECK (qty > 0),
  CONSTRAINT fk_shi_ship   FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id) ON DELETE CASCADE,
  CONSTRAINT fk_shi_product FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE stock_movements (
  movement_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL,
  warehouse_id INT NOT NULL,
  qty_change INT NOT NULL,
  move_type ENUM('RECEIPT','SHIPMENT','ADJUSTMENT','TRANSFER_IN','TRANSFER_OUT') NOT NULL,
  ref_table VARCHAR(30),
  ref_id BIGINT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_sm_product FOREIGN KEY (product_id) REFERENCES products(product_id),
  CONSTRAINT fk_sm_wh      FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
  INDEX idx_sm_prod_wh_time (product_id, warehouse_id, created_at)
);

CREATE TABLE transfers (
  transfer_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  from_warehouse_id INT NOT NULL,
  to_warehouse_id INT NOT NULL,
  status ENUM('DRAFT','POSTED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,
  CONSTRAINT fk_tr_from FOREIGN KEY (from_warehouse_id) REFERENCES warehouses(warehouse_id),
  CONSTRAINT fk_tr_to   FOREIGN KEY (to_warehouse_id)   REFERENCES warehouses(warehouse_id),
  CHECK (from_warehouse_id <> to_warehouse_id)
);

CREATE TABLE transfer_items (
  transfer_item_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  transfer_id BIGINT NOT NULL,
  product_id INT NOT NULL,
  qty INT NOT NULL CHECK (qty > 0),
  CONSTRAINT fk_ti_transfer FOREIGN KEY (transfer_id) REFERENCES transfers(transfer_id) ON DELETE CASCADE,
  CONSTRAINT fk_ti_product  FOREIGN KEY (product_id)  REFERENCES products(product_id)
);

CREATE TABLE adjustments (
  adjustment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  warehouse_id INT NOT NULL,
  reason VARCHAR(200),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_adj_wh FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

CREATE TABLE adjustment_items (
  adjustment_item_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  adjustment_id BIGINT NOT NULL,
  product_id INT NOT NULL,
  qty_change INT NOT NULL, -- can be + or -
  notes VARCHAR(200),
  CONSTRAINT fk_adji_adj  FOREIGN KEY (adjustment_id) REFERENCES adjustments(adjustment_id) ON DELETE CASCADE,
  CONSTRAINT fk_adji_prod FOREIGN KEY (product_id)    REFERENCES products(product_id)
);

CREATE TABLE reorder_alerts (
  alert_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL,
  warehouse_id INT NOT NULL,
  on_hand_at_alert INT NOT NULL,
  reorder_point INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  CONSTRAINT fk_alert_prod FOREIGN KEY (product_id) REFERENCES products(product_id),
  CONSTRAINT fk_alert_wh   FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
  INDEX idx_alert_open (product_id, warehouse_id, resolved_at)
);

INSERT INTO units (name, abbreviation) VALUES
 ('Piece','pc'), ('Box','box');

INSERT INTO categories (name) VALUES
 ('Electronics'), ('Furniture');

INSERT INTO warehouses (code, name, address) VALUES
 ('BLR','Bengaluru WH','Peenya'), ('MUM','Mumbai WH','Bhiwandi');

INSERT INTO suppliers (name, phone, email) VALUES
 ('Acme Components','9999999999','acme@example.com'),
 ('Futura Traders','8888888888','futura@example.com');

INSERT INTO products (sku, name, category_id, unit_id, reorder_point, reorder_qty)
VALUES
 ('TV42','42" LED TV', 1, 1, 10, 20),
 ('CHAIR-STD','Standard Chair', 2, 1, 50, 100),
 ('TV55','55" Smart TV', 1, 1, 5, 10);

INSERT INTO product_suppliers (product_id, supplier_id, supplier_sku, lead_time_days, last_unit_cost)
VALUES
 (1,1,'AC-LED42',7,18000.00),
 (3,1,'AC-LED55',10,35000.00),
 (2,2,'FT-CH-STD',5,700.00);

DELIMITER //

CREATE PROCEDURE check_and_create_reorder_alert(IN p_product_id INT, IN p_warehouse_id INT)
BEGIN
  DECLARE v_on_hand INT DEFAULT 0;
  DECLARE v_reorder_point INT DEFAULT 0;

  SELECT on_hand INTO v_on_hand
  FROM stock
  WHERE product_id = p_product_id AND warehouse_id = p_warehouse_id;

  IF v_on_hand IS NULL THEN SET v_on_hand = 0; END IF;

  SELECT reorder_point INTO v_reorder_point
  FROM products
  WHERE product_id = p_product_id;

  IF v_on_hand < v_reorder_point THEN
    IF (SELECT COUNT(*)
        FROM reorder_alerts
        WHERE product_id = p_product_id
          AND warehouse_id = p_warehouse_id
          AND resolved_at IS NULL) = 0 THEN
      INSERT INTO reorder_alerts (product_id, warehouse_id, on_hand_at_alert, reorder_point)
      VALUES (p_product_id, p_warehouse_id, v_on_hand, v_reorder_point);
    END IF;
  ELSE
    UPDATE reorder_alerts
    SET resolved_at = CURRENT_TIMESTAMP
    WHERE product_id = p_product_id
      AND warehouse_id = p_warehouse_id
      AND resolved_at IS NULL;
  END IF;
END//

CREATE PROCEDURE transfer_stock(
  IN p_product_id INT,
  IN p_from_wh INT,
  IN p_to_wh INT,
  IN p_qty INT,
  IN p_notes TEXT
)
BEGIN
  DECLARE v_on_hand INT;
  DECLARE v_transfer_id BIGINT;

  IF p_from_wh = p_to_wh THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'From and To warehouse must differ';
  END IF;

  START TRANSACTION;

  SELECT on_hand INTO v_on_hand
  FROM stock
  WHERE product_id = p_product_id AND warehouse_id = p_from_wh
  FOR UPDATE;

  IF v_on_hand IS NULL OR v_on_hand < p_qty THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock to transfer';
  END IF;

  INSERT INTO transfers (from_warehouse_id, to_warehouse_id, status, notes)
  VALUES (p_from_wh, p_to_wh, 'POSTED', p_notes);
  SET v_transfer_id = LAST_INSERT_ID();

  INSERT INTO transfer_items (transfer_id, product_id, qty)
  VALUES (v_transfer_id, p_product_id, p_qty);

  INSERT INTO stock (product_id, warehouse_id, on_hand, reserved)
  VALUES (p_product_id, p_from_wh, 0, 0)
  ON DUPLICATE KEY UPDATE on_hand = on_hand - p_qty;

  INSERT INTO stock_movements (product_id, warehouse_id, qty_change, move_type, ref_table, ref_id)
  VALUES (p_product_id, p_from_wh, -p_qty, 'TRANSFER_OUT', 'transfers', v_transfer_id);

  INSERT INTO stock (product_id, warehouse_id, on_hand, reserved)
  VALUES (p_product_id, p_to_wh, p_qty, 0)
  ON DUPLICATE KEY UPDATE on_hand = on_hand + p_qty;

  INSERT INTO stock_movements (product_id, warehouse_id, qty_change, move_type, ref_table, ref_id)
  VALUES (p_product_id, p_to_wh, p_qty, 'TRANSFER_IN', 'transfers', v_transfer_id);

  CALL check_and_create_reorder_alert(p_product_id, p_from_wh);
  CALL check_and_create_reorder_alert(p_product_id, p_to_wh);

  COMMIT;
END//

DELIMITER ;

DELIMITER //

CREATE TRIGGER trg_receipt_items_ai AFTER INSERT ON receipt_items
FOR EACH ROW
BEGIN
  DECLARE v_wh INT;
  DECLARE v_po BIGINT;
  DECLARE v_supplier INT;

  SELECT warehouse_id, po_id INTO v_wh, v_po
  FROM receipts
  WHERE receipt_id = NEW.receipt_id;

  INSERT INTO stock (product_id, warehouse_id, on_hand, reserved)
  VALUES (NEW.product_id, v_wh, NEW.qty, 0)
  ON DUPLICATE KEY UPDATE on_hand = on_hand + NEW.qty;

  INSERT INTO stock_movements (product_id, warehouse_id, qty_change, move_type, ref_table, ref_id)
  VALUES (NEW.product_id, v_wh, NEW.qty, 'RECEIPT', 'receipt_items', NEW.receipt_item_id);

  IF v_po IS NOT NULL THEN
    SELECT supplier_id INTO v_supplier FROM purchase_orders WHERE po_id = v_po;
    IF v_supplier IS NOT NULL THEN
      UPDATE product_suppliers
      SET last_unit_cost = NEW.unit_cost
      WHERE product_id = NEW.product_id AND supplier_id = v_supplier;
    END IF;
  END IF;

  CALL check_and_create_reorder_alert(NEW.product_id, v_wh);
END//

CREATE TRIGGER trg_shipment_items_bi BEFORE INSERT ON shipment_items
FOR EACH ROW
BEGIN
  DECLARE v_wh INT;
  DECLARE v_on_hand INT;

  SELECT warehouse_id INTO v_wh FROM shipments WHERE shipment_id = NEW.shipment_id;
  SELECT on_hand INTO v_on_hand FROM stock WHERE product_id = NEW.product_id AND warehouse_id = v_wh;

  IF v_on_hand IS NULL OR v_on_hand < NEW.qty THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock for shipment';
  END IF;
END//

CREATE TRIGGER trg_shipment_items_ai AFTER INSERT ON shipment_items
FOR EACH ROW
BEGIN
  DECLARE v_wh INT;
  SELECT warehouse_id INTO v_wh FROM shipments WHERE shipment_id = NEW.shipment_id;

  UPDATE stock
  SET on_hand = on_hand - NEW.qty
  WHERE product_id = NEW.product_id AND warehouse_id = v_wh;

  INSERT INTO stock_movements (product_id, warehouse_id, qty_change, move_type, ref_table, ref_id)
  VALUES (NEW.product_id, v_wh, -NEW.qty, 'SHIPMENT', 'shipment_items', NEW.shipment_item_id);

  CALL check_and_create_reorder_alert(NEW.product_id, v_wh);
END//

CREATE TRIGGER trg_adjustment_items_ai AFTER INSERT ON adjustment_items
FOR EACH ROW
BEGIN
  DECLARE v_wh INT;
  SELECT warehouse_id INTO v_wh FROM adjustments WHERE adjustment_id = NEW.adjustment_id;

  INSERT INTO stock (product_id, warehouse_id, on_hand, reserved)
  VALUES (NEW.product_id, v_wh, GREATEST(NEW.qty_change,0), 0)
  ON DUPLICATE KEY UPDATE on_hand = on_hand + NEW.qty_change;

  INSERT INTO stock_movements (product_id, warehouse_id, qty_change, move_type, ref_table, ref_id)
  VALUES (NEW.product_id, v_wh, NEW.qty_change, 'ADJUSTMENT', 'adjustment_items', NEW.adjustment_item_id);

  CALL check_and_create_reorder_alert(NEW.product_id, v_wh);
END//

DELIMITER ;

CREATE OR REPLACE VIEW vw_stock AS
SELECT p.sku, p.name AS product, w.code AS warehouse, s.on_hand, s.reserved, s.available,
       p.reorder_point, p.reorder_qty
FROM stock s
JOIN products p   ON p.product_id = s.product_id
JOIN warehouses w ON w.warehouse_id = s.warehouse_id;

CREATE OR REPLACE VIEW vw_low_stock AS
SELECT * FROM vw_stock WHERE on_hand < reorder_point;

CREATE OR REPLACE VIEW vw_inventory_valuation AS
SELECT p.sku, p.name AS product, w.code AS warehouse,
       s.on_hand,
       COALESCE(ps.last_unit_cost, 0) AS unit_cost,
       (s.on_hand * COALESCE(ps.last_unit_cost, 0)) AS inventory_value
FROM stock s
JOIN products p   ON p.product_id = s.product_id
JOIN warehouses w ON w.warehouse_id = s.warehouse_id
LEFT JOIN product_suppliers ps ON ps.product_id = p.product_id;
SELECT * FROM vw_stock;

INSERT INTO purchase_orders (supplier_id, warehouse_id, status, expected_at, notes)
VALUES (1, 1, 'PLACED', DATE_ADD(CURDATE(), INTERVAL 7 DAY), 'TVs for launch');

INSERT INTO purchase_order_items (po_id, product_id, ordered_qty, unit_cost)
VALUES (LAST_INSERT_ID(), 1, 30, 17500.00),
       (LAST_INSERT_ID(), 3, 10, 34000.00);

INSERT INTO receipts (po_id, warehouse_id, reference, notes)
VALUES (1, 1, 'GRN-0001', 'All items OK');

INSERT INTO receipt_items (receipt_id, product_id, qty, unit_cost)
VALUES (1, 1, 30, 17500.00),
       (1, 3, 10, 34000.00);

SELECT * FROM vw_stock;
SELECT * FROM stock_movements;

INSERT INTO customers (name) VALUES ('Retail Mart');

INSERT INTO sales_orders (customer_id, warehouse_id, status, notes)
VALUES (1, 1, 'CONFIRMED', 'Priority');

INSERT INTO sales_order_items (so_id, product_id, ordered_qty, unit_price)
VALUES (1, 1, 5, 21000.00);

INSERT INTO shipments (so_id, warehouse_id, reference, notes)
VALUES (1, 1, 'SHP-0001', 'Normal dispatch');

INSERT INTO shipment_items (shipment_id, product_id, qty)
VALUES (1, 1, 5);

SELECT * FROM vw_stock;
SELECT * FROM vw_low_stock;         
SELECT * FROM reorder_alerts;        

CALL transfer_stock(1, 1, 2, 10, 'Balance to Mumbai');

SELECT * FROM vw_stock WHERE sku='TV42';
SELECT * FROM stock_movements WHERE product_id=1 ORDER BY created_at DESC;

SELECT * FROM vw_stock ORDER BY sku, warehouse;

SELECT sku, product, warehouse, on_hand, reorder_point, reorder_qty
FROM vw_low_stock
ORDER BY product;

SELECT p.sku, p.name AS product, SUM(ABS(sm.qty_change)) AS moved_qty
FROM stock_movements sm
JOIN products p ON p.product_id = sm.product_id
WHERE sm.move_type IN ('SHIPMENT','RECEIPT')
  AND sm.created_at >= DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY)
GROUP BY p.sku, p.name
ORDER BY moved_qty DESC
LIMIT 5;

SELECT * FROM vw_inventory_valuation ORDER BY inventory_value DESC;

SELECT sm.*, w.code AS warehouse
FROM stock_movements sm
JOIN warehouses w ON w.warehouse_id = sm.warehouse_id
WHERE sm.product_id = 1
ORDER BY sm.created_at DESC;
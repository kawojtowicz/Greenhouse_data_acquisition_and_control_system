USE greenhouse_data_base;

-- =====================
-- USERS
-- =====================
INSERT INTO Users (name, last_name, email, password_hash) VALUES
('Jan', 'Kowalski', 'jan.kowalski@example.com', 'hash123'),
('Anna', 'Nowak', 'anna.nowak@example.com', 'hash456');

-- =====================
-- GREENHOUSE CONTROLLERS
-- =====================
INSERT INTO Greenhouse_controllers (id_greenhouse_controller, id_user) VALUES
(1001, 1),
(1002, 2);

-- =====================
-- GREENHOUSES
-- =====================
INSERT INTO Greenhouses (greenhouse_name, description) VALUES
('Szklarnia A', 'Główna szklarnia produkcyjna'),
('Szklarnia B', 'Szklarnia testowa');

-- =====================
-- ZONES
-- =====================
INSERT INTO Zones (
  zone_name,
  id_greenhouse_controller,
  id_greenhouse,
  x, y, height, width
) VALUES
('Strefa Pomidorów', 1, 1, 10, 10, 40, 40),
('Strefa Ogórków', 1001, 1, 60, 10, 40, 40),
('Strefa Sałaty', 1002, 2, 20, 20, 50, 50);

-- =====================
-- SENSOR NODES
-- =====================
INSERT INTO Sensor_nodes (
  id_sensor_node,
  sensor_node_name,
  id_zone,
  x, y
) VALUES
(2001, 'Czujnik T/H/L 1', 1, 15, 15),
(2002, 'Czujnik T/H/L 2', 1, 30, 30),
(2003, 'Czujnik T/H/L 3', 2, 65, 15),
(2004, 'Czujnik T/H/L 4', 3, 25, 25);

-- =====================
-- HTL LOGS
-- =====================
INSERT INTO htl_logs (
  temperature,
  humidity,
  light,
  id_sensor_node
) VALUES
(22.5, 60.2, 12000, 2001),
(23.1, 58.9, 11800, 2001),
(21.8, 65.0, 11000, 2002),
(24.0, 55.5, 13000, 2003),
(20.3, 70.1, 9000, 2004);

-- =====================
-- END DEVICES
-- =====================
INSERT INTO End_devices (
  id_end_device,
  end_device_name,
  up_temp,
  down_temp,
  up_hum,
  down_hum,
  up_light,
  down_light,
  end_device_state,
  id_zone,
  x, y
) VALUES
(5149013745535275, 'Wentylator 1', NULL, NULL, NULL, NULL, 300, 50, 1, 5, 1000, 1000),
(3002, 'Nawilżacz 1', NULL, NULL, 75.0, 55.0, NULL, NULL, 0, 1, 18, 18),
(3003, 'Lampa LED 1', NULL, NULL, NULL, NULL, 15000, 8000, 1, 2, 70, 15),
(3004, 'Wentylator 2', 26.0, 17.0, NULL, NULL, NULL, NULL, 0, 3, 30, 30);

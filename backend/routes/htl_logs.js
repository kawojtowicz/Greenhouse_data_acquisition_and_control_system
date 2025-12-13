const express = require('express');
const router = express.Router();
const dbPromise = require('../db');

router.get('/', async (req, res) => {
  try {
    const db = await dbPromise;
    const [rows] = await db.query('SELECT * FROM htl_logs');
    res.json(rows);
  } catch (err) {
    console.error('Error fetching htl_logs:', err);
    res.status(500).json({ error: err.message });
  }
});

// router.post('/', async (req, res) => {
//   const { temperature, humidity, light, id_sensor_node, id_controller } = req.body;
//   const db = await dbPromise;

//   if (!temperature || !humidity || !light || !id_sensor_node || !id_controller) {
//     return res.status(400).json({ error: "Missing required fields" });
//   }

//   try {
//     await db.query('START TRANSACTION');

//     const [controllerExisting] = await db.query(
//       'SELECT id_greenhouse_controller FROM Greenhouse_controllers WHERE id_greenhouse_controller = ?',
//       [id_controller]
//     );

//     let createdController = false;
//     if (controllerExisting.length === 0) {
//       await db.query(
//         'INSERT INTO Greenhouse_controllers (id_greenhouse_controller, greenhouse_name, id_user) VALUES (?, ?, ?)',
//         [id_controller, `AutoController_${id_controller}`, 1]
//       );
//       createdController = true;
//     }

//     const [sensorExisting] = await db.query(
//       'SELECT id_sensor_node FROM Sensor_nodes WHERE id_sensor_node = ?',
//       [id_sensor_node]
//     );

//     let createdSensorNode = false;
//     if (sensorExisting.length === 0) {
//       await db.query(
//         'INSERT INTO Sensor_nodes (id_sensor_node, sensor_node_name, id_greenhouse_controller) VALUES (?, ?, ?)',
//         [id_sensor_node, `AutoNode_${id_sensor_node}`, id_controller]
//       );
//       createdSensorNode = true;
//     }

//     const log_time = new Date().toISOString().slice(0, 19).replace('T', ' ');
//     const [result] = await db.query(
//       'INSERT INTO htl_logs (temperature, humidity, light, id_sensor_node, log_time) VALUES (?, ?, ?, ?, ?)',
//       [temperature, humidity, light, id_sensor_node, log_time]
//     );

//     await db.query('COMMIT');

//     res.json({
//       id_log: result.insertId,
//       temperature,
//       humidity,
//       light,
//       id_sensor_node,
//       id_controller,
//       log_time,
//       controller_created: createdController,
//       sensor_node_created: createdSensorNode
//     });

//   } catch (err) {
//     await db.query('ROLLBACK');
//     console.error('Error adding log:', err);
//     res.status(500).json({ error: err.message });
//   }
// });
router.post('/', async (req, res) => {
  const { temperature, humidity, light, id_sensor_node, id_controller } = req.body;
  const db = await dbPromise;

  if (
    temperature === undefined ||
    humidity === undefined ||
    light === undefined ||
    !id_sensor_node ||
    !id_controller
  ) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    await db.query('START TRANSACTION');

    // 1️⃣ Controller
    const [[controller]] = await db.query(
      'SELECT id_greenhouse_controller FROM Greenhouse_controllers WHERE id_greenhouse_controller = ?',
      [id_controller]
    );

    if (!controller) {
      await db.query(
        'INSERT INTO Greenhouse_controllers (id_greenhouse_controller, id_user) VALUES (?, ?)',
        [id_controller, 1] // domyślny user (np. admin / system)
      );
    }

    // 2️⃣ Greenhouse
    const [[greenhouse]] = await db.query(
      'SELECT id_greenhouse FROM Greenhouses WHERE greenhouse_name = ?',
      [`AutoGreenhouse_${id_controller}`]
    );

    let greenhouseId;
    if (!greenhouse) {
      const [gRes] = await db.query(
        'INSERT INTO Greenhouses (greenhouse_name, description) VALUES (?, ?)',
        [`AutoGreenhouse_${id_controller}`, 'Auto-created from IoT']
      );
      greenhouseId = gRes.insertId;
    } else {
      greenhouseId = greenhouse.id_greenhouse;
    }

    // 3️⃣ Zone
    const [[zone]] = await db.query(
      'SELECT id_zone FROM Zones WHERE id_greenhouse_controller = ? AND id_greenhouse = ?',
      [id_controller, greenhouseId]
    );

    let zoneId;
    if (!zone) {
      const [zRes] = await db.query(
        `INSERT INTO Zones (
          zone_name, id_greenhouse_controller, id_greenhouse
        ) VALUES (?, ?, ?)`,
        ['AutoZone', id_controller, greenhouseId]
      );
      zoneId = zRes.insertId;
    } else {
      zoneId = zone.id_zone;
    }

    // 4️⃣ Sensor node
    const [[sensor]] = await db.query(
      'SELECT id_sensor_node FROM Sensor_nodes WHERE id_sensor_node = ?',
      [id_sensor_node]
    );

    if (!sensor) {
      await db.query(
        `INSERT INTO Sensor_nodes (
          id_sensor_node, sensor_node_name, id_zone
        ) VALUES (?, ?, ?)`,
        [id_sensor_node, `AutoNode_${id_sensor_node}`, zoneId]
      );
    }

    // 5️⃣ Log
    const [logRes] = await db.query(
      `INSERT INTO htl_logs (
        temperature, humidity, light, id_sensor_node
      ) VALUES (?, ?, ?, ?)`,
      [temperature, humidity, light, id_sensor_node]
    );

    await db.query('COMMIT');

    res.json({
      id_log: logRes.insertId,
      temperature,
      humidity,
      light,
      id_sensor_node,
      id_controller,
      zone_id: zoneId,
      greenhouse_id: greenhouseId,
      auto_created: true
    });

  } catch (err) {
    await db.query('ROLLBACK');
    console.error('Error adding log:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

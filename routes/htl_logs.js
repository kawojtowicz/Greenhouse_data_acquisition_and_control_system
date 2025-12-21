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


router.post('/', async (req, res) => {
  const { temperature, humidity, light, id_sensor_node, device_id, node_type } = req.body;
  const db = await dbPromise;

  if (node_type === undefined || !id_sensor_node || !device_id) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    await db.query('START TRANSACTION');

    const [controllerRows] = await db.query(
      'SELECT id_greenhouse_controller FROM Greenhouse_controllers WHERE device_id = ?',
      [device_id]
    );

    let controllerId;
    if (controllerRows.length === 0) {
      const [cRes] = await db.query(
        'INSERT INTO Greenhouse_controllers (device_id) VALUES (?)',
        [device_id]
      );
      controllerId = cRes.insertId;
    } else {
      controllerId = controllerRows[0].id_greenhouse_controller;
    }

    if (node_type === 1) {
      if (temperature === undefined || humidity === undefined || light === undefined) {
        await db.query('ROLLBACK');
        return res.status(400).json({ error: 'Missing sensor data' });
      }

      const [sensorRows] = await db.query(
        'SELECT id_sensor_node FROM Sensor_nodes WHERE id_sensor_node = ?',
        [id_sensor_node]
      );

      const sensorExists = sensorRows.length > 0;

      if (!sensorExists) {
        await db.query(
          'INSERT INTO Sensor_nodes (id_sensor_node, sensor_node_name, id_greenhouse_controller) VALUES (?, ?, ?)',
          [id_sensor_node, `AutoNode_${id_sensor_node}`, controllerId]
        );
      }

      const [logRes] = await db.query(
        'INSERT INTO htl_logs (temperature, humidity, light, id_sensor_node) VALUES (?, ?, ?, ?)',
        [temperature, humidity, light, id_sensor_node]
      );

      await db.query('COMMIT');

      return res.json({
        type: 'sensor',
        id_log: logRes.insertId,
        id_sensor_node,
        controllerId,
        sensor_auto_created: !sensorExists
      });
    }

    if (node_type === 0) {
      const [endDeviceRows] = await db.query(
        'SELECT id_end_device FROM End_devices WHERE id_end_device = ?',
        [id_sensor_node]
      );

      const endDeviceExists = endDeviceRows.length > 0;

      if (!endDeviceExists) {
        await db.query(
          'INSERT INTO End_devices (id_end_device, end_device_name, id_zone, id_greenhouse_controller) VALUES (?, ?, NULL, ?)',
          [id_sensor_node, `EndDevice_${id_sensor_node}`, controllerId]
        );
      }

      await db.query('COMMIT');

      return res.json({
        type: 'end_device',
        id_end_device: id_sensor_node,
        auto_created: !endDeviceExists
      });
    }

    await db.query('ROLLBACK');
    res.status(400).json({ error: 'Invalid node_type' });

  } catch (err) {
    await db.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});


module.exports = router;

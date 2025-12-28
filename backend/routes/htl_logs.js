const express = require('express');
const router = express.Router();
const db = require('../db'); // pg Pool

router.get('/', async (req, res) => {
  try {
    const { rows } = await db.query('SELECT * FROM htl_logs');
    res.json(rows);
  } catch (err) {
    console.error('Error fetching htl_logs:', err);
    res.status(500).json({ error: err.message });
  }
});



router.post('/', async (req, res) => {
  let { temperature, humidity, light, id_sensor_node, device_id, node_type } = req.body;

  node_type = Number(node_type);
  if (![0,1].includes(node_type)) {
    return res.status(400).json({ error: 'Invalid or missing node_type' });
  }


  if (id_sensor_node === undefined || id_sensor_node === null) {
    return res.status(400).json({ error: 'Missing id_sensor_node' });
  }

  const id_sensor_node_num = BigInt(id_sensor_node.toString());

  const client = await db.connect();

  try {
    await client.query('BEGIN');

    const { rows: controllerRows } = await client.query(
      'SELECT id_greenhouse_controller FROM Greenhouse_controllers WHERE device_id = $1',
      [device_id]
    );

    let controllerId;
    if (controllerRows.length === 0) {
      const { rows: cRows } = await client.query(
        'INSERT INTO Greenhouse_controllers (device_id) VALUES ($1) RETURNING id_greenhouse_controller',
        [device_id]
      );
      controllerId = cRows[0].id_greenhouse_controller;
    } else {
      controllerId = controllerRows[0].id_greenhouse_controller;
    }

    if (node_type === 1) { 
      if (temperature === undefined || humidity === undefined || light === undefined) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Missing sensor data' });
      }

      const { rows: sensorRows } = await client.query(
        'SELECT id_sensor_node FROM Sensor_nodes WHERE id_sensor_node = $1',
        [id_sensor_node_num]  
      );

      const sensorExists = sensorRows.length > 0;

      if (!sensorExists) {
        await client.query(
          'INSERT INTO Sensor_nodes (id_sensor_node, sensor_node_name, id_greenhouse_controller) VALUES ($1, $2, $3)',
          [id_sensor_node_num, `AutoNode_${id_sensor_node}`, controllerId]
        );
      }

      const { rows: logRows } = await client.query(
        'INSERT INTO htl_logs (temperature, humidity, light, id_sensor_node) VALUES ($1, $2, $3, $4) RETURNING id_htl_log',
        [temperature, humidity, light, id_sensor_node_num]
      );

      await client.query('COMMIT');

      return res.json({
        type: 'sensor',
        id_htl_log: logRows[0].id_htl_log,
        id_sensor_node,
        controllerId,
        sensor_auto_created: !sensorExists
      });
    }

    if (node_type === 0) { 
      const { rows: endDeviceRows } = await client.query(
        'SELECT id_end_device FROM End_devices WHERE id_end_device = $1',
        [id_sensor_node_num]
      );

      const endDeviceExists = endDeviceRows.length > 0;

      if (!endDeviceExists) {
        await client.query(
          'INSERT INTO End_devices (id_end_device, end_device_name, id_zone, id_greenhouse_controller) VALUES ($1, $2, NULL, $3)',
          [id_sensor_node_num, `EndDevice_${id_sensor_node}`, controllerId]
        );
      }

      await client.query('COMMIT');

      return res.json({
        type: 'end_device',
        id_end_device: id_sensor_node,
        auto_created: !endDeviceExists
      });
    }

    await client.query('ROLLBACK');
    res.status(400).json({ error: 'Invalid node_type' });

  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    client.release();
  }
});

module.exports = router;
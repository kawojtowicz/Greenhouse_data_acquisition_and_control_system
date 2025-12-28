const express = require('express');
const router = express.Router();
const db = require('../db');
const jwt = require('jsonwebtoken');
const { authenticateDevice } = require('../auth');

router.post('/', async (req, res) => {
  const { device_id, controller_name } = req.body;

  if (!device_id) return res.status(400).json({ message: 'device_id required' });

  try {
    const { rows: existing } = await db.query(
      'SELECT * FROM Greenhouse_controllers WHERE device_id = $1',
      [device_id]
    );

    if (existing.length === 0) {
      await db.query(
        'INSERT INTO Greenhouse_controllers (device_id, id_user) VALUES ($1, NULL)',
        [device_id]
      );
    }

    res.json({ message: 'Device announced' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/zones/full', authenticateDevice, async (req, res) => {
  try {
    const deviceId = req.device.device_id;

    const { rows: zones } = await db.query(
      `SELECT z.id_zone
       FROM Zones z
       JOIN Greenhouse_controllers gc
         ON z.id_greenhouse_controller = gc.id_greenhouse_controller
       WHERE gc.device_id = $1`,
      [deviceId]
    );

    const result = [];

    for (const z of zones) {
      const zoneId = z.id_zone;

      const { rows: sensors } = await db.query(
        `SELECT 
            l.id_sensor_node AS "sensorNodeID",
            l.temperature    AS "tmpCelsius",
            l.humidity       AS "humRH",
            l.light          AS "lightLux"
         FROM htl_logs l
         JOIN Sensor_nodes sn ON sn.id_sensor_node = l.id_sensor_node
         WHERE sn.id_zone = $1
         ORDER BY l.log_time DESC
         LIMIT 1`,
        [zoneId]
      );

      const { rows: endDevices } = await db.query(
        `SELECT 
            id_end_device,
            up_temp, down_temp,
            up_hum, down_hum,
            up_light, down_light,
            end_device_state
         FROM End_devices
         WHERE id_zone = $1`,
        [zoneId]
      );

      const tempEndDevices = [];
      const humEndDevices = [];
      const lightEndDevices = [];

      for (const ed of endDevices) {
        if (ed.up_temp !== null || ed.down_temp !== null) {
          tempEndDevices.push({
            id: ed.id_end_device,
            upValue: ed.up_temp ?? 0,
            downValue: ed.down_temp ?? 0,
            onOff: ed.end_device_state
          });
        }

        if (ed.up_hum !== null || ed.down_hum !== null) {
          humEndDevices.push({
            id: ed.id_end_device,
            upValue: ed.up_hum ?? 0,
            downValue: ed.down_hum ?? 0,
            onOff: ed.end_device_state
          });
        }

        if (ed.up_light !== null || ed.down_light !== null) {
          lightEndDevices.push({
            id: ed.id_end_device,
            upValue: ed.up_light ?? 0,
            downValue: ed.down_light ?? 0,
            onOff: ed.end_device_state
          });
        }
      }

      result.push({
        zoneID: zoneId,
        sensorValues: sensors[0] || {
          tmpCelsius: 0,
          humRH: 0,
          lightLux: 0,
          sensorNodeID: 0
        },
        tempEndDevices,
        humEndDevices,
        lightEndDevices
      });
    }

    res.json({ zones: result });

  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
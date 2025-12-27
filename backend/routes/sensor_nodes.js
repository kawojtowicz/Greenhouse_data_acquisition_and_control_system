const express = require('express');
const router = express.Router();
const db = require('../db'); // pg Pool

router.get('/', async (req, res) => {
  try {
    const { rows } = await db.query('SELECT * FROM Sensor_nodes');
    res.json(rows);
  } catch (err) {
    console.error('Error fetching sensor nodes:', err);
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { sensor_node_name, id_greenhouse_controller } = req.body;

    const { rows } = await db.query(
      `INSERT INTO Sensor_nodes (sensor_node_name, id_greenhouse_controller)
       VALUES ($1, $2)
       RETURNING id_sensor_node`,
      [sensor_node_name, id_greenhouse_controller]
    );

    res.json({
      id: rows[0].id_sensor_node,
      sensor_node_name,
      id_greenhouse_controller
    });
  } catch (err) {
    console.error('Error adding sensor node:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

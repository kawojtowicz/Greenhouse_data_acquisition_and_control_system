const express = require('express');
const router = express.Router();
const dbPromise = require('../db');


router.get('/', async (req, res) => {
  try {
    const db = await dbPromise;
    const [rows] = await db.query('SELECT * FROM Sensor_nodes');
    res.json(rows);
  } catch (err) {
    console.error('Error fetching sensor nodes:', err);
    res.status(500).json({ error: err.message });
  }
});


router.post('/', async (req, res) => {
  try {
    const { sensor_node_name, id_greenhouse_controller } = req.body;
    const db = await dbPromise;

    const [result] = await db.query(
      'INSERT INTO Sensor_nodes (sensor_node_name, id_greenhouse_controller) VALUES (?, ?)',
      [sensor_node_name, id_greenhouse_controller]
    );

    res.json({
      id: result.insertId,
      sensor_node_name,
      id_greenhouse_controller
    });
  } catch (err) {
    console.error('Error adding sensor node:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

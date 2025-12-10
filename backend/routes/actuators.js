const express = require('express');
const router = express.Router();
const dbPromise = require('../db');

router.get('/', async (req, res) => {
  try {
    const db = await dbPromise;
    const [rows] = await db.query('SELECT * FROM Actuators');
    res.json(rows);
  } catch (err) {
    console.error('Error fetching actuators:', err);
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { actuator_name, id_greenhouse_controller, actuator_state } = req.body;
    const db = await dbPromise;

    const [result] = await db.query(
      'INSERT INTO Actuators (actuator_name, id_greenhouse_controller, actuator_state) VALUES (?, ?, ?)',
      [actuator_name, id_greenhouse_controller, actuator_state]
    );

    res.json({
      id: result.insertId,
      actuator_name,
      id_greenhouse_controller,
      actuator_state
    });
  } catch (err) {
    console.error('Error adding actuator:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;


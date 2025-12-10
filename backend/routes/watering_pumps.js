const express = require('express');
const router = express.Router();
const dbPromise = require('../db');

router.get('/', async (req, res) => {
  try {
    const db = await dbPromise;
    const [rows] = await db.query('SELECT * FROM Watering_pumps');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { watering_pump_name, id_greenhouse_controller, watering_pump_state } = req.body;
    const db = await dbPromise;
    const [result] = await db.query(
      'INSERT INTO Watering_pumps (watering_pump_name, id_greenhouse_controller, watering_pump_state) VALUES (?, ?, ?)',
      [watering_pump_name, id_greenhouse_controller, watering_pump_state]
    );

    res.json({
      id: result.insertId,
      watering_pump_name,
      id_greenhouse_controller,
      watering_pump_state
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

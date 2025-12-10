const express = require('express');
const router = express.Router();
const dbPromise = require('../db');


router.get('/', async (req, res) => {
  try {
    const db = await dbPromise;
    const [rows] = await db.query('SELECT * FROM Heaters');
    res.json(rows);
  } catch (err) {
    console.error('Error fetching heaters:', err);
    res.status(500).json({ error: err.message });
  }
});

  
router.post('/', async (req, res) => {
  try {
    const { heater_name, id_greenhouse_controller, heater_state } = req.body;
    const db = await dbPromise;

    const [result] = await db.query(
      'INSERT INTO Heaters (heater_name, id_greenhouse_controller, heater_state) VALUES (?, ?, ?)',
      [heater_name, id_greenhouse_controller, heater_state]
    );

    res.json({
      id: result.insertId,
      heater_name,
      id_greenhouse_controller,
      heater_state
    });
  } catch (err) {
    console.error('Error adding heater:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

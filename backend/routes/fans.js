const express = require('express');
const router = express.Router();
const dbPromise = require('../db');

router.get('/', async (req, res) => {
  try {
    const db = await dbPromise;
    const [rows] = await db.query('SELECT * FROM Fans');
    res.json(rows);
  } catch (err) {
    console.error('Error fetching fans:', err);
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { fan_name, id_greenhouse_controller, fun_state } = req.body;

    if (!fan_name || !id_greenhouse_controller || fun_state === undefined) {
      return res.status(400).json({ error: 'No required fields' });
    }

    const db = await dbPromise;
    const [result] = await db.query(
      'INSERT INTO Fans (fan_name, id_greenhouse_controller, fun_state) VALUES (?, ?, ?)',
      [fan_name, id_greenhouse_controller, fun_state]
    );

    res.status(201).json({
      id: result.insertId,
      fan_name,
      id_greenhouse_controller,
      fun_state
    });
  } catch (err) {
    console.error('Error adding fan:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

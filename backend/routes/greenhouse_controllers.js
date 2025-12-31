const express = require('express');
const router = express.Router();
const db = require('../db');

router.get('/', async (req, res) => {
  try {
    const { rows } = await db.query('SELECT * FROM Greenhouse_controllers');
    res.json(rows);
  } catch (err) {
    console.error('Error fetching controllers:', err);
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { greenhouse_name, id_user } = req.body;

    const { rows } = await db.query(
      'INSERT INTO Greenhouse_controllers (greenhouse_name, id_user) VALUES ($1, $2) RETURNING id_greenhouse_controller',
      [greenhouse_name, id_user]
    );

    res.json({
      id: rows[0].id_greenhouse_controller,
      greenhouse_name,
      id_user
    });
  } catch (err) {
    console.error('Error adding controller:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
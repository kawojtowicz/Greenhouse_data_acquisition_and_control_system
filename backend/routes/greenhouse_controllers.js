const express = require('express');
const router = express.Router();
const dbPromise = require('../db');


router.get('/', async (req, res) => {
  try {
    const db = await dbPromise;
    const [rows] = await db.query('SELECT * FROM Greenhouse_controllers');
    res.json(rows);
  } catch (err) {
    console.error('Error fetching controllers:', err);
    res.status(500).json({ error: err.message });
  }
});


router.post('/', async (req, res) => {
  try {
    const { greenhouse_name, id_user } = req.body;
    const db = await dbPromise;

    const [result] = await db.query(
      'INSERT INTO Greenhouse_controllers (greenhouse_name, id_user) VALUES (?, ?)',
      [greenhouse_name, id_user]
    );

    res.json({
      id: result.insertId,
      greenhouse_name,
      id_user
    });
  } catch (err) {
    console.error('Error adding controller:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const dbPromise = require('../db');
const { isUserAuthenticated } = require('../auth');

router.get('/', isUserAuthenticated, async (req, res) => {
    res.status(200).json({
        id: req.session.user.id,
        email: req.session.user.email,
        name: req.session.user.name,
        lastName: req.session.user.lastName,
    });
});


router.post('/', async (req, res) => {
  const { name, last_name, email, password } = req.body;

  if (!name || !last_name || !email || !password) {
    return res.status(400).json({ message: 'Wszystkie pola są wymagane' });
  }

  try {
    const db = await dbPromise;
    const [existing] = await db.query('SELECT id_user FROM Users WHERE email = ?', [email]);
    if (existing.length > 0) {
      return res.status(409).json({ message: 'Użytkownik o tym emailu już istnieje' });
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const [result] = await db.query(
      'INSERT INTO Users (name, last_name, email, password_hash) VALUES (?, ?, ?, ?)',
      [name, last_name, email, passwordHash]
    );

    req.session.user = {
      id: result.insertId,
      name,
      lastName: last_name,
      email
    };

    res.json({ message: 'Rejestracja zakończona', user: req.session.user });
  } catch (err) {
    console.error('Błąd przy rejestracji:', err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});


router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: 'Email i hasło są wymagane' });
  }

  try {
    const db = await dbPromise;
    const [rows] = await db.query('SELECT * FROM Users WHERE email = ?', [email]);

    if (rows.length === 0) {
      return res.status(401).json({ message: 'Nieprawidłowy email lub hasło' });
    }

    const user = rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);

    if (!valid) {
      return res.status(401).json({ message: 'Nieprawidłowy email lub hasło' });
    }

    req.session.user = {
      id: user.id_user,
      name: user.name,
      lastName: user.last_name,
      email: user.email
    };

    res.json({ message: 'Logowanie udane', user: req.session.user });
  } catch (err) {
    console.error('Błąd logowania:', err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});

router.delete('/', isUserAuthenticated, (req, res) => {
    req.session.destroy(err => {
        if (err) {
            console.error('Error during logout:', err);
            return res.status(500).json({ message: 'Internal server error.' });
        }
        res.status(200).json({ message: 'Logout successful.' });
    });
});


router.get('/sensors', isUserAuthenticated, async (req, res) => {
  try {
    console.log('User session:', req.session.user);
    const userId = req.session.user.id;
    const db = await dbPromise;

    const [controllers] = await db.query(
      'SELECT * FROM Greenhouse_controllers WHERE id_user = ?',
      [userId]
    );

    if (controllers.length === 0) {
      return res.json({ controllers: [] });
    }

    const controllerIds = controllers.map(c => c.id_greenhouse_controller);

    const [sensorNodes] = await db.query(
      'SELECT * FROM Sensor_nodes WHERE id_greenhouse_controller IN (?)',
      [controllerIds]
    );

    const result = controllers.map(controller => ({
      id_greenhouse_controller: controller.id_greenhouse_controller,
      greenhouse_name: controller.greenhouse_name,
      temperature_set: controller.temperature_set,
      sensor_nodes: sensorNodes.filter(
        node => node.id_greenhouse_controller === controller.id_greenhouse_controller
      )
    }));

    res.json({ controllers: result });
  } catch (err) {
    console.error('Błąd przy pobieraniu sensor node:', err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});

router.post('/:id/temperature', isUserAuthenticated, async (req, res) => {
  console.log('POST /greenhouse/:id/temperature', {
    user: req.session.user,
    params: req.params,
    body: req.body,
  });

  const greenhouseId = req.params.id;
  const { temperature_set } = req.body;

  if (temperature_set === undefined || typeof temperature_set !== 'number') {
    return res.status(400).json({ message: 'Nieprawidłowa wartość temperatury' });
  }

  try {
    const db = await dbPromise;

    const [rows] = await db.query(
      'SELECT * FROM Greenhouse_controllers WHERE id_greenhouse_controller = ? AND id_user = ?',
      [greenhouseId, req.session.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: 'Nie znaleziono szklarni dla tego użytkownika' });
    }

    await db.query(
      'UPDATE Greenhouse_controllers SET temperature_set = ? WHERE id_greenhouse_controller = ?',
      [temperature_set, greenhouseId]
    );

    res.json({ message: 'Temperatura zaktualizowana', temperature_set });
  } catch (err) {
    console.error('Błąd przy aktualizacji temperatury:', err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});

router.get('/:id/last-log', isUserAuthenticated, async (req, res) => {
  const greenhouseId = req.params.id;
  try {
    const db = await dbPromise;

    const [rows] = await db.query(
      `SELECT hl.temperature, hl.humidity, hl.light, hl.log_time, hl.id_sensor_node
       FROM htl_logs hl
       JOIN Sensor_nodes sn ON hl.id_sensor_node = sn.id_sensor_node
       WHERE sn.id_greenhouse_controller = ?
         AND hl.log_time = (
           SELECT MAX(hl2.log_time)
           FROM htl_logs hl2
           WHERE hl2.id_sensor_node = hl.id_sensor_node
         )
       ORDER BY hl.id_sensor_node`,
      [greenhouseId]
    );

    res.json(rows);
  } catch (err) {
    console.error('Błąd przy pobieraniu ostatnich logów:', err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});


module.exports = router;


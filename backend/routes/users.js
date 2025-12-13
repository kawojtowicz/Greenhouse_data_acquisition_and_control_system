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
    const userId = req.session.user.id;
    const db = await dbPromise;

    const [rows] = await db.query(`
      SELECT 
        gc.id_greenhouse_controller,
        g.greenhouse_name,
        z.id_zone,
        z.zone_name,
        sn.id_sensor_node,
        sn.sensor_node_name
      FROM Greenhouse_controllers gc
      JOIN Zones z ON z.id_greenhouse_controller = gc.id_greenhouse_controller
      JOIN Greenhouses g ON g.id_greenhouse = z.id_greenhouse
      LEFT JOIN Sensor_nodes sn ON sn.id_zone = z.id_zone
      WHERE gc.id_user = ?
      ORDER BY gc.id_greenhouse_controller, z.id_zone
    `, [userId]);

    const controllersMap = {};

    for (const row of rows) {
      if (!controllersMap[row.id_greenhouse_controller]) {
        controllersMap[row.id_greenhouse_controller] = {
          id_greenhouse_controller: row.id_greenhouse_controller,
          greenhouse_name: row.greenhouse_name,
          zones: []
        };
      }

      let controller = controllersMap[row.id_greenhouse_controller];

      let zone = controller.zones.find(z => z.id_zone === row.id_zone);
      if (!zone) {
        zone = {
          id_zone: row.id_zone,
          zone_name: row.zone_name,
          sensor_nodes: []
        };
        controller.zones.push(zone);
      }

      if (row.id_sensor_node) {
        zone.sensor_nodes.push({
          id_sensor_node: row.id_sensor_node,
          sensor_node_name: row.sensor_node_name
        });
      }
    }

    res.json({ controllers: Object.values(controllersMap) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});

router.post(
  '/sensors/position',
  isUserAuthenticated,
  async (req, res) => {
    const { id_sensor_node, x, y } = req.body;
    const db = await dbPromise;

    if (!id_sensor_node || x === undefined || y === undefined) {
      return res.status(400).json({ message: 'Missing id_sensor_node, x or y' });
    }

    try {
      // 🔐 sprawdzamy czy sensor należy do zalogowanego usera
      const [rows] = await db.query(
        `
        SELECT sn.id_sensor_node
        FROM Sensor_nodes sn
        JOIN Zones z ON sn.id_zone = z.id_zone
        JOIN Greenhouse_controllers gc ON z.id_greenhouse_controller = gc.id_greenhouse_controller
        WHERE sn.id_sensor_node = ?
          AND gc.id_user = ?
        `,
        [id_sensor_node, req.session.user.id]
      );

      if (rows.length === 0) {
        return res.status(403).json({ message: 'Access denied' });
      }

      await db.query(
        `
        UPDATE Sensor_nodes
        SET x = ?, y = ?
        WHERE id_sensor_node = ?
        `,
        [Math.round(x), Math.round(y), id_sensor_node]
      );

      res.json({
        message: 'Sensor position saved',
        id_sensor_node,
        x,
        y,
      });
    } catch (err) {
      console.error('Error saving sensor position:', err);
      res.status(500).json({ message: 'Server error' });
    }
  }
);


router.get('/:id/last-log', isUserAuthenticated, async (req, res) => {
  const controllerId = req.params.id;

  try {
    const db = await dbPromise;

    const [rows] = await db.query(`
      SELECT 
        sn.id_sensor_node,
        sn.sensor_node_name,
        sn.x,
        sn.y,
        hl.temperature,
        hl.humidity,
        hl.light,
        hl.log_time
      FROM Sensor_nodes sn
      JOIN Zones z ON sn.id_zone = z.id_zone
      JOIN htl_logs hl ON hl.id_sensor_node = sn.id_sensor_node
      WHERE z.id_greenhouse_controller = ?
        AND hl.log_time = (
          SELECT MAX(log_time)
          FROM htl_logs
          WHERE id_sensor_node = sn.id_sensor_node
        )
      ORDER BY sn.id_sensor_node
    `, [controllerId]);

    res.json(rows);
  } catch (err) {
    console.error('Błąd pobierania logów:', err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});



router.get('/zones/:zoneId/devices', isUserAuthenticated, async (req, res) => {
  const { zoneId } = req.params;
  const db = await dbPromise;

  const [rows] = await db.query(`
    SELECT *
    FROM End_devices
    WHERE id_zone = ?
  `, [zoneId]);

  res.json(rows);
});

// Zmiana szklarni dla sensora
router.post('/sensors/change-controller', isUserAuthenticated, async (req, res) => {
  const { id_sensor_node, new_controller_id } = req.body;
  const db = await dbPromise;

  if (!id_sensor_node || !new_controller_id) {
    return res.status(400).json({ message: 'Missing id_sensor_node or new_controller_id' });
  }

  try {
    // Sprawdzamy, czy sensor należy do użytkownika
    const [sensorRows] = await db.query(
      `SELECT sn.id_sensor_node
       FROM Sensor_nodes sn
       JOIN Zones z ON sn.id_zone = z.id_zone
       JOIN Greenhouse_controllers gc ON z.id_greenhouse_controller = gc.id_greenhouse_controller
       WHERE sn.id_sensor_node = ?
         AND gc.id_user = ?`,
      [id_sensor_node, req.session.user.id]
    );

    if (sensorRows.length === 0) {
      return res.status(403).json({ message: 'Access denied: sensor not found or not owned by user' });
    }

    // Sprawdzamy, czy nowa szklarnia należy do tego samego użytkownika
    const [controllerRows] = await db.query(
      'SELECT id_greenhouse_controller FROM Greenhouse_controllers WHERE id_greenhouse_controller = ? AND id_user = ?',
      [new_controller_id, req.session.user.id]
    );

    if (controllerRows.length === 0) {
      return res.status(403).json({ message: 'Access denied: controller not found or not owned by user' });
    }

    // Aktualizacja sensora – zakładamy, że sensor ma przypisaną strefę (zone)
    // Przenosimy go do pierwszej strefy nowej szklarni
    const [zoneRows] = await db.query(
      'SELECT id_zone FROM Zones WHERE id_greenhouse_controller = ? ORDER BY id_zone LIMIT 1',
      [new_controller_id]
    );

    if (zoneRows.length === 0) {
      return res.status(400).json({ message: 'Target controller has no zones' });
    }

    const newZoneId = zoneRows[0].id_zone;

    await db.query(
      'UPDATE Sensor_nodes SET id_zone = ? WHERE id_sensor_node = ?',
      [newZoneId, id_sensor_node]
    );

    res.json({
      message: 'Sensor moved successfully',
      id_sensor_node,
      new_controller_id,
      new_zone_id: newZoneId,
    });
  } catch (err) {
    console.error('Error changing sensor controller:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Pobieranie listy szklarni użytkownika
router.get('/greenhouses', isUserAuthenticated, async (req, res) => {
  try {
    const userId = req.session.user.id;
    const db = await dbPromise;

    const [rows] = await db.query(
      'SELECT id_greenhouse_controller, greenhouse_name FROM Greenhouse_controllers WHERE id_user = ?',
      [userId]
    );

    res.json({ greenhouses: rows });
  } catch (err) {
    console.error('Error fetching user greenhouses:', err);
    res.status(500).json({ message: 'Server error' });
  }
});


// Dodawanie nowej szklarni
router.post('/greenhouses', isUserAuthenticated, async (req, res) => {
  const { greenhouse_name, description } = req.body;

  if (!greenhouse_name || greenhouse_name.trim() === '') {
    return res.status(400).json({ message: 'Nazwa szklarni jest wymagana' });
  }

  try {
    const db = await dbPromise;

    // Tworzymy nową szklarnię w tabeli Greenhouses
    const [result] = await db.query(
      'INSERT INTO Greenhouses (greenhouse_name, description) VALUES (?, ?)',
      [greenhouse_name, description || null]
    );

    res.status(201).json({
      message: 'Szklarnia utworzona',
      greenhouse: {
        id_greenhouse: result.insertId,
        greenhouse_name,
        description: description || null
      }
    });
  } catch (err) {
    console.error('Error creating greenhouse:', err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});


// Pobieranie wszystkich stref użytkownika
router.get('/zones', isUserAuthenticated, async (req, res) => {
  try {
    const userId = req.session.user.id;
    const db = await dbPromise;

    const [rows] = await db.query(`
      SELECT 
        z.id_zone,
        z.zone_name,
        z.id_greenhouse_controller,
        z.id_greenhouse,
        g.greenhouse_name
      FROM Zones z
      JOIN Greenhouse_controllers gc ON z.id_greenhouse_controller = gc.id_greenhouse_controller
      JOIN Greenhouses g ON z.id_greenhouse = g.id_greenhouse
      WHERE gc.id_user = ?
      ORDER BY gc.id_greenhouse_controller, z.id_zone
    `, [userId]);

    res.json({ zones: rows });
  } catch (err) {
    console.error('Error fetching user zones:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Pobieranie stref dla jednej szklarni/kontrolera
router.get('/greenhouses/:controllerId/zones', isUserAuthenticated, async (req, res) => {
  const { controllerId } = req.params;

  try {
    const db = await dbPromise;

    // Sprawdzenie czy kontroler należy do użytkownika
    const [checkController] = await db.query(
      'SELECT id_greenhouse_controller FROM Greenhouse_controllers WHERE id_greenhouse_controller = ? AND id_user = ?',
      [controllerId, req.session.user.id]
    );

    if (checkController.length === 0) {
      return res.status(403).json({ message: 'Access denied: controller not found or not owned by user' });
    }

    const [zones] = await db.query(`
      SELECT 
        z.id_zone,
        z.zone_name,
        z.id_greenhouse,
        g.greenhouse_name
      FROM Zones z
      JOIN Greenhouses g ON z.id_greenhouse = g.id_greenhouse
      WHERE z.id_greenhouse_controller = ?
      ORDER BY z.id_zone
    `, [controllerId]);

    res.json({ zones });
  } catch (err) {
    console.error('Error fetching zones for controller:', err);
    res.status(500).json({ message: 'Server error' });
  }
});



module.exports = router;

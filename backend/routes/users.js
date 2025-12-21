const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const dbPromise = require('../db');
const jwt = require('jsonwebtoken');
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
      const [rows] = await db.query(
        `
        SELECT sn.id_sensor_node
        FROM Sensor_nodes sn
        LEFT JOIN Zones z ON sn.id_zone = z.id_zone
        LEFT JOIN Greenhouses g ON z.id_greenhouse = g.id_greenhouse
        WHERE sn.id_sensor_node = ?
          AND (g.id_user = ? OR sn.id_zone IS NULL)
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

router.post('/sensors/change-controller', isUserAuthenticated, async (req, res) => {
  const { id_sensor_node, new_controller_id } = req.body;
  const db = await dbPromise;

  if (!id_sensor_node || !new_controller_id) {
    return res.status(400).json({ message: 'Missing id_sensor_node or new_controller_id' });
  }

  try {
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

    const [controllerRows] = await db.query(
      'SELECT id_greenhouse_controller FROM Greenhouse_controllers WHERE id_greenhouse_controller = ? AND id_user = ?',
      [new_controller_id, req.session.user.id]
    );

    if (controllerRows.length === 0) {
      return res.status(403).json({ message: 'Access denied: controller not found or not owned by user' });
    }

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


router.get('/zones', isUserAuthenticated, async (req, res) => {
  try {
    const userId = req.session.user.id;
    const greenhouseId = req.query.greenhouse_id;
    const db = await dbPromise;

    if (!greenhouseId) {
      return res.status(400).json({ message: 'greenhouse_id required' });
    }

    const [rows] = await db.query(`
      SELECT 
        z.id_zone,
        z.zone_name,
        z.id_greenhouse_controller,
        z.id_greenhouse,
        z.x,
        z.y,
        z.width,
        z.height,
        g.greenhouse_name
      FROM Zones z
      JOIN Greenhouses g ON z.id_greenhouse = g.id_greenhouse
      WHERE z.id_greenhouse = ? AND g.id_user = ?
      ORDER BY z.id_zone
    `, [greenhouseId, userId]);


    res.json({ zones: rows });
  } catch (err) {
    console.error('Error fetching zones:', err);
    res.status(500).json({ message: 'Server error' });
  }
});


router.get('/greenhouses/:controllerId/zones', isUserAuthenticated, async (req, res) => {
  const { controllerId } = req.params;

  try {
    const db = await dbPromise;

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

router.get('/unassigned', isUserAuthenticated, async (req, res) => {
  try {
    const db = await dbPromise;
    const [rows] = await db.query(
      'SELECT device_id FROM Greenhouse_controllers WHERE id_user IS NULL'
    );

    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/assign', isUserAuthenticated, async (req, res) => {
  const { device_id } = req.body;
  if (!device_id) return res.status(400).json({ message: 'device_id required' });

  try {
    const db = await dbPromise;

    const [rows] = await db.query(
      'SELECT * FROM Greenhouse_controllers WHERE device_id = ? AND id_user IS NULL',
      [device_id]
    );

    if (rows.length === 0) return res.status(400).json({ message: 'Device not available' });

    await db.query(
      'UPDATE Greenhouse_controllers SET id_user = ? WHERE device_id = ?',
      [req.session.user.id, device_id]
    );

    const token = jwt.sign({ device_id, user_id: req.session.user.id }, process.env.JWT_SECRET, { expiresIn: '30d' });

    res.json({ message: 'Device assigned', token });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});


router.get('/sensors/unassigned', isUserAuthenticated, async (req, res) => {
  try {
    const db = await dbPromise;
    const userId = req.session.user.id;

    const [rows] = await db.query(`
      SELECT
        sn.id_sensor_node,
        sn.sensor_node_name,
        sn.id_greenhouse_controller
      FROM Sensor_nodes sn
      JOIN Greenhouse_controllers gc
        ON gc.id_greenhouse_controller = sn.id_greenhouse_controller
      WHERE sn.id_zone IS NULL
        AND gc.id_user = ?
      ORDER BY sn.id_sensor_node
    `, [userId]);

    res.json(rows);
  } catch (err) {
    console.error('Error fetching unassigned sensors:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/greenhouses', isUserAuthenticated, async (req, res) => {
  const { greenhouse_name, description } = req.body;

  if (!greenhouse_name || greenhouse_name.trim() === '') {
    return res.status(400).json({ message: 'Nazwa szklarni jest wymagana' });
  }

  try {
    const db = await dbPromise;

    const [result] = await db.query(
      'INSERT INTO Greenhouses (greenhouse_name, description, id_user) VALUES (?, ?, ?)',
      [greenhouse_name, description || null, req.session.user.id]
    );

    const [controllerResult] = await db.query(
      'INSERT INTO Greenhouse_controllers (id_user) VALUES (?)',
      [req.session.user.id]
    );

    res.status(201).json({
      message: 'Szklarnia utworzona',
      greenhouse: {
        id_greenhouse: result.insertId,
        greenhouse_name,
        description: description || null,
        id_user: req.session.user.id
      },
      controller: {
        id_greenhouse_controller: controllerResult.insertId
      }
    });
  } catch (err) {
    console.error('Error creating greenhouse:', err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});

router.get('/greenhouses', isUserAuthenticated, async (req, res) => {
  try {
    const db = await dbPromise;

    const [greenhouses] = await db.query(
      'SELECT * FROM Greenhouses WHERE id_user = ?',
      [req.session.user.id]
    );

    res.json({ greenhouses });
  } catch (err) {
    console.error('Error fetching greenhouses:', err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});




router.post('/sensors/assign-zone', isUserAuthenticated, async (req, res) => {
  const { id_sensor_node, id_zone } = req.body;
  const db = await dbPromise;

  if (!id_sensor_node || !id_zone) {
    return res.status(400).json({ message: 'id_sensor_node i id_zone wymagane' });
  }

  try {
  
    const [zoneRows] = await db.query(`
      SELECT z.id_zone, z.x, z.y, z.width, z.height
      FROM Zones z
      JOIN Greenhouses g ON z.id_greenhouse = g.id_greenhouse
      WHERE z.id_zone = ? AND g.id_user = ?
    `, [id_zone, req.session.user.id]);

    if (zoneRows.length === 0) {
      return res.status(403).json({ message: 'Strefa nie należy do użytkownika' });
    }

    const zone = zoneRows[0];


    const centerX = zone.x + zone.width / 2;
    const centerY = zone.y + zone.height / 2;

    
    await db.query(
      'UPDATE Sensor_nodes SET id_zone = ?, x = ?, y = ? WHERE id_sensor_node = ?',
      [id_zone, Math.round(centerX), Math.round(centerY), id_sensor_node]
    );

    res.json({
      message: 'Sensor przypisany do strefy i ustawiony w jej środku',
      id_sensor_node,
      id_zone,
      x: Math.round(centerX),
      y: Math.round(centerY)
    });
  } catch (err) {
    console.error('Error assigning sensor to zone:', err);
    res.status(500).json({ message: 'Server error' });
  }
});


router.post('/zones', isUserAuthenticated, async (req, res) => {
  const { zone_name, greenhouse_id, x, y, width, height } = req.body;

  if (!zone_name || !greenhouse_id) {
    return res.status(400).json({ message: 'zone_name i greenhouse_id są wymagane' });
  }

  try {
    const db = await dbPromise;

    const [greenhouseRows] = await db.query(
      'SELECT id_user FROM Greenhouses WHERE id_greenhouse = ?',
      [greenhouse_id]
    );

    if (greenhouseRows.length === 0) {
      return res.status(404).json({ message: 'Szklarnia nie istnieje' });
    }

    if (greenhouseRows[0].id_user !== req.session.user.id) {
      return res.status(403).json({ message: 'Dostęp zabroniony: nie jesteś właścicielem szklarni' });
    }


    const [result] = await db.query(
      `INSERT INTO Zones 
       (zone_name, id_greenhouse, x, y, width, height, id_greenhouse_controller) 
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        zone_name,
        greenhouse_id,
        x ?? 50,
        y ?? 50,
        width ?? 50,
        height ?? 50,
        null
      ]
    );

    res.status(201).json({
      message: 'Strefa utworzona',
      zone: {
        id_zone: result.insertId,
        zone_name,
        id_greenhouse: greenhouse_id,
        x: x ?? 50,
        y: y ?? 50,
        width: width ?? 50,
        height: height ?? 50,
        id_greenhouse_controller: null
      }
    });
  } catch (err) {
    console.error('Błąd tworzenia strefy:', err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});


router.get('/zones/all', isUserAuthenticated, async (req, res) => {
  try {
    const userId = req.session.user.id;
    const db = await dbPromise;

    const [rows] = await db.query(`
      SELECT 
        z.id_zone,
        z.zone_name,
        z.id_greenhouse,
        g.greenhouse_name
      FROM Zones z
      JOIN Greenhouses g ON z.id_greenhouse = g.id_greenhouse
      WHERE g.id_user = ?
      ORDER BY g.id_greenhouse, z.id_zone
    `, [userId]);

    res.json({ zones: rows });
  } catch (err) {
    console.error('Error fetching all user zones:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/:id/sensors/all', isUserAuthenticated, async (req, res) => {
  const greenhouseId = req.params.id;
  try {
    const db = await dbPromise;

    const [check] = await db.query(
      `SELECT id_greenhouse
       FROM Greenhouses
       WHERE id_greenhouse = ? AND id_user = ?`,
      [greenhouseId, req.session.user.id]
    );

    if (check.length === 0) return res.status(403).json({ message: 'Access denied' });

    const [sensors] = await db.query(`
      SELECT
      sn.id_sensor_node,
      sn.sensor_node_name,
      sn.x,
      sn.y,
      (SELECT temperature
      FROM htl_logs
      WHERE id_sensor_node = sn.id_sensor_node
      ORDER BY log_time DESC
      LIMIT 1) AS temperature,
      (SELECT humidity
      FROM htl_logs
      WHERE id_sensor_node = sn.id_sensor_node
      ORDER BY log_time DESC
      LIMIT 1) AS humidity,
      (SELECT light
      FROM htl_logs
      WHERE id_sensor_node = sn.id_sensor_node
      ORDER BY log_time DESC
      LIMIT 1) AS light
    FROM Sensor_nodes sn
    JOIN Zones z ON sn.id_zone = z.id_zone
    WHERE z.id_greenhouse = ?
    ORDER BY sn.id_sensor_node

    `, [greenhouseId]);

    res.json(sensors);
  } catch (err) {
    console.error('Error fetching all sensors for greenhouse:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

router.delete('/zones/:zoneId', isUserAuthenticated, async (req, res) => {
  const { zoneId } = req.params;
  const db = await dbPromise;

  try {
    const [zoneRows] = await db.query(`
      SELECT z.id_zone
      FROM Zones z
      JOIN Greenhouses g ON z.id_greenhouse = g.id_greenhouse
      WHERE z.id_zone = ? AND g.id_user = ?
    `, [zoneId, req.session.user.id]);

    if (zoneRows.length === 0) {
      return res.status(403).json({ message: 'Dostęp zabroniony: strefa nie należy do użytkownika' });
    }

  
    await db.query(`
      UPDATE Sensor_nodes
      SET id_zone = NULL
      WHERE id_zone = ?
    `, [zoneId]);

  
    await db.query(`
      UPDATE End_devices
      SET id_zone = NULL
      WHERE id_zone = ?
    `, [zoneId]);

  
    await db.query(`
      DELETE FROM Zones
      WHERE id_zone = ?
    `, [zoneId]);

    res.json({ message: 'Strefa usunięta, powiązane sensory i urządzenia odpięte', id_zone: zoneId });
  } catch (err) {
    console.error('Error deleting zone:', err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});

router.get('/:greenhouseId/end-devices', isUserAuthenticated, async (req, res) => {
  const { greenhouseId } = req.params;
  const db = await dbPromise;

  try {
    const [rows] = await db.query(`
      SELECT *
      FROM End_devices
      WHERE id_zone IN (
        SELECT id_zone FROM Zones WHERE id_greenhouse = ?
      )
    `, [greenhouseId]);

    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/end-devices/position', isUserAuthenticated, async (req, res) => {
  const { id_end_device, x, y } = req.body;
  const db = await dbPromise;

  if (!id_end_device || x === undefined || y === undefined) {
    return res.status(400).json({ message: 'Missing id_end_device, x or y' });
  }

  try {
    const [rows] = await db.query(
      `
      SELECT ed.id_end_device
      FROM End_devices ed
      LEFT JOIN Zones z ON ed.id_zone = z.id_zone
      LEFT JOIN Greenhouses g ON z.id_greenhouse = g.id_greenhouse
      WHERE ed.id_end_device = ?
        AND g.id_user = ?
      `,
      [id_end_device, req.session.user.id]
    );

    if (rows.length === 0) {
      return res.status(403).json({ message: 'Access denied' });
    }

    await db.query(
      `
      UPDATE End_devices
      SET x = ?, y = ?
      WHERE id_end_device = ?
      `,
      [Math.round(x), Math.round(y), id_end_device]
    );

    res.json({
      message: 'End device position saved',
      id_end_device,
      x,
      y,
    });
  } catch (err) {
    console.error('Error saving end device position:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/greenhouse/:id/controllers', isUserAuthenticated, async (req, res) => {
  const greenhouseId = req.params.id;
  const userId = req.session.user.id;
  const db = await dbPromise;

  const [rows] = await db.query(
    `SELECT id_greenhouse_controller, device_id, device_token
     FROM Greenhouse_controllers
     WHERE id_user = ? AND is_active = 1`,
    [userId]
  );

  res.json(rows);
});

router.post('/zones/:id/assign-controller', isUserAuthenticated, async (req, res) => {
  const zoneId = req.params.id;
  const { controller_id } = req.body;
  const db = await dbPromise;

  try {
    await db.query(
      `UPDATE Zones SET id_greenhouse_controller = ? WHERE id_zone = ?`,
      [controller_id, zoneId]
    );
    res.status(200).json({ message: 'Strefa przypisana do kontrolera' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Błąd serwera' });
  }
});

router.get('/end-devices/unassigned', isUserAuthenticated, async (req, res) => {
  try {
    const db = await dbPromise;
    const userId = req.session.user.id;

    const [rows] = await db.query(`
      SELECT
        ed.id_end_device,
        ed.end_device_name,
        ed.id_greenhouse_controller
      FROM End_devices ed
      JOIN Greenhouse_controllers gc
        ON gc.id_greenhouse_controller = ed.id_greenhouse_controller
      WHERE ed.id_zone IS NULL
        AND gc.id_user = ?
      ORDER BY ed.id_end_device
    `, [userId]);

    res.json(rows);
  } catch (err) {
    console.error('Error fetching unassigned end devices:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/end-devices/assign-zone', isUserAuthenticated, async (req, res) => {
  const { id_end_device, id_zone } = req.body;
  const db = await dbPromise;

  if (!id_end_device || !id_zone) {
    return res.status(400).json({ message: 'id_end_device i id_zone wymagane' });
  }

  try {
    const [[zone]] = await db.query(`
      SELECT 
        z.id_zone,
        z.x,
        z.y,
        z.width,
        z.height
      FROM Zones z
      JOIN Greenhouses g ON z.id_greenhouse = g.id_greenhouse
      WHERE z.id_zone = ? AND g.id_user = ?
    `, [id_zone, req.session.user.id]);

    if (!zone) {
      return res.status(403).json({ message: 'Strefa nie należy do użytkownika' });
    }

    const deviceX = Math.round(zone.x + zone.width / 2);
    const deviceY = Math.round(zone.y + zone.height / 2);

    await db.query(`
      UPDATE End_devices
      SET 
        id_zone = ?,
        x = ?,
        y = ?
      WHERE id_end_device = ?
    `, [id_zone, deviceX, deviceY, id_end_device]);

    res.json({
      message: 'End device przypisany do strefy',
      id_end_device,
      id_zone,
      x: deviceX,
      y: deviceY
    });
  } catch (err) {
    console.error('Error assigning end device to zone:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/end-devices/update-params', isUserAuthenticated, async (req, res) => {
  const {
    id_end_device,
    up_temp,
    down_temp,
    up_hum,
    down_hum,
    up_light,
    down_light
  } = req.body;

  const db = await dbPromise;

  if (!id_end_device) {
    return res.status(400).json({ message: 'id_end_device required' });
  }

  try {
   
    const [rows] = await db.query(`
      SELECT ed.id_end_device
      FROM End_devices ed
      JOIN Zones z ON ed.id_zone = z.id_zone
      JOIN Greenhouses g ON z.id_greenhouse = g.id_greenhouse
      WHERE ed.id_end_device = ?
        AND g.id_user = ?
    `, [id_end_device, req.session.user.id]);

    if (rows.length === 0) {
      return res.status(403).json({ message: 'Access denied' });
    }

    await db.query(`
      UPDATE End_devices
      SET
        up_temp = ?,
        down_temp = ?,
        up_hum = ?,
        down_hum = ?,
        up_light = ?,
        down_light = ?
      WHERE id_end_device = ?
    `, [
      up_temp ?? null,
      down_temp ?? null,
      up_hum ?? null,
      down_hum ?? null,
      up_light ?? null,
      down_light ?? null,
      id_end_device
    ]);

    res.json({ message: 'End device parameters updated' });
  } catch (err) {
    console.error('Error updating end device params:', err);
    res.status(500).json({ message: 'Server error' });
  }
});


module.exports = router;

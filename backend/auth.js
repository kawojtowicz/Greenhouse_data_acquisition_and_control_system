const session = require('express-session');
const bcrypt = require('bcryptjs');
const dbPromise = require('./db');
const jwt = require('jsonwebtoken');
require('dotenv').config();
const JWT_SECRET = process.env.JWT_SECRET;


function isUserAuthenticated(req, res, next) {
    if (req.session && req.session.user) {
        next();
    } else {
        res.status(401).json({ message: 'Access denied. Please log in.' });
    }
}

function authenticateUser(req, id, username, firstName, lastName, email) {
    req.session.user = { id, username, firstName, lastName, email };
}

async function authenticateDevice(req, res, next) {
  const authHeader = req.headers['authorization'] || req.headers['Authorization'];
  if (!authHeader) return res.status(401).json({ message: 'Token required' });

  const token = authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ message: 'Token required' });

  try {
    const db = await dbPromise;

    const [rows] = await db.query(
      'SELECT * FROM Greenhouse_controllers WHERE device_token = ?',
      [token]
    );

    if (rows.length === 0) return res.status(403).json({ message: 'Invalid token' });

    req.device = rows[0];
    next();
  } catch (err) {
    console.error(err);
    return res.status(403).json({ message: 'Invalid token' });
  }
}



module.exports = { isUserAuthenticated, authenticateUser, authenticateDevice };

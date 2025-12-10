const session = require('express-session');
const bcrypt = require('bcryptjs');
const { withConnection } = require('./db');

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

module.exports = { isUserAuthenticated, authenticateUser };

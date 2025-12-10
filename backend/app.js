const express = require('express');
const session = require('express-session');
const app = express();
const port = 3000;

app.use((req, res, next) => {
  console.log(
    `[${new Date().toISOString()}] Request from ${req.ip}:${req.connection.remotePort} - ${req.method} ${req.url}`
  );
  next();
});

const cors = require('cors');
app.use(cors());


app.use(express.json());

app.use(session({
  secret: process.env.SESSION_SECRET || 'default_secret',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: false,
    httpOnly: true,
    maxAge: 1000 * 60 * 60 * 24
  }
}));

const usersRoutes = require('./routes/users');
const controllersRoutes = require('./routes/greenhouse_controllers');
const sensorNodesRoutes = require('./routes/sensor_nodes');
const logsRoutes = require('./routes/htl_logs');
const fansRoutes = require('./routes/fans');
const actuatorsRoutes = require('./routes/actuators');
const heatersRoutes = require('./routes/heaters');
const wateringPumpsRoutes = require('./routes/watering_pumps');

app.use('/users', usersRoutes);
app.use('/greenhouse-controllers', controllersRoutes);
app.use('/sensor-nodes', sensorNodesRoutes);
app.use('/htl-logs', logsRoutes);
app.use('/fans', fansRoutes);
app.use('/actuators', actuatorsRoutes);
app.use('/heaters', heatersRoutes);
app.use('/watering-pumps', wateringPumpsRoutes);

app.get('/', (req, res) => {
  res.json({ message: 'Server is running! Use /htl-logs for logs.' });
});

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});

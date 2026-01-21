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

const admin = require('firebase-admin');
require('./services/zone_alarms');

const firebaseConfig = {
  projectId: process.env.FIREBASE_PROJECT_ID,
  clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
  privateKey: process.env.FIREBASE_PRIVATE_KEY ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n') : undefined,
};

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(firebaseConfig)
  });
  console.log("✅ Firebase Admin zainicjalizowany poprawnie.");
}



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
const devicesRoutes = require('./routes/devices');

app.use('/users', usersRoutes);
app.use('/greenhouse-controllers', controllersRoutes);
app.use('/sensor-nodes', sensorNodesRoutes);
app.use('/htl-logs', logsRoutes);
app.use('/devices', devicesRoutes);

app.use((req, res, next) => {
  console.log("===== INCOMING REQUEST =====");
  console.log("Method:", req.method);
  console.log("URL:", req.originalUrl);
  console.log("Headers:", req.headers);
  console.log("IP:", req.ip);
  console.log("User-Agent:", req.headers['user-agent']);
  console.log("============================");
  next();
});


app.get('/ping', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});


app.get('/', (req, res) => {
  res.json({ message: 'Server is running! Use /htl-logs for logs.' });
});

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});

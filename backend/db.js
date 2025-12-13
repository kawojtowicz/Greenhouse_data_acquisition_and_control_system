
const mysql = require('mysql2/promise');

const connectWithRetry = async () => {
  while (true) {
    try {
      const pool = mysql.createPool({
        host: 'greenhouse_db',
        user: 'root',
        password: 'example',
        database: 'greenhouse_data_base',
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0
      });

      await pool.query('SELECT 1');
      console.log('Connected to MySQL database');
      return pool;
    } catch (err) {
      console.log('Waiting for MySQL to be ready... retrying in 5 seconds');
      await new Promise(res => setTimeout(res, 5000));
    }
  }
};

const dbPromise = connectWithRetry();

module.exports = dbPromise;


// docker exec -it greenhouse_db mysql -u root -p    
const db = require('../db');
const { sendAlarmNotification } = require('./push'); // FCM

async function checkOneAlarm({
  zone,
  alarm,
  value,
  min,
  max,
  delay,
  type,
  user
}) {
  if (value === null || value === undefined) return;

  const now = new Date();

  const broken =
    (min !== null && value < min) ||
    (max !== null && value > max);

  if (!broken) {
    if (alarm.active) {
      await db.query(`
        UPDATE Zone_alarm_states
        SET ${type}_alarm_active = FALSE,
            ${type}_alarm_since = NULL
        WHERE id_zone = $1
      `, [zone.id_zone]);
    }
    return;
  }

  if (!alarm.active) {
    await db.query(`
      UPDATE Zone_alarm_states
      SET ${type}_alarm_active = TRUE,
          ${type}_alarm_since = $2
      WHERE id_zone = $1
    `, [zone.id_zone, now]);
    return;
  }

  const duration = (now - alarm.since) / 1000;
  if (duration < delay) return;

  await sendAlarmNotification({
    user,
    zoneName: zone.zone_name,
    type,
    value
  });
}

async function checkZoneAlarms(sensorNodeId, log) {
  const { rows } = await db.query(`
    SELECT 
      z.*,
      zas.temp_alarm_active, zas.temp_alarm_since,
      zas.hum_alarm_active, zas.hum_alarm_since,
      zas.light_alarm_active, zas.light_alarm_since,
      u.id_user, u.fcm_token
    FROM Sensor_nodes sn
    JOIN Zones z ON sn.id_zone = z.id_zone
    JOIN Greenhouses g ON z.id_greenhouse = g.id_greenhouse
    JOIN Users u ON g.id_user = u.id_user
    LEFT JOIN Zone_alarm_states zas ON zas.id_zone = z.id_zone
    WHERE sn.id_sensor_node = $1
  `, [sensorNodeId]);

  if (rows.length === 0) return;

  const zone = rows[0];
  const user = rows[0];

  await checkOneAlarm({
    zone,
    alarm: { active: zone.temp_alarm_active, since: zone.temp_alarm_since },
    value: log.temperature,
    min: zone.min_temp,
    max: zone.max_temp,
    delay: zone.temp_alarm_delay_seconds,
    type: 'temp',
    user
  });

  await checkOneAlarm({
    zone,
    alarm: { active: zone.hum_alarm_active, since: zone.hum_alarm_since },
    value: log.humidity,
    min: zone.min_hum,
    max: zone.max_hum,
    delay: zone.hum_alarm_delay_seconds,
    type: 'hum',
    user
  });

  await checkOneAlarm({
    zone,
    alarm: { active: zone.light_alarm_active, since: zone.light_alarm_since },
    value: log.light,
    min: zone.min_light,
    max: zone.max_light,
    delay: zone.light_alarm_delay_seconds,
    type: 'light',
    user
  });
}

module.exports = { checkZoneAlarms };

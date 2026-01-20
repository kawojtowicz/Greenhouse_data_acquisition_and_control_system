const admin = require('firebase-admin');
const { alarmText } = require('services/notifications');

async function sendAlarmNotification({ user, zoneName, type, value }) {
  if (!user.fcm_token) return;

  await admin.messaging().send({
    token: user.fcm_token,
    notification: {
      title: `⚠️ Alarm – ${zoneName}`,
      body: alarmText(type, value)
    },
    data: {
      type: 'ALARM',
      zone: zoneName,
      metric: type
    }
  });
}

module.exports = { sendAlarmNotification };

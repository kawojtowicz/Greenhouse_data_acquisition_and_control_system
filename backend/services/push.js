const admin = require('firebase-admin');
const { alarmText } = require('./notifications');

// async function sendAlarmNotification({ user, zoneName, type, value }) {
//   if (!user.fcm_token) return;

//   await admin.messaging().send({
//     token: user.fcm_token,
//     notification: {
//       title: `⚠️ Alarm – ${zoneName}`,
//       body: alarmText(type, value)
//     },
//     data: {
//       type: 'ALARM',
//       zone: zoneName,
//       metric: type
//     }
//   });
// }

async function sendAlarmNotification({ user, zoneName, type, value }) {
  if (!user.fcm_token) return;

  try {
    const messageId = await admin.messaging().send({
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

    console.log(`Powiadomienie wysłane! messageId: ${messageId}`);
    return messageId;

  } catch (err) {
    console.error('Błąd przy wysyłaniu powiadomienia:', err);
    throw err;
  }
}


module.exports = { sendAlarmNotification };

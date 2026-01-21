const admin = require('firebase-admin');
const { alarmText } = require('./notifications');
require('dotenv').config();

if (!process.env.FIREBASE_PROJECT_ID) {
    console.error("UWAGA: Brak FIREBASE_PROJECT_ID w zmiennych środowiskowych!");
}

if (admin.apps.length === 0) {
    try {
        admin.initializeApp({
            credential: admin.credential.cert({
                projectId: process.env.FIREBASE_PROJECT_ID,
                clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
                privateKey: process.env.FIREBASE_PRIVATE_KEY ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n') : undefined,
            }),
        });
        console.log("Firebase Admin zainicjalizowany poprawnie.");
    } catch (error) {
        console.error("Błąd podczas inicjalizacji Firebase Admin:", error);
    }
}

async function sendAlarmNotification({ user, zoneName, type, value }) {
    if (!user.fcm_token) {
        console.log("Brak tokenu FCM dla użytkownika, pomijam wysyłkę.");
        return;
    }

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

        console.log(`🚀 Powiadomienie wysłane! ID: ${messageId}`);
        return messageId;
    } catch (err) {
        console.error('❌ Błąd FCM:', err);
        throw err;
    }
}

module.exports = { sendAlarmNotification };
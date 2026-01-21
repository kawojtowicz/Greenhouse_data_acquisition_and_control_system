import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  static final _fcm = FirebaseMessaging.instance;

  static Future<String?> getToken() async {
    await _fcm.requestPermission();
    return await _fcm.getToken();
  }
}

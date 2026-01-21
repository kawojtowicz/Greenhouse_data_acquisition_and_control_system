// import 'dart:io';
// import 'dart:convert';
// import 'dart:typed_data';

// class SmartConfigService {
//   static const int port = 7001;

//   static Future<void> send({
//     required String ssid,
//     required String password,
//   }) async {
//     final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

//     socket.broadcastEnabled = true;

//     final payload = utf8.encode('$ssid\x00$password');
//     final data = Uint8List.fromList(payload);

//     for (int i = 0; i < 60; i++) {
//       socket.send(data, InternetAddress('255.255.255.255'), port);
//       await Future.delayed(const Duration(milliseconds: 120));
//     }

//     socket.close();
//   }
// }

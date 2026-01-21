import 'package:flutter/material.dart';
import 'pages/auth_page.dart';
import '../services/dio_client.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await DioClient().init();
  runApp(const MyApp());
}

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await DioClient().init();
//   runApp(const MyApp());
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Greenhouse App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 38, 182, 204),
        ),
      ),
      home: const AuthPage(),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

// import 'pages/auth_page.dart';
// import '../services/dio_client.dart';

// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   await Firebase.initializeApp();
//   await DioClient().init();

//   runApp(const MyApp());

//   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//     final notif = message.notification;
//     final context = navigatorKey.currentContext;

//     if (notif != null && context != null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.red,
//           content: Text(notif.body ?? '⚠️ Alarm'),
//         ),
//       );
//     }
//   });
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       navigatorKey: navigatorKey,
//       title: 'Greenhouse App',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: const Color.fromARGB(255, 38, 182, 204),
//         ),
//       ),
//       home: const AuthPage(),
//     );
//   }
// }

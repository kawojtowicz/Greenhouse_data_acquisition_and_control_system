import 'package:flutter/material.dart';
import 'pages/auth_page.dart';
import '../services/dio_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DioClient().init();
  runApp(const MyApp());
}

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

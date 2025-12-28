import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  final Dio dio;

  AuthService(this.dio);

  Future<User?> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Wprowadź adres e-mail użytkownika i hasło');
    }

    final loginResponse = await dio.post(
      'http://192.168.0.101:3000/users/login',
      data: jsonEncode({'email': email, 'password': password}),
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (loginResponse.statusCode == 200) {
      final userResponse = await dio.get(
        'http://192.168.0.101:3000/users',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (userResponse.statusCode == 200) {
        final userData = userResponse.data;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('id', userData['id']);
        await prefs.setString('email', userData['email']);
        await prefs.setString('name', userData['name']);
        await prefs.setString('lastName', userData['lastName']);

        return User(
          id: userData['id'],
          email: userData['email'],
          name: userData['name'],
          lastName: userData['lastName'],
        );
      } else {
        throw Exception('Błąd podczas pobierania danych użytkownika');
      }
    } else {
      throw Exception('Niepoprawne dane logowania');
    }
  }

  Future<User?> register({
    required String email,
    required String password,
    required String name,
    required String lastName,
  }) async {
    final response = await dio.post(
      'http://192.168.0.101:3000/users',
      data: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        'last_name': lastName,
      }),
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return await login(email, password);
    } else if (response.statusCode == 400) {
      throw Exception('Złe dane: ${response.data}');
    } else {
      throw Exception('Błąd rejestracji: ${response.statusCode}');
    }
  }
}

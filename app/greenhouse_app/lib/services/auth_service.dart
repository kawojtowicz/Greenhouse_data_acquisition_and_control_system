import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  final Dio dio;
  final String baseUrl;

  AuthService(
    this.dio, {
    this.baseUrl =
        'https://greenhouse-data-acquisition-and-control.onrender.com',
  });

  Future<User?> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Podaj email i hasło');
    }

    try {
      final loginResponse = await dio.post(
        '$baseUrl/users/login',
        data: {'email': email, 'password': password},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (loginResponse.statusCode == 200) {
        final userResponse = await dio.get(
          '$baseUrl/users',
          options: Options(headers: {'Content-Type': 'application/json'}),
        );

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
      }

      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Błędne hasło');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Użytkownik nie istnieje');
      }
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Brak połączenia z serwerem');
      }

      throw Exception('Błąd logowania');
    }
  }

  Future<User?> register({
    required String email,
    required String password,
    required String name,
    required String lastName,
  }) async {
    final response = await dio.post(
      '$baseUrl/users',
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

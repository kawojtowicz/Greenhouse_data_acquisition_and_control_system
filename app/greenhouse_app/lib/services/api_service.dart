import 'package:dio/dio.dart';
import '../models/user.dart';
import 'package:flutter/material.dart';
import 'dio_client.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/greenhouse_controller.dart';

class ApiService {
  final Dio dio;

  ApiService() : dio = DioClient().dio;

  Future<bool> logoutUser(BuildContext context) async {
    try {
      final response = await dio.delete(
        'http://192.168.0.101:3000/users',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();

        // await prefs.remove('accessToken');
        // await prefs.remove('refreshToken');
        await prefs.remove('id');
        await prefs.remove('email');
        await prefs.remove('name');
        await prefs.remove('lastName');

        await DioClient().getCookieJar().deleteAll();

        Provider.of<UserProvider>(context, listen: false).clearUser();

        print('Dane użytkownika wyczyszczone');
        return true;
      } else {
        print('Logout failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Logout error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchUserData() async {
    try {
      final response = await dio.get(
        'http://192.168.0.101:3000/users',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print('fetchUserData error: $e');
    }
    return null;
  }

  Future<List<GreenhouseController>> fetchUserSensorNodes() async {
    try {
      final response = await dio.get('http://192.168.0.101:3000/users/sensors');
      print('Status code: ${response.statusCode}');
      print('Response data: ${response.data}');

      if (response.statusCode == 200) {
        final List data = response.data['controllers'];
        print('Controllers data: $data');
        return data.map((c) => GreenhouseController.fromJson(c)).toList();
      } else {
        print('Unexpected status code: ${response.statusCode}');
      }
    } catch (e, stack) {
      print('fetchUserSensors error: $e');
      print(stack);
    }
    return [];
  }

  Future<bool> updateGreenhouseTemperature(
    int greenhouseId,
    double temperature,
  ) async {
    try {
      final response = await dio.post(
        'http://192.168.0.101:3000/users/$greenhouseId/temperature',
        data: {'temperature_set': temperature},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Temperatura zaktualizowana: ${response.data}');
        return true;
      } else {
        print('Błąd aktualizacji temperatury: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('updateGreenhouseTemperature error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchLastHTLLogs(int greenhouseId) async {
    try {
      final response = await dio.get(
        'http://192.168.0.101:3000/users/$greenhouseId/last-log',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      print("DEBUG last-log response: ${response.data}"); // DODAJ TO

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }

        if (data is Map && data['logs'] is List) {
          return List<Map<String, dynamic>>.from(data['logs']);
        }

        if (data is Map) {
          return [Map<String, dynamic>.from(data)];
        }
      }
    } catch (e) {
      print('fetchLastHTLLogs error: $e');
    }
    return [];
  }
}

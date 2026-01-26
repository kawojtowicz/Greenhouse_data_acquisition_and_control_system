import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dio_client.dart';
import '../providers/user_provider.dart';
import '../models/greenhouse_controller.dart';
import '../models/discovered_device.dart';
import '../models/sensor_node.dart';
import '../models/greenhouse.dart';
import '../models/zone.dart';
import '../models/end_device.dart';

class ApiService {
  final Dio dio = DioClient().dio;
  final String baseUrl =
      // 'https://greenhouse-data-acquisition-and-control.onrender.com';
      'https://backend-floral-fog-9850.fly.dev';

  Future<bool> logoutUser(BuildContext context) async {
    try {
      final response = await dio.delete(
        '$baseUrl/users',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
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
        '$baseUrl/users',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 200) return response.data;
    } catch (e) {
      print('fetchUserData error: $e');
    }
    return null;
  }

  Future<List<GreenhouseController>> fetchUserSensorNodes() async {
    try {
      final response = await dio.get('$baseUrl/users/sensors');
      if (response.statusCode == 200) {
        final List data = response.data['controllers'];
        return data.map((c) => GreenhouseController.fromJson(c)).toList();
      }
    } catch (e) {
      print('fetchUserSensorNodes error: $e');
    }
    return [];
  }

  Future<void> saveSensorPosition(int sensorId, double x, double y) async {
    try {
      await dio.post(
        '$baseUrl/users/sensors/position',
        data: {'id_sensor_node': sensorId, 'x': x, 'y': y},
      );
    } catch (e) {
      print('saveSensorPosition error: $e');
    }
  }

  Future<Map<String, dynamic>> addGreenhouse(
    String name, [
    String? description,
  ]) async {
    try {
      final response = await dio.post(
        '$baseUrl/users/greenhouses',
        data: {
          'greenhouse_name': name,
          if (description != null) 'description': description,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 201) return response.data['greenhouse'];
      throw Exception(
        'Nie udało się utworzyć szklarni. Status: ${response.statusCode}',
      );
    } catch (e) {
      print('addGreenhouse error: $e');
      rethrow;
    }
  }

  Future<void> changeSensorGreenhouse(int sensorId, int newGreenhouseId) async {
    try {
      await dio.post(
        '$baseUrl/users/sensors/change-controller',
        data: {
          'id_sensor_node': sensorId,
          'new_controller_id': newGreenhouseId,
        },
      );
    } catch (e) {
      print('changeSensorGreenhouse error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchLastHTLLogs(int greenhouseId) async {
    try {
      final response = await dio.get(
        '$baseUrl/users/$greenhouseId/last-log',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) return List<Map<String, dynamic>>.from(data);
        if (data is Map && data['logs'] is List)
          return List<Map<String, dynamic>>.from(data['logs']);
        if (data is Map) return [Map<String, dynamic>.from(data)];
      }
    } catch (e) {
      print('fetchLastHTLLogs error: $e');
    }
    return [];
  }

  Future<List<DiscoveredDevice>> fetchDiscoveredDevices() async {
    try {
      final response = await dio.get('$baseUrl/users/unassigned');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((d) => DiscoveredDevice.fromJson(d))
            .toList();
      }
    } catch (e) {
      print('fetchDiscoveredDevices error: $e');
    }
    return [];
  }

  // Future<String?> assignDevice(String deviceId) async {
  //   try {
  //     final response = await dio.post(
  //       '$baseUrl/users/assign',
  //       data: {'device_id': deviceId},
  //       options: Options(headers: {'Content-Type': 'application/json'}),
  //     );
  //     if (response.statusCode == 200 && response.data['token'] != null) {
  //       return response.data['token'];
  //     }
  //   } catch (e) {
  //     print('assignDevice error: $e');
  //   }
  //   return null;
  // }

  Future<String?> assignDevice(String deviceId, String deviceToken) async {
    try {
      final response = await dio.post(
        '$baseUrl/users/assign',
        data: {'device_id': deviceId, 'device_token': deviceToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data['token'] != null) {
        return response.data['token'];
      }
    } catch (e) {
      print('assignDevice error: $e');
    }
    return null;
  }

  Future<List<SensorNode>> fetchUnassignedSensors() async {
    try {
      final response = await dio.get(
        '$baseUrl/users/sensors/unassigned',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => SensorNode.fromJson(e))
            .toList();
      }
    } catch (e) {
      print('fetchUnassignedSensors error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchAllUserZones() async {
    try {
      final response = await dio.get(
        '$baseUrl/users/zones/all',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data['zones'];
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('fetchAllUserZones error: $e');
    }
    return [];
  }

  Future<void> assignSensorToZone(int sensorId, int zoneId) async {
    try {
      await dio.post(
        '$baseUrl/users/sensors/assign-zone',
        data: {'id_sensor_node': sensorId, 'id_zone': zoneId},
      );
    } catch (e) {
      print('assignSensorToZone error: $e');
      throw e;
    }
  }

  Future<List<Greenhouse>> fetchUserGreenhouses() async {
    try {
      final response = await dio.get('$baseUrl/users/greenhouses');
      if (response.statusCode == 200) {
        final List data = response.data['greenhouses'];
        return data.map((g) => Greenhouse.fromJson(g)).toList();
      }
    } catch (e) {
      print('fetchUserGreenhouses error: $e');
    }
    return [];
  }

  Future<int?> createZone(
    int greenhouseId,
    String zoneName,
    double x,
    double y,
    double width,
    double height,
  ) async {
    try {
      final response = await dio.post(
        '$baseUrl/users/zones',
        data: {
          'greenhouse_id': greenhouseId,
          'zone_name': zoneName,
          'x': x.round(),
          'y': y.round(),
          'width': width.round(),
          'height': height.round(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['zone']['id_zone'];
      }
    } catch (e) {
      print('createZone error: $e');
    }

    return null;
  }

  Future<List<Zone>> fetchZonesWithSensors(int greenhouseId) async {
    try {
      final response = await dio.get(
        '$baseUrl/users/zones?greenhouse_id=$greenhouseId',
      );

      if (response.statusCode == 200) {
        final List data = response.data['zones'];
        return data.map((z) => Zone.fromJson(z)).toList();
      }
    } catch (e) {
      print('fetchZonesWithSensors error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchAllSensorsForGreenhouse(
    int greenhouseId,
  ) async {
    try {
      final response = await dio.get(
        '$baseUrl/users/$greenhouseId/sensors/all',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      print('fetchAllSensorsForGreenhouse error: $e');
    }
    return [];
  }

  Future<void> deleteZone(int zoneId) async {
    try {
      await dio.delete('$baseUrl/users/zones/$zoneId');
    } catch (e) {
      print('deleteZone error: $e');
      throw e;
    }
  }

  Future<List<EndDevice>> fetchEndDevices(int greenhouseId) async {
    try {
      final response = await dio.get(
        '$baseUrl/users/$greenhouseId/end-devices',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data is List) {
        final List data = response.data;
        return data.map((d) => EndDevice.fromJson(d)).toList();
      }
    } catch (e) {
      print('fetchEndDevices error: $e');
    }
    return [];
  }

  Future<void> saveEndDevicePosition(int id, double x, double y) async {
    try {
      await dio.post(
        '$baseUrl/users/end-devices/position',
        data: {'id_end_device': id, 'x': x, 'y': y},
      );
      print('End device position saved: $id at ($x, $y)');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        print('Endpoint not found. Check server URL.');
      } else if (e.response?.statusCode == 403) {
        print('Access denied.');
      } else {
        print('Error saving end device position: $e');
      }
    }
  }

  Future<List<GreenhouseController>> fetchControllers(int greenhouseId) async {
    try {
      final response = await dio.get(
        '$baseUrl/users/greenhouse/$greenhouseId/controllers',
      );
      print('fetchControllers response: ${response.data}');
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((c) => GreenhouseController.fromJson(c))
            .toList();
      }
    } catch (e) {
      print('fetchControllers error: $e');
    }
    return [];
  }

  Future<void> assignZoneToController({
    required int zoneId,
    required int controllerId,
  }) async {
    try {
      await dio.post(
        '$baseUrl/users/zones/$zoneId/assign-controller',
        data: {'controller_id': controllerId},
      );
    } catch (e) {
      print('assignZoneToController error: $e');
    }
  }

  Future<List<EndDevice>> fetchUnassignedEndDevices() async {
    try {
      final response = await dio.get('$baseUrl/users/end-devices/unassigned');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => EndDevice.fromJson(e))
            .toList();
      }
    } catch (e) {
      print('fetchUnassignedEndDevices error: $e');
    }
    return [];
  }

  Future<void> assignEndDeviceToZone(int endDeviceId, int zoneId) async {
    try {
      await dio.post(
        '$baseUrl/users/end-devices/assign-zone',
        data: {'id_end_device': endDeviceId, 'id_zone': zoneId},
      );
    } catch (e) {
      print('assignEndDeviceToZone error: $e');
      throw e;
    }
  }

  Future<void> updateEndDeviceParams({
    required int id,
    double? upTemp,
    double? downTemp,
    double? upHum,
    double? downHum,
    double? upLight,
    double? downLight,
  }) async {
    await dio.post(
      '$baseUrl/users/end-devices/update-params',
      data: {
        'id_end_device': id,
        'up_temp': upTemp,
        'down_temp': downTemp,
        'up_hum': upHum,
        'down_hum': downHum,
        'up_light': upLight,
        'down_light': downLight,
      },
    );
  }

  Future<void> deleteGreenhouse(int greenhouseId) async {
    try {
      await dio.delete(
        '$baseUrl/users/greenhouses/$greenhouseId',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
    } catch (e) {
      print('deleteGreenhouse error: $e');
      rethrow;
    }
  }

  Future<void> updateGreenhouseName(
    int greenhouseId,
    String newName, [
    String? description,
  ]) async {
    try {
      final response = await dio.post(
        '$baseUrl/users/greenhouses/update',
        data: {
          'id_greenhouse': greenhouseId,
          'new_name': newName,
          if (description != null) 'description': description,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        print('Nazwa szklarni zaktualizowana na: $newName');
      } else {
        print(
          'Nie udało się zaktualizować nazwy szklarni. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('updateGreenhouseName error: $e');
      rethrow;
    }
  }

  Future<void> unassignSensorFromZone(int sensorId) async {
    try {
      await dio.post(
        '$baseUrl/users/sensors/unassign-zone',
        data: {'id_sensor_node': sensorId},
      );
    } catch (e) {
      print('Error unassigning sensor: $e');
      throw e;
    }
  }

  Future<void> unassignEndDeviceFromZone(int endDeviceId) async {
    try {
      await dio.post(
        '$baseUrl/users/end-devices/unassign-zone',
        data: {'id_end_device': endDeviceId},
      );
    } catch (e) {
      print('Error unassigning end device: $e');
      throw e;
    }
  }

  Future<void> updateSensorName(int id, String newName) async {
    await dio.post(
      '$baseUrl/users/sensors/update-name',
      data: {'id_sensor_node': id, 'new_name': newName},
    );
  }

  Future<void> updateEndDeviceName(int id, String newName) async {
    await dio.post(
      '$baseUrl/users/end-devices/update-name',
      data: {'id_end_device': id, 'new_name': newName},
    );
  }

  Future<void> deleteSensor(int sensorId) async {
    try {
      await dio.delete('$baseUrl/users/sensors/$sensorId');
    } catch (e) {
      print('deleteSensor error: $e');
      rethrow;
    }
  }

  Future<void> deleteEndDevice(int endDeviceId) async {
    try {
      await dio.delete('$baseUrl/users/end-devices/$endDeviceId');
    } catch (e) {
      print('deleteEndDevice error: $e');
      rethrow;
    }
  }

  Future<List<Greenhouse>> fetchGreenhousesWithZones() async {
    try {
      List<Greenhouse> greenhouses = await fetchUserGreenhouses();

      for (var gh in greenhouses) {
        final response = await dio.get(
          '$baseUrl/users/greenhouses/${gh.id}/zones',
        );

        if (response.statusCode == 200) {
          gh.zones = (response.data['zones'] as List)
              .map((z) => Zone.fromJson(z))
              .toList();
        }
      }

      return greenhouses;
    } catch (e) {
      print("Błąd fetchGreenhousesWithZones: $e");
      return [];
    }
  }

  Future<bool> updateZoneAlarms(int zoneId, Map<String, dynamic> data) async {
    try {
      final response = await dio.post(
        '$baseUrl/users/zones/$zoneId/config-alarms',
        data: data,
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Błąd updateZoneAlarms: $e");
      return false;
    }
  }

  Future<int> fetchSensorHealthCheckInterval() async {
    try {
      final response = await dio.get(
        '$baseUrl/users/sensor-health-check',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final v = data['sensor_health_check_interval'];
        if (v is int) return v;
        if (v is String) return int.tryParse(v) ?? 30;
        return 30;
      }
    } catch (e) {
      print('fetchSensorHealthCheckInterval error: $e');
    }
    throw Exception('Nie udało się pobrać sensor_health_check_interval');
  }

  Future<void> updateSensorHealthCheckInterval(int seconds) async {
    try {
      final response = await dio.post(
        '$baseUrl/users/sensor-health-check',
        data: {'sensor_health_check_interval': seconds},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) return;
      throw Exception('Status: ${response.statusCode}');
    } catch (e) {
      print('updateSensorHealthCheckInterval error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> fetchMyControllers() async {
    try {
      final res = await dio.get('$baseUrl/users/controllers');
      return res.data;
    } catch (e) {
      print('fetchMyControllers error: $e');
      throw Exception('Nie udało się pobrać kontrolerów');
    }
  }

  Future<void> deleteController(dynamic deviceId) async {
    try {
      final res = await dio.delete('$baseUrl/users/controllers/$deviceId');
      if (res.statusCode != 200) {
        throw Exception('Status: ${res.statusCode}');
      }
    } catch (e) {
      print('deleteController error: $e');
      rethrow;
    }
  }
}

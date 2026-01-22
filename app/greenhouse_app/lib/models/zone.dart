import 'sensor_node.dart';

class Zone {
  final int id;
  final String name;
  final int x;
  final int y;
  final int width;
  final int height;

  final bool alarmActive;
  final String? alarmReason;

  final List<SensorNode> sensorNodes;

  final int? controllerId;
  final String? controllerDeviceId;

  final double? minTemp;
  final double? maxTemp;
  final double? minHum;
  final double? maxHum;
  final double? minLight;
  final double? maxLight;

  final int? tempAlarmDelaySeconds;
  final int? humAlarmDelaySeconds;
  final int? lightAlarmDelaySeconds;

  const Zone({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.sensorNodes,
    required this.alarmActive,
    this.alarmReason,
    this.controllerId,
    this.controllerDeviceId,
    this.minTemp,
    this.maxTemp,
    this.minHum,
    this.maxHum,
    this.minLight,
    this.maxLight,
    this.tempAlarmDelaySeconds,
    this.humAlarmDelaySeconds,
    this.lightAlarmDelaySeconds,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    double? parseDoubleOrNull(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value.replaceAll(',', '.'));
      return null;
    }

    return Zone(
      id: parseInt(json['id_zone']),
      name: (json['zone_name'] ?? '').toString(),

      x: parseInt(json['x'], defaultValue: 50),
      y: parseInt(json['y'], defaultValue: 50),
      width: parseInt(json['width'], defaultValue: 50),
      height: parseInt(json['height'], defaultValue: 50),

      alarmActive: json['alarm_active'] == true,
      alarmReason: json['alarm_reason']?.toString(),

      sensorNodes: (json['sensor_nodes'] as List? ?? [])
          .map((s) => SensorNode.fromJson(s as Map<String, dynamic>))
          .toList(),

      controllerId: json['id_greenhouse_controller'] != null
          ? parseInt(json['id_greenhouse_controller'])
          : null,
      controllerDeviceId: json['controller_device_id']?.toString(),

      minTemp: parseDoubleOrNull(json['min_temp']),
      maxTemp: parseDoubleOrNull(json['max_temp']),
      minHum: parseDoubleOrNull(json['min_hum']),
      maxHum: parseDoubleOrNull(json['max_hum']),
      minLight: parseDoubleOrNull(json['min_light']),
      maxLight: parseDoubleOrNull(json['max_light']),

      tempAlarmDelaySeconds: json['temp_alarm_delay_seconds'] != null
          ? parseInt(json['temp_alarm_delay_seconds'])
          : null,
      humAlarmDelaySeconds: json['hum_alarm_delay_seconds'] != null
          ? parseInt(json['hum_alarm_delay_seconds'])
          : null,
      lightAlarmDelaySeconds: json['light_alarm_delay_seconds'] != null
          ? parseInt(json['light_alarm_delay_seconds'])
          : null,
    );
  }
}

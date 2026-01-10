import 'sensor_node.dart';

class Zone {
  final int id;
  final String name;
  final int x;
  final int y;
  final int width;
  final int height;
  final List<SensorNode> sensorNodes;
  final int? controllerId;
  final String? controllerDeviceId;

  Zone({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.sensorNodes,
    this.controllerId,
    this.controllerDeviceId,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Zone(
      id: parseInt(json['id_zone']),
      name: json['zone_name'] ?? '',
      x: parseInt(json['x'] ?? 50),
      y: parseInt(json['y'] ?? 50),
      width: parseInt(json['width'] ?? 50),
      height: parseInt(json['height'] ?? 50),
      sensorNodes: (json['sensor_nodes'] as List? ?? [])
          .map((s) => SensorNode.fromJson(s))
          .toList(),
      controllerId: json['id_greenhouse_controller'] != null
          ? parseInt(json['id_greenhouse_controller'])
          : null,
      controllerDeviceId: json['controller_device_id']?.toString(),
    );
  }
}

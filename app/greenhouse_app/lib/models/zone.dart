// import 'sensor_node.dart';

// class Zone {
//   final int id;
//   final String name;
//   final int x;
//   final int y;
//   final int width;
//   final int height;
//   final List<SensorNode> sensorNodes;

//   Zone({
//     required this.id,
//     required this.name,
//     required this.x,
//     required this.y,
//     required this.width,
//     required this.height,
//     required this.sensorNodes,
//   });

//   factory Zone.fromJson(Map<String, dynamic> json) {
//     return Zone(
//       id: json['id_zone'],
//       name: json['zone_name'],
//       x: json['x'] ?? 50,
//       y: json['y'] ?? 50,
//       width: json['width'] ?? 50,
//       height: json['height'] ?? 50,
//       sensorNodes: (json['sensor_nodes'] as List? ?? [])
//           .map((s) => SensorNode.fromJson(s))
//           .toList(),
//     );
//   }
// }
import 'sensor_node.dart';

class Zone {
  final int id;
  final String name;
  final int x;
  final int y;
  final int width;
  final int height;
  final List<SensorNode> sensorNodes;

  Zone({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.sensorNodes,
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
    );
  }
}

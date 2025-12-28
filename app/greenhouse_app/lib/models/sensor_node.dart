// class SensorNode {
//   final int id;
//   final String name;

//   SensorNode({required this.id, required this.name});

//   factory SensorNode.fromJson(Map<String, dynamic> json) {
//     return SensorNode(
//       id: json['id_sensor_node'],
//       name: json['sensor_node_name'],
//     );
//   }
// }
// class SensorNode {
//   final int id;
//   final String name;

//   SensorNode({required this.id, required this.name});

//   factory SensorNode.fromJson(Map<String, dynamic> json) {
//     return SensorNode(
//       id: json['id_sensor_node'] is int
//           ? json['id_sensor_node']
//           : int.parse(json['id_sensor_node'].toString()),
//       name: json['sensor_node_name'] ?? '',
//     );
//   }
// }
class SensorNode {
  final int id;
  final String name;

  SensorNode({required this.id, required this.name});

  factory SensorNode.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return SensorNode(
      id: parseInt(json['id_sensor_node']),
      name: json['sensor_node_name'] ?? '',
    );
  }
}

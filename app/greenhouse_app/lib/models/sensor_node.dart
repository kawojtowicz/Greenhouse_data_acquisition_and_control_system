class SensorNode {
  final int id;
  final String name;
  final int idGreenhouseController;

  SensorNode({
    required this.id,
    required this.name,
    required this.idGreenhouseController,
  });

  factory SensorNode.fromJson(Map<String, dynamic> json) {
    return SensorNode(
      id: json['id_sensor_node'] ?? 0,
      name: json['sensor_node_name'] ?? '',
      idGreenhouseController: json['id_greenhouse_controller'] ?? '',
    );
  }
}

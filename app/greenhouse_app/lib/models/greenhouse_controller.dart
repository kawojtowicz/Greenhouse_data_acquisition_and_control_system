import 'sensor_node.dart';

class GreenhouseController {
  final int id;
  final String greenhouseName;
  final double temperatureSet;
  final List<SensorNode> sensorNodes;

  GreenhouseController({
    required this.id,
    required this.greenhouseName,
    required this.temperatureSet,
    required this.sensorNodes,
  });

  factory GreenhouseController.fromJson(Map<String, dynamic> json) {
    return GreenhouseController(
      id: json['id_greenhouse_controller'],
      greenhouseName: json['greenhouse_name'],
      temperatureSet: (json['temperature_set'] ?? 0).toDouble(),
      sensorNodes:
          (json['sensor_nodes'] as List<dynamic>?)
              ?.map((e) => SensorNode.fromJson(e))
              .toList() ??
          [],
    );
  }
}

import 'zone.dart';

class GreenhouseController {
  final int id;
  final String? deviceId;
  final String? deviceToken;
  final String? greenhouseName;
  final List<Zone> zones;

  GreenhouseController({
    required this.id,
    this.deviceId,
    this.deviceToken,
    this.greenhouseName,
    required this.zones,
  });

  factory GreenhouseController.fromJson(Map<String, dynamic> json) {
    return GreenhouseController(
      id: json['id_greenhouse_controller'],
      deviceId: json['device_id'],
      deviceToken: json['device_token'],
      greenhouseName: json['greenhouse_name'],
      zones: (json['zones'] as List? ?? [])
          .map((z) => Zone.fromJson(z))
          .toList(),
    );
  }
}

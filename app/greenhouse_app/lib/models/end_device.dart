class EndDevice {
  final int id;
  final String name;
  final String type;
  final double x;
  final double y;
  final double? upTemp;
  final double? downTemp;
  final double? upHum;
  final double? downHum;
  final double? upLight;
  final double? downLight;

  EndDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.x,
    required this.y,
    this.upTemp,
    this.downTemp,
    this.upHum,
    this.downHum,
    this.upLight,
    this.downLight,
  });

  factory EndDevice.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final id = parseInt(json['id_end_device']);

    return EndDevice(
      id: id,
      name: (json['end_device_name'] as String?)?.trim().isNotEmpty == true
          ? json['end_device_name']
          : 'Device $id',
      type: json['type'] ?? 'Unknown',
      x: parseDouble(json['x']) ?? 50,
      y: parseDouble(json['y']) ?? 50,
      upTemp: parseDouble(json['up_temp']),
      downTemp: parseDouble(json['down_temp']),
      upHum: parseDouble(json['up_hum']),
      downHum: parseDouble(json['down_hum']),
      upLight: parseDouble(json['up_light']),
      downLight: parseDouble(json['down_light']),
    );
  }
}

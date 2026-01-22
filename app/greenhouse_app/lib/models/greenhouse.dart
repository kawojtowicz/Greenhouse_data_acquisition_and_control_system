class Greenhouse {
  final int id;
  final String name;
  final String? description;
  final bool hasAlarm;
  List<dynamic> zones;

  Greenhouse({
    required this.id,
    required this.name,
    this.description,
    this.hasAlarm = false,
    this.zones = const [],
  });

  factory Greenhouse.fromJson(Map<String, dynamic> json) {
    return Greenhouse(
      id: json['id_greenhouse'],
      name: json['greenhouse_name'],
      description: json['description'],
      hasAlarm: json['has_alarm'] ?? false,
    );
  }
}

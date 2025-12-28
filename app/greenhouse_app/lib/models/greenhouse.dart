class Greenhouse {
  final int id;
  final String name;
  final String? description;

  Greenhouse({required this.id, required this.name, this.description});

  factory Greenhouse.fromJson(Map<String, dynamic> json) {
    return Greenhouse(
      id: json['id_greenhouse'],
      name: json['greenhouse_name'],
      description: json['description'],
    );
  }
}

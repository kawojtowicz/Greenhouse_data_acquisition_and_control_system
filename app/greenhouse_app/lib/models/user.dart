import 'package:shared_preferences/shared_preferences.dart';

class User {
  final int id;
  final String email;
  final String name;
  final String lastName;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.lastName,
  });

  factory User.fromPrefs(SharedPreferences prefs) {
    return User(
      id: prefs.getInt('id') ?? 0,
      email: prefs.getString('email') ?? '',
      name: prefs.getString('name') ?? '',
      lastName: prefs.getString('lastName') ?? '',
    );
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('id', id);
    await prefs.setString('email', email);
    await prefs.setString('name', name);
    await prefs.setString('lastName', lastName);
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
    );
  }
}

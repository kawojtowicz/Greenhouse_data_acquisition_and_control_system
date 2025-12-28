import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_page.dart';
import '../services/dio_client.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLogin = true;
  bool loading = false;

  final _authService = AuthService(DioClient().dio);

  void register() async {
    setState(() => loading = true);
    final response = await _authService.register(
      name: nameController.text,
      lastName: lastNameController.text,
      email: emailController.text,
      password: passwordController.text,
    );
    setState(() => loading = false);

    print('Register response: $response');
  }

  void login() async {
    setState(() => loading = true);
    final user = await _authService.login(
      emailController.text,
      passwordController.text,
    );

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Błędne dane logowania')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Logowanie' : 'Rejestracja')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isLogin)
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Imię'),
                    validator: (v) => v!.isEmpty ? 'Wymagane' : null,
                  ),
                if (!isLogin)
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(labelText: 'Nazwisko'),
                    validator: (v) => v!.isEmpty ? 'Wymagane' : null,
                  ),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => v!.isEmpty ? 'Wymagane' : null,
                ),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Hasło'),
                  obscureText: true,
                  validator: (v) => v!.isEmpty ? 'Wymagane' : null,
                ),
                const SizedBox(height: 20),
                loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            if (isLogin) {
                              login();
                            } else {
                              register();
                            }
                          }
                        },
                        child: Text(isLogin ? 'Zaloguj' : 'Zarejestruj'),
                      ),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin
                        ? 'Nie masz konta? Zarejestruj się'
                        : 'Masz konto? Zaloguj się',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

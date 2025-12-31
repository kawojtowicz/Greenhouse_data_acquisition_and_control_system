import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class WifiProvisioningPage extends StatefulWidget {
  const WifiProvisioningPage({super.key});

  @override
  State<WifiProvisioningPage> createState() => _WifiProvisioningPageState();
}

class _WifiProvisioningPageState extends State<WifiProvisioningPage> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController();

  bool _isLoading = false;

  Future<void> sendProvisioning() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text.trim();
    final token = _tokenController.text.trim();

    if (ssid.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SSID i token są wymagane')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      const deviceIp = '10.123.45.1';
      final dio = Dio();

      final response = await dio.post(
        'http://$deviceIp/token',
        data: {'ssid': ssid, 'password': password, 'token': token},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token i Wi-Fi wysłane pomyślnie!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd urządzenia: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd połączenia: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi Provisioning')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(
                labelText: 'SSID (sieć CC3235SF)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Hasło Wi-Fi (opcjonalne)',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(labelText: 'Token JWT'),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: sendProvisioning,
                    child: const Text('Wyślij token i Wi-Fi'),
                  ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/discovered_device.dart';

class DiscoverDevicesPage extends StatefulWidget {
  const DiscoverDevicesPage({super.key});

  @override
  State<DiscoverDevicesPage> createState() => _DiscoverDevicesPageState();
}

class _DiscoverDevicesPageState extends State<DiscoverDevicesPage> {
  final api = ApiService();
  late Future<List<DiscoveredDevice>> devicesFuture;

  @override
  void initState() {
    super.initState();
    devicesFuture = api.fetchDiscoveredDevices();
  }

  void assignDevice(String deviceId) async {
    try {
      final token = await api.assignDevice(deviceId);
      if (token != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Urządzenie przypisane i token zapisany!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Błąd przypisywania urządzenia')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd: $e')));
    }

    setState(() {
      devicesFuture = api.fetchDiscoveredDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wykryte urządzenia')),
      body: FutureBuilder<List<DiscoveredDevice>>(
        future: devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Błąd: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Brak wykrytych urządzeń'));
          }

          final devices = snapshot.data!;

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                leading: const Icon(Icons.memory, size: 40),
                title: Text(device.deviceId),
                subtitle: Text(
                  device.assigned ? 'Już przypisane' : 'Nieprzypisane',
                ),
                trailing: device.assigned
                    ? const Icon(Icons.check, color: Colors.green)
                    : ElevatedButton(
                        onPressed: () => assignDevice(device.deviceId),
                        child: const Text('Dodaj'),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

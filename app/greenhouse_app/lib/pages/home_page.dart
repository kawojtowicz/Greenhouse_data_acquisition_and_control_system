import 'package:flutter/material.dart';
import 'package:greenhouse_app/pages/discover_devices_page.dart';
import 'package:greenhouse_app/pages/greenhouse_view.dart';
import 'package:greenhouse_app/pages/wifi_provisioning_page.dart';
import '../services/api_service.dart';
import '../models/greenhouse.dart';
import 'package:greenhouse_app/pages/discover_nodes_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = ApiService();
  late Future<List<Greenhouse>> greenhousesFuture;

  @override
  void initState() {
    super.initState();
    greenhousesFuture = api.fetchUserGreenhouses();
  }

  void logout() async {
    await api.logoutUser(context);
    Navigator.pushReplacementNamed(context, '/');
  }

  void navigateToDiscoverDevices() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiscoverDevicesPage()),
    ).then((_) {
      setState(() {
        greenhousesFuture = api.fetchUserGreenhouses();
      });
    });
  }

  void navigateToWifiProvisioning() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WifiProvisioningPage()),
    );
  }

  void _addNewGreenhouseDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodaj nową szklarnię'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nazwa szklarni'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Opis (opcjonalny)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nazwa szklarni jest wymagana')),
                );
                return;
              }

              try {
                await api.addGreenhouse(
                  name,
                  description.isNotEmpty ? description : null,
                );
                Navigator.pop(context);
                setState(() {
                  greenhousesFuture = api.fetchUserGreenhouses();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Szklarnia utworzona')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Błąd tworzenia szklarni: $e')),
                );
              }
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twoje obiekty'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi),
            tooltip: 'Wi-Fi Provisioning',
            onPressed: navigateToWifiProvisioning,
          ),
          IconButton(
            icon: const Icon(Icons.sensors_off),
            tooltip: 'Nieprzypisane czujniki',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UnassignedDevicesPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_box),
            tooltip: 'Dodaj nowy kontroler',
            onPressed: navigateToDiscoverDevices,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Dodaj nową szklarnię',
            onPressed: _addNewGreenhouseDialog,
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: logout),
        ],
      ),
      body: Center(
        child: FutureBuilder<List<Greenhouse>>(
          future: greenhousesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Błąd: ${snapshot.error}');
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Brak szklarni'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: navigateToDiscoverDevices,
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj nowy kontroler'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _addNewGreenhouseDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj nową szklarnię'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: navigateToWifiProvisioning,
                    icon: const Icon(Icons.wifi),
                    label: const Text('Skonfiguruj Wi-Fi CC3235SF'),
                  ),
                ],
              );
            } else {
              final greenhouses = snapshot.data!;
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: greenhouses.length,
                itemBuilder: (context, index) {
                  final greenhouse = greenhouses[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              GreenhouseViewPage(greenhouse: greenhouse),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.home, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            greenhouse.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (greenhouse.description != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                greenhouse.description!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}

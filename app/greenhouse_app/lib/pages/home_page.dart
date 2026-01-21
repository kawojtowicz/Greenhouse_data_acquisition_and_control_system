import 'package:flutter/material.dart';
import 'package:greenhouse_app/pages/discover_devices_page.dart';
import 'package:greenhouse_app/pages/greenhouse_view.dart';
import 'package:greenhouse_app/pages/wifi_provisioning_page.dart';
import 'package:greenhouse_app/pages/discover_nodes_page.dart';
import '../services/api_service.dart';
import '../models/greenhouse.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = ApiService();
  late Future<List<Greenhouse>> greenhousesFuture;

  bool editMode = false;
  bool showAddFAB = false;

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

  void navigateToUnassignedDevices() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UnassignedDevicesPage()),
    );
  }

  void navigateToWifiProvisioning() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WifiProvisioningPage()),
    );
  }

  Future<void> _addNewGreenhouseDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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

              await api.addGreenhouse(
                name,
                description.isNotEmpty ? description : null,
              );

              Navigator.pop(context);
              setState(() {
                greenhousesFuture = api.fetchUserGreenhouses();
              });
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGreenhouse(Greenhouse greenhouse) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuń szklarnię'),
        content: Text(
          'Czy na pewno chcesz usunąć szklarnię "${greenhouse.name}"?\nWszystkie dane zostaną utracone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await api.deleteGreenhouse(greenhouse.id);
              setState(() {
                greenhousesFuture = api.fetchUserGreenhouses();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Szklarnia usunięta')),
              );
            },
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }

  Future<void> _editGreenhouseDialog(Greenhouse greenhouse) async {
    final nameController = TextEditingController(text: greenhouse.name);
    final descriptionController = TextEditingController(
      text: greenhouse.description ?? '',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edytuj szklarnię'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nazwa'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Opis'),
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
              final newName = nameController.text.trim();
              final newDescription = descriptionController.text.trim();

              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nazwa nie może być pusta')),
                );
                return;
              }

              Navigator.pop(context);

              await ApiService().updateGreenhouseName(
                greenhouse.id,
                newName,
                newDescription.isEmpty ? null : newDescription,
              );

              setState(() {
                greenhousesFuture = ApiService().fetchUserGreenhouses();
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Szklarnia zaktualizowana')),
              );
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'add_device':
        navigateToDiscoverDevices();
        break;
      case 'unassigned_devices':
        navigateToUnassignedDevices();
        break;
      case 'wifi':
        navigateToWifiProvisioning();
        break;
      case 'logout':
        logout();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twoje szklarnie'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_device',
                child: ListTile(
                  leading: Icon(Icons.add_box),
                  title: Text('Dodaj nowy kontroler'),
                ),
              ),
              const PopupMenuItem(
                value: 'unassigned_devices',
                child: ListTile(
                  leading: Icon(Icons.sensors_off),
                  title: Text('Nieprzypisane urządzenia'),
                ),
              ),
              // const PopupMenuItem(
              //   value: 'wifi',
              //   child: ListTile(
              //     leading: Icon(Icons.wifi),
              //     title: Text('Skonfiguruj Wi-Fi'),
              //   ),
              // ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Wyloguj się'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<List<Greenhouse>>(
            future: greenhousesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Błąd: ${snapshot.error}'));
              }

              final greenhouses = snapshot.data ?? [];

              if (greenhouses.isEmpty) {
                return const Center(child: Text('Brak szklarni'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: greenhouses.length,
                itemBuilder: (context, index) {
                  final greenhouse = greenhouses[index];
                  return GestureDetector(
                    onTap: () {
                      if (!editMode) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                GreenhouseViewPage(greenhouse: greenhouse),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Najpierw zamknij tryb edycji'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },

                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: Card(
                            color: Colors.green[50],
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[200],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.home,
                                    color: Color.fromARGB(255, 14, 72, 16),
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  greenhouse.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromARGB(221, 7, 84, 72),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                if (greenhouse.description != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                      vertical: 4.0,
                                    ),
                                    child: Text(
                                      greenhouse.description!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (editMode)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Column(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blueGrey,
                                  ),
                                  onPressed: () =>
                                      _editGreenhouseDialog(greenhouse),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () =>
                                      _deleteGreenhouse(greenhouse),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          Positioned(
            bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAddFAB)
                  Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'add_greenhouse',
                        onPressed: _addNewGreenhouseDialog,
                        child: const Icon(Icons.add),
                        backgroundColor: Colors.green,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                FloatingActionButton(
                  heroTag: 'edit_mode',
                  onPressed: () {
                    setState(() {
                      showAddFAB = !showAddFAB;
                      editMode = showAddFAB;
                    });
                  },
                  child: Icon(showAddFAB ? Icons.close : Icons.edit),
                  backgroundColor: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

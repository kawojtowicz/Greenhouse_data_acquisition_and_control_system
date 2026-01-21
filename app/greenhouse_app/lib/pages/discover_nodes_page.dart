import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UnassignedDevicesPage extends StatefulWidget {
  const UnassignedDevicesPage({super.key});

  @override
  State<UnassignedDevicesPage> createState() => _UnassignedDevicesPageState();
}

class _UnassignedDevicesPageState extends State<UnassignedDevicesPage> {
  final api = ApiService();

  late Future<List<_DeviceItem>> devicesFuture;

  Map<int, bool> expanded = {};
  Map<int, List<Map<String, dynamic>>> zonesMap = {};

  @override
  void initState() {
    super.initState();
    devicesFuture = _loadDevices();
  }

  Future<void> _deleteDevice(_DeviceItem device) async {
    try {
      if (device.isSensor) {
        await api.deleteSensor(device.id);
      } else {
        await api.deleteEndDevice(device.id);
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Urządzenie usunięte')));

      setState(() {
        devicesFuture = _loadDevices();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd usuwania: $e')));
    }
  }

  Future<void> _confirmDelete(_DeviceItem device) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdzenie'),
        content: Text(
          device.isSensor
              ? 'Czy na pewno chcesz usunąć ten sensor?'
              : 'Czy na pewno chcesz usunąć to urządzenie?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      _deleteDevice(device);
    }
  }

  Future<List<_DeviceItem>> _loadDevices() async {
    final sensors = await api.fetchUnassignedSensors();
    final endDevices = await api.fetchUnassignedEndDevices();

    return [
      ...sensors.map(
        (s) => _DeviceItem(id: s.id, name: s.name, isSensor: true),
      ),
      ...endDevices.map(
        (e) => _DeviceItem(id: e.id, name: e.name, isSensor: false),
      ),
    ];
  }

  Future<void> _fetchZones(int deviceId) async {
    if (!zonesMap.containsKey(deviceId)) {
      final zones = await api.fetchAllUserZones();
      setState(() {
        zonesMap[deviceId] = zones;
        expanded[deviceId] = true;
      });
    } else {
      setState(() {
        expanded[deviceId] = !(expanded[deviceId] ?? false);
      });
    }
  }

  Future<void> _assignToZone(_DeviceItem device, int zoneId) async {
    try {
      if (device.isSensor) {
        await api.assignSensorToZone(device.id, zoneId);
      } else {
        await api.assignEndDeviceToZone(device.id, zoneId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            device.isSensor
                ? 'Sensor przypisany do strefy'
                : 'End device przypisany do strefy',
          ),
        ),
      );

      setState(() {
        devicesFuture = _loadDevices();
        expanded[device.id] = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd przypisania: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nieprzypisane urządzenia')),
      body: FutureBuilder<List<_DeviceItem>>(
        future: devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Błąd: ${snapshot.error}'));
          }

          final devices = snapshot.data ?? [];

          if (devices.isEmpty) {
            return const Center(child: Text('Brak nieprzypisanych urządzeń'));
          }

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final isExpanded = expanded[device.id] ?? false;
              final zones = zonesMap[device.id] ?? [];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: Icon(
                        device.isSensor ? Icons.sensors : Icons.devices,
                        color: device.isSensor ? Colors.green : Colors.blue,
                      ),
                      title: Text(device.name),
                      subtitle: Text(
                        '${device.isSensor ? 'Sensor' : 'End Device'} • ID: ${device.id}',
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _fetchZones(device.id),
                            child: Text(
                              isExpanded
                                  ? 'Ukryj strefy'
                                  : 'Przypisz do strefy',
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _confirmDelete(device),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Usuń'),
                          ),
                        ],
                      ),
                    ),

                    if (isExpanded)
                      ...zones.map(
                        (zone) => ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 32,
                            right: 16,
                          ),
                          title: Text(zone['zone_name']),
                          subtitle: Text(
                            'Szklarnia: ${zone['greenhouse_name']}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () =>
                                _assignToZone(device, zone['id_zone']),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DeviceItem {
  final int id;
  final String name;
  final bool isSensor;

  _DeviceItem({required this.id, required this.name, required this.isSensor});
}

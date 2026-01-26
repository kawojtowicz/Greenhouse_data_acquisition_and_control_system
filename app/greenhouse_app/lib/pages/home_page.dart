import 'dart:async';
import 'package:flutter/material.dart';
import 'package:greenhouse_app/pages/discover_devices_page.dart';
import 'package:greenhouse_app/pages/greenhouse_view.dart';
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
  Timer? _refreshTimer;

  bool editMode = false;
  bool showAddFAB = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!editMode) _refreshData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      greenhousesFuture = api.fetchUserGreenhouses();
    });
  }

  void logout() async {
    await api.logoutUser(context);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'alarms':
        _showSensorHealthCheckDialog();
        break;

      case 'add_device':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DiscoverDevicesPage()),
        ).then((_) => _refreshData());
        break;
      case 'unassigned_devices':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UnassignedDevicesPage()),
        );
        break;
      case 'logout':
        logout();
        break;
      case 'my_controllers':
        _showMyControllersView();
        break;
    }
  }

  void _showMyControllersView() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<List<dynamic>>(
            future: api.fetchMyControllers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const Text('Błąd ładowania kontrolerów');
              }

              final controllers = snapshot.data ?? [];

              if (controllers.isEmpty) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: Text('Brak przypisanych kontrolerów')),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Moje kontrolery',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: controllers.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final c = controllers[index];
                        return ListTile(
                          leading: const Icon(Icons.memory),
                          title: Text('ID: ${c['device_id']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              final deviceId = c['device_id']?.toString();
                              if (deviceId != null && deviceId.isNotEmpty) {
                                _confirmDeleteController(deviceId);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Nieprawidłowy ID kontrolera',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteController(String controllerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuń kontroler'),
        content: const Text('Czy na pewno chcesz usunąć ten kontroler?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await api.deleteController(controllerId);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kontroler usunięty')));
    }
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
              if (nameController.text.trim().isEmpty) return;
              await api.addGreenhouse(
                nameController.text.trim(),
                descriptionController.text.trim(),
              );
              if (!mounted) return;
              Navigator.pop(context);
              _refreshData();
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSensorHealthCheckDialog() async {
    bool saving = false;

    int currentSeconds;
    try {
      currentSeconds = await api.fetchSensorHealthCheckInterval();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd pobierania ustawień: $e')));
      return;
    }
    if (!mounted) return;

    int h = currentSeconds ~/ 3600;
    int m = (currentSeconds % 3600) ~/ 60;
    int s = currentSeconds % 60;

    final hCtrl = TextEditingController(text: h.toString());
    final mCtrl = TextEditingController(text: m.toString());
    final sCtrl = TextEditingController(text: s.toString());

    int clampInt(int v, int min, int max) =>
        v < min ? min : (v > max ? max : v);

    int parseOrZero(String t) => int.tryParse(t.trim()) ?? 0;

    String two(int v) => v.toString().padLeft(2, '0');

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          int hh = parseOrZero(hCtrl.text);
          int mm = parseOrZero(mCtrl.text);
          int ss = parseOrZero(sCtrl.text);

          hh = clampInt(hh, 0, 23);
          mm = clampInt(mm, 0, 59);
          ss = clampInt(ss, 0, 59);

          final total = hh * 3600 + mm * 60 + ss;

          final minSeconds = 5;
          final maxSeconds = 86400;
          final invalid = total < minSeconds || total > maxSeconds;

          Widget numField({
            required String label,
            required TextEditingController ctrl,
            required int min,
            required int max,
          }) {
            return Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: label,
                  helperText: '$min–$max',
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            );
          }

          return AlertDialog(
            title: const Text(
              'Ustaw czas, po którym uruchomi się alarm o bezczynności czujnika:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    numField(label: 'Godz.', ctrl: hCtrl, min: 0, max: 23),
                    const SizedBox(width: 12),
                    numField(label: 'Min.', ctrl: mCtrl, min: 0, max: 59),
                    const SizedBox(width: 12),
                    numField(label: 'Sek.', ctrl: sCtrl, min: 0, max: 59),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ustaw: ${two(hh)}:${two(mm)}:${two(ss)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text('Łącznie w sekundach: $total s'),
                      const SizedBox(height: 8),
                      Text(
                        'Poprzednia wartość: $currentSeconds s',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      if (invalid) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Zakres: $minSeconds–$maxSeconds s',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _presetChip(
                      '30s',
                      0,
                      0,
                      30,
                      hCtrl,
                      mCtrl,
                      sCtrl,
                      setDialogState,
                    ),
                    _presetChip(
                      '1 min',
                      0,
                      1,
                      0,
                      hCtrl,
                      mCtrl,
                      sCtrl,
                      setDialogState,
                    ),
                    _presetChip(
                      '5 min',
                      0,
                      5,
                      0,
                      hCtrl,
                      mCtrl,
                      sCtrl,
                      setDialogState,
                    ),
                    _presetChip(
                      '15 min',
                      0,
                      15,
                      0,
                      hCtrl,
                      mCtrl,
                      sCtrl,
                      setDialogState,
                    ),
                    _presetChip(
                      '1 h',
                      1,
                      0,
                      0,
                      hCtrl,
                      mCtrl,
                      sCtrl,
                      setDialogState,
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Anuluj'),
              ),
              ElevatedButton.icon(
                icon: saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Zapisz'),
                onPressed: saving || invalid
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          await api.updateSensorHealthCheckInterval(total);
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Zapisano: ${two(hh)}:${two(mm)}:${two(ss)}',
                              ),
                            ),
                          );
                          Navigator.pop(context);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('Błąd zapisu: $e')),
                          );
                        } finally {
                          setDialogState(() => saving = false);
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _presetChip(
    String label,
    int hh,
    int mm,
    int ss,
    TextEditingController hCtrl,
    TextEditingController mCtrl,
    TextEditingController sCtrl,
    void Function(void Function()) setDialogState,
  ) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        setDialogState(() {
          hCtrl.text = hh.toString();
          mCtrl.text = mm.toString();
          sCtrl.text = ss.toString();
        });
      },
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
              await api.updateGreenhouseName(
                greenhouse.id,
                nameController.text.trim(),
                descriptionController.text.trim(),
              );
              if (!mounted) return;
              Navigator.pop(context);
              _refreshData();
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
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
                value: 'alarms',
                child: ListTile(
                  leading: Icon(Icons.notifications_active),
                  title: Text('Konfiguracja alarmu o bezczynności czujnika'),
                ),
              ),
              const PopupMenuItem(
                value: 'add_device',
                child: ListTile(
                  leading: Icon(Icons.add_box),
                  title: Text('Dodaj kontroler'),
                ),
              ),

              const PopupMenuItem(
                value: 'my_controllers',
                child: ListTile(
                  leading: Icon(Icons.settings_remote),
                  title: Text('Moje kontrolery'),
                ),
              ),

              const PopupMenuItem(
                value: 'unassigned_devices',
                child: ListTile(
                  leading: Icon(Icons.sensors_off),
                  title: Text('Nieprzypisane urządzenia'),
                ),
              ),
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
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: FutureBuilder<List<Greenhouse>>(
          future: greenhousesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final greenhouses = snapshot.data ?? [];
            if (greenhouses.isEmpty)
              return const Center(child: Text('Brak szklarni.'));

            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: greenhouses.length,
              itemBuilder: (context, index) {
                final greenhouse = greenhouses[index];
                return _buildGreenhouseCard(greenhouse);
              },
            );
          },
        ),
      ),
      floatingActionButton: _buildFabMenu(),
    );
  }

  Widget _buildGreenhouseCard(Greenhouse greenhouse) {
    final bool hasAlarm = greenhouse.hasAlarm;
    return GestureDetector(
      onTap: () {
        if (!editMode) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GreenhouseViewPage(greenhouse: greenhouse),
            ),
          ).then((_) => _refreshData());
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
          Positioned.fill(
            child: Card(
              margin: EdgeInsets.zero,
              color: hasAlarm ? Colors.red.shade50 : Colors.green[50],
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
                      color: hasAlarm ? Colors.red.shade100 : Colors.green[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.home,
                      color: hasAlarm
                          ? Colors.red.shade900
                          : const Color.fromARGB(255, 14, 72, 16),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      greenhouse.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: hasAlarm
                            ? Colors.red.shade900
                            : const Color.fromARGB(221, 7, 84, 72),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (greenhouse.description != null &&
                      greenhouse.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Text(
                        greenhouse.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (hasAlarm && !editMode)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  "ALARM",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          if (editMode)
            Positioned(
              top: 4,
              right: 4,
              child: Column(
                children: [
                  _buildEditIcon(
                    Icons.edit,
                    Colors.blueGrey,
                    () => _editGreenhouseDialog(greenhouse),
                  ),
                  const SizedBox(height: 4),
                  _buildEditIcon(
                    Icons.delete,
                    Colors.redAccent,
                    () => _deleteGreenhouse(greenhouse),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditIcon(IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: IconButton(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
      ),
    );
  }

  Future<void> _deleteGreenhouse(Greenhouse greenhouse) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuń szklarnię'),
        content: Text('Czy na pewno chcesz usunąć "${greenhouse.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await api.deleteGreenhouse(greenhouse.id);
      _refreshData();
    }
  }

  Widget _buildFabMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showAddFAB) ...[
          FloatingActionButton(
            heroTag: 'add_btn',
            onPressed: _addNewGreenhouseDialog,
            backgroundColor: Colors.green,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: () => setState(() {
            showAddFAB = !showAddFAB;
            editMode = showAddFAB;
          }),
          backgroundColor: showAddFAB ? Colors.grey : Colors.blue,
          child: Icon(showAddFAB ? Icons.close : Icons.edit),
        ),
      ],
    );
  }
}

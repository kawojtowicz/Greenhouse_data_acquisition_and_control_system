import 'package:flutter/material.dart';
import '../models/greenhouse.dart';
import '../services/api_service.dart';
import 'dart:async';

const double mapSize = 3000;

class GreenhouseViewPage extends StatefulWidget {
  final Greenhouse greenhouse;

  const GreenhouseViewPage({super.key, required this.greenhouse});

  @override
  State<GreenhouseViewPage> createState() => _GreenhouseViewPageState();
}

class ZoneRect {
  int? id;
  double x;
  double y;
  double width;
  double height;
  String name;
  String? assignedController;
  bool alarmActive;
  String? alarmReason;

  double? minTemp;
  double? maxTemp;
  double? minHum;
  double? maxHum;
  double? minLight;
  double? maxLight;

  int? tempDelay;
  int? humDelay;
  int? lightDelay;

  ZoneRect({
    this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.name,
    this.assignedController,
    this.alarmActive = false,
    this.alarmReason,

    this.minTemp,
    this.maxTemp,
    this.minHum,
    this.maxHum,
    this.minLight,
    this.maxLight,
    this.tempDelay,
    this.humDelay,
    this.lightDelay,
  });
}

class SensorTile {
  final int id;
  String name;
  double x;
  double y;
  final dynamic temperature;
  final dynamic humidity;
  final dynamic light;

  bool isExpanded;
  bool isDragging;

  SensorTile({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.temperature,
    this.humidity,
    this.light,
    this.isExpanded = false,
    this.isDragging = false,
  });
}

class EndDeviceTile {
  final int id;
  String name;
  double x;
  double y;
  final double? upTemp;
  final double? downTemp;
  final double? upHum;
  final double? downHum;
  final double? upLight;
  final double? downLight;

  bool isExpanded;
  bool isDragging;

  EndDeviceTile({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.upTemp,
    this.downTemp,
    this.upHum,
    this.downHum,
    this.upLight,
    this.downLight,
    this.isExpanded = false,
    this.isDragging = false,
  });
}

class _GreenhouseViewPageState extends State<GreenhouseViewPage> {
  List<SensorTile> sensors = [];
  List<ZoneRect> zones = [];
  List<EndDeviceTile> endDevices = [];
  ZoneRect? currentDrawing;
  late final TransformationController _transformController;

  bool editMode = false;
  bool changeLocationMode = false;
  bool drawZoneMode = false;
  bool isLoading = false;

  Offset? startDrag;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _fetchAll();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerAndZoom();
    });

    Timer.periodic(const Duration(seconds: 10), (_) {
      if (!sensors.any((s) => s.isDragging)) {
        _fetchAll();
      }
    });
  }

  void _centerAndZoom() {
    final scale = 0.8;
    final screen = MediaQuery.of(context).size;

    _transformController.value = Matrix4.identity()
      ..scale(scale)
      ..translate(
        -mapSize / 2 + screen.width / (2 * scale),
        -mapSize / 2 + screen.height / (2 * scale),
      );
  }

  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      await Future.wait([_fetchLastLogs(), _fetchZones(), _fetchEndDevices()]);
    } catch (e) {
      print('Error fetching data: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _editEndDevice(EndDeviceTile device) async {
    final nameCtrl = TextEditingController(text: device.name);
    final upTempCtrl = TextEditingController(text: device.upTemp?.toString());
    final downTempCtrl = TextEditingController(
      text: device.downTemp?.toString(),
    );
    final upHumCtrl = TextEditingController(text: device.upHum?.toString());
    final downHumCtrl = TextEditingController(text: device.downHum?.toString());
    final upLightCtrl = TextEditingController(text: device.upLight?.toString());
    final downLightCtrl = TextEditingController(
      text: device.downLight?.toString(),
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edytuj: ${device.name}'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                'ID: ${device.id}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nazwa urządzenia',
                ),
              ),
              const SizedBox(height: 12),

              _numField('Temperatura wyłączenia (°C)', upTempCtrl),
              _numField('Temperatura włączenia (°C)', downTempCtrl),
              _numField('Wilgotność wyłączenia (%)', upHumCtrl),
              _numField('Wilgotność włączenia (%)', downHumCtrl),
              _numField('Światło wyłączenia (lx)', upLightCtrl),
              _numField('Światło włączenia (lx)', downLightCtrl),
            ],
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;

              if (newName != device.name) {
                await ApiService().updateEndDeviceName(device.id, newName);
                setState(() {
                  device.name = newName;
                });
              }

              await ApiService().updateEndDeviceParams(
                id: device.id,
                upTemp: double.tryParse(upTempCtrl.text),
                downTemp: double.tryParse(downTempCtrl.text),
                upHum: double.tryParse(upHumCtrl.text),
                downHum: double.tryParse(downHumCtrl.text),
                upLight: double.tryParse(upLightCtrl.text),
                downLight: double.tryParse(downLightCtrl.text),
              );

              Navigator.pop(context);
            },

            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  Widget _numField(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _assignZoneToController(ZoneRect zone) async {
    try {
      if (zone.id == null) {
        final newZoneId = await ApiService().createZone(
          widget.greenhouse.id,
          zone.name.isEmpty ? 'Nowa strefa' : zone.name,
          zone.x,
          zone.y,
          zone.width,
          zone.height,
        );

        if (newZoneId != null) {
          zone.id = newZoneId;
        } else {
          print('Failed to create zone: ID is null');
          return;
        }
      }

      final int zoneId = zone.id!;

      final controllersData = await ApiService().fetchControllers(
        widget.greenhouse.id,
      );

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Wybierz kontroler dla strefy'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: controllersData.length,
              itemBuilder: (context, index) {
                final controller = controllersData[index];
                return ListTile(
                  title: Text(controller.deviceId ?? 'Brak device_id'),
                  onTap: () async {
                    await ApiService().assignZoneToController(
                      zoneId: zoneId,
                      controllerId: controller.id,
                    );
                    Navigator.pop(context);
                    await _fetchZones();
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      print('Błąd przy przypisywaniu kontrolera: $e');
    }
  }

  void _showGreenhouseInfo() {
    final int zoneCount = zones.length;

    final int sensorsAssignedToZones = sensors.length;

    final int endDevicesAssigned = endDevices.length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.eco, color: Colors.green),
            SizedBox(width: 8),
            Text('Informacje o szklarni'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Nazwa', widget.greenhouse.name),
            _infoRow(
              'Opis',
              widget.greenhouse.description?.isNotEmpty == true
                  ? widget.greenhouse.description!
                  : 'Brak opisu',
            ),
            const Divider(),
            _infoRow('Liczba stref', zoneCount.toString()),
            _infoRow('Czujniki', sensorsAssignedToZones.toString()),
            _infoRow('Urządzenia ', endDevicesAssigned.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(flex: 6, child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _fetchEndDevices() async {
    try {
      final rawDevices = await ApiService().fetchEndDevices(
        widget.greenhouse.id,
      );

      endDevices = rawDevices.map((d) {
        return EndDeviceTile(
          id: d.id,
          name: d.name,
          x: d.x,
          y: d.y,
          upTemp: d.upTemp,
          downTemp: d.downTemp,
          upHum: d.upHum,
          downHum: d.downHum,
          upLight: d.upLight,
          downLight: d.downLight,
        );
      }).toList();
    } catch (e) {
      print('Error fetching end devices: $e');
      endDevices = [];
    }
  }

  Future<void> _deleteZone(ZoneRect zone) async {
    try {
      final zonesData = await ApiService().fetchZonesWithSensors(
        widget.greenhouse.id,
      );
      final targetZone = zonesData.firstWhere(
        (z) =>
            z.x.toDouble() == zone.x &&
            z.y.toDouble() == zone.y &&
            z.width.toDouble() == zone.width &&
            z.height.toDouble() == zone.height,
      );

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Usuń strefę'),
          content: Text('Czy na pewno chcesz usunąć strefę "${zone.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Usuń'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await ApiService().deleteZone(targetZone.id);

      await _fetchZones();
      setState(() {});
    } catch (e) {
      print('Error deleting zone: $e');
    }
  }

  Future<void> _fetchLastLogs() async {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    try {
      final sensorsData = await ApiService().fetchAllSensorsForGreenhouse(
        widget.greenhouse.id,
      );

      sensors = sensorsData.map((sensor) {
        final id = parseInt(sensor['id_sensor_node']);
        final existing = sensors.firstWhere(
          (s) => s.id == id,
          orElse: () => SensorTile(
            id: id,
            name: sensor['sensor_node_name'] ?? 'Sensor $id',
            x: (sensor['x'] ?? 50).toDouble(),
            y: (sensor['y'] ?? 50).toDouble(),
          ),
        );

        return SensorTile(
          id: id,
          name: sensor['sensor_node_name'] ?? 'Sensor $id',
          x: existing.isDragging ? existing.x : (sensor['x'] ?? 50).toDouble(),
          y: existing.isDragging ? existing.y : (sensor['y'] ?? 50).toDouble(),
          temperature: sensor['temperature'],
          humidity: sensor['humidity'],
          light: sensor['light'],
          isExpanded: existing.isExpanded,
          isDragging: existing.isDragging,
        );
      }).toList();
    } catch (e) {
      print('Error fetching sensors: $e');
      sensors = [];
    }
  }

  Future<void> _fetchZones() async {
    final hadAlarmBefore = zones.any((z) => z.alarmActive);

    final fetched = await ApiService().fetchZonesWithSensors(
      widget.greenhouse.id,
    );

    setState(() {
      zones = fetched
          .map(
            (z) => ZoneRect(
              id: z.id,
              x: z.x.toDouble(),
              y: z.y.toDouble(),
              width: z.width.toDouble(),
              height: z.height.toDouble(),
              name: z.name,
              assignedController: z.controllerDeviceId ?? '⚠ Brak!',
              alarmActive: z.alarmActive,
              alarmReason: z.alarmReason,

              minTemp: z.minTemp,
              maxTemp: z.maxTemp,
              minHum: z.minHum,
              maxHum: z.maxHum,
              minLight: z.minLight,
              maxLight: z.maxLight,

              tempDelay: z.tempAlarmDelaySeconds,
              humDelay: z.humAlarmDelaySeconds,
              lightDelay: z.lightAlarmDelaySeconds,
            ),
          )
          .toList();
    });

    final hasAlarmNow = zones.any((z) => z.alarmActive);

    if (!hadAlarmBefore && hasAlarmNow) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('⚠️ Alarm w jednej ze stref!'),
        ),
      );
    }

    for (final z in zones) {
      debugPrint(
        'ZONE ${z.name} alarm=${z.alarmActive} reason="${z.alarmReason}"',
      );
    }
  }

  void toggleEditMode() async {
    if (editMode) {
      for (final s in sensors) {
        if (s.isDragging) {
          try {
            await ApiService().saveSensorPosition(s.id, s.x, s.y);
            s.isDragging = false;
          } catch (e) {
            print('Error saving sensor position: $e');
          }
        }
      }
    }

    setState(() {
      editMode = !editMode;
      drawZoneMode = false;
      changeLocationMode = false;
    });
  }

  void toggleDrawZoneMode() {
    if (!editMode) return;
    setState(() => drawZoneMode = !drawZoneMode);
  }

  void toggleChangeLocationMode() {
    if (!editMode) return;
    setState(() => changeLocationMode = !changeLocationMode);
  }

  Future<void> _onSensorClicked(SensorTile sensor) async {
    if (!changeLocationMode) {
      setState(() {
        sensor.isExpanded = !sensor.isExpanded;
      });
      return;
    }

    final greenhouses = await ApiService().fetchUserGreenhouses();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Wybierz szklarnię'),
        content: ListView(
          shrinkWrap: true,
          children: greenhouses
              .map(
                (gh) => ListTile(
                  title: Text(gh.name),
                  onTap: () async {
                    await ApiService().changeSensorGreenhouse(sensor.id, gh.id);
                    Navigator.pop(context);
                    _fetchAll();
                  },
                ),
              )
              .toList(),
        ),
      ),
    );

    setState(() => changeLocationMode = false);
  }

  Future<void> _editZoneAlarms(ZoneRect zone) async {
    final minTempCtrl = TextEditingController(
      text: zone.minTemp?.toString() ?? '',
    );
    final maxTempCtrl = TextEditingController(
      text: zone.maxTemp?.toString() ?? '',
    );
    final minHumCtrl = TextEditingController(
      text: zone.minHum?.toString() ?? '',
    );
    final maxHumCtrl = TextEditingController(
      text: zone.maxHum?.toString() ?? '',
    );
    final minLightCtrl = TextEditingController(
      text: zone.minLight?.toString() ?? '',
    );
    final maxLightCtrl = TextEditingController(
      text: zone.maxLight?.toString() ?? '',
    );

    final tempDelayCtrl = TextEditingController(
      text: (zone.tempDelay ?? 1800).toString(),
    );
    final humDelayCtrl = TextEditingController(
      text: (zone.humDelay ?? 1800).toString(),
    );
    final lightDelayCtrl = TextEditingController(
      text: (zone.lightDelay ?? 1800).toString(),
    );

    bool saving = false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Alarmy: ${zone.name.isEmpty ? "Strefa" : zone.name}'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  'Zone ID: ${zone.id}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Temperatura (°C)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _numFiel('Minimalna temperatura:', minTempCtrl),
                _numFiel('Maksymalna temperatura:', maxTempCtrl),
                _numFieldInt('Opóżnienie alarmu w sekundach:', tempDelayCtrl),

                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Wilgotność (%)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _numFiel('Minimalna wilgotność:', minHumCtrl),
                _numFiel('Maksymalna wilgotność:', maxHumCtrl),
                _numFieldInt('Opóźnienie alarmu w sekundach:', humDelayCtrl),

                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Światło (lx)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _numFiel('Minimalne natężenie:', minLightCtrl),
                _numFiel('Maksymalne natężenie:', maxLightCtrl),
                _numFieldInt('Opóźnienie alarmu w sekundach:', lightDelayCtrl),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);

                      final payload = <String, dynamic>{
                        'min_temp': _tryDoubleOrNull(minTempCtrl.text),
                        'max_temp': _tryDoubleOrNull(maxTempCtrl.text),
                        'min_hum': _tryDoubleOrNull(minHumCtrl.text),
                        'max_hum': _tryDoubleOrNull(maxHumCtrl.text),
                        'min_light': _tryDoubleOrNull(minLightCtrl.text),
                        'max_light': _tryDoubleOrNull(maxLightCtrl.text),

                        'temp_alarm_delay_seconds': _tryIntOrNull(
                          tempDelayCtrl.text,
                        ),
                        'hum_alarm_delay_seconds': _tryIntOrNull(
                          humDelayCtrl.text,
                        ),
                        'light_alarm_delay_seconds': _tryIntOrNull(
                          lightDelayCtrl.text,
                        ),
                      };

                      payload.removeWhere((k, v) => v == null);

                      try {
                        final ok = await ApiService().updateZoneAlarms(
                          zone.id!,
                          payload,
                        );
                        if (!ok) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Nie udało się zapisać alarmów'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Zapisano alarmy strefy'),
                            ),
                          );
                          await _fetchZones();
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Błąd zapisu: $e')),
                        );
                      } finally {
                        setDialogState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
  }

  double? _tryDoubleOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  int? _tryIntOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Widget _numFiel(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _numFieldInt(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _editSensor(SensorTile sensor) async {
    final nameCtrl = TextEditingController(text: sensor.name);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edycja sensora'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ID: ${sensor.id}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nazwa sensora'),
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
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;

              await ApiService().updateSensorName(sensor.id, newName);

              setState(() {
                sensor.name = newName;
              });

              Navigator.pop(context);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  void _onZoneStart(DragStartDetails d) {
    startDrag = d.localPosition;
    currentDrawing = ZoneRect(
      id: null,
      x: startDrag!.dx,
      y: startDrag!.dy,
      width: 0,
      height: 0,
      name: '',
    );
  }

  void _onZoneUpdate(DragUpdateDetails d) {
    setState(() {
      currentDrawing!.width = d.localPosition.dx - startDrag!.dx;
      currentDrawing!.height = d.localPosition.dy - startDrag!.dy;
    });
  }

  String _withUnit(dynamic value, String unit) {
    if (value == null) return '-';

    if (value is String) {
      final s = value.trim();
      final n = double.tryParse(s.replaceAll(',', '.'));
      if (n != null) return '${n.toStringAsFixed(1)}$unit';
      return '$s $unit';
    }

    if (value is num) {
      final v = value.toDouble();
      if (v == v.roundToDouble()) return '${v.toInt()}$unit';
      return '${v.toStringAsFixed(1)}$unit';
    }

    return '$value $unit';
  }

  Future<void> _onZoneEnd(DragEndDetails d) async {
    if (currentDrawing == null) return;

    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nazwa strefy'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );

    final name = controller.text.trim().isEmpty
        ? 'Nowa strefa'
        : controller.text.trim();

    try {
      final newZoneId = await ApiService().createZone(
        widget.greenhouse.id,
        name,
        currentDrawing!.x,
        currentDrawing!.y,
        currentDrawing!.width,
        currentDrawing!.height,
      );

      if (newZoneId != null) {
        currentDrawing!.id = newZoneId;
      }
    } catch (e) {
      print('Error saving zone: $e');
    }

    await _fetchZones();
    setState(() {
      currentDrawing = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.greenhouse.name),
        actions: [
          IconButton(
            tooltip: 'Informacje o szklarni',
            icon: const Icon(Icons.help_outline),
            onPressed: _showGreenhouseInfo,
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _fetchAll,
        child: Column(
          children: [
            if (editMode && !drawZoneMode)
              Container(
                width: double.infinity,
                color: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                child: const Text(
                  'Tryb edycji: \n- Dotknij obiektu, aby edytować parametry.\n- Przeciągnij obiekt, aby zmienić jego lokalizację.\n- Wciśnij kosz, aby usunąć obiekt.\n- Wciśnij ołówek, aby edytować obiekt.\n- Wciśnij dzwonek, aby ustawić alarmy strefy.\n- Wciśnij ikonę ołówka w prawym dolnym rogu ekranu, aby rysować nowe strefy.',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (drawZoneMode)
              Container(
                width: double.infinity,
                color: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                child: const Text(
                  'Tryb rysowania nowej strefy: \n - Przeciągnij po mapie, aby zaznaczyć obszar.\n - Naciśnij ikonę ołówna ponownie, aby wyjść.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            Expanded(child: _buildMainView()),
          ],
        ),
      ),

      floatingActionButton: editMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'draw',
                  backgroundColor: drawZoneMode
                      ? Colors.orange
                      : Colors.blueGrey,
                  onPressed: toggleDrawZoneMode,
                  child: const Icon(Icons.edit),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'edit',
                  backgroundColor: Colors.green,
                  onPressed: toggleEditMode,
                  child: const Icon(Icons.check),
                ),
              ],
            )
          : FloatingActionButton(
              onPressed: toggleEditMode,
              child: const Icon(Icons.edit),
            ),
    );
  }

  Widget _buildMainView() {
    return InteractiveViewer(
      constrained: false,
      transformationController: _transformController,
      minScale: 0.2,
      maxScale: 5,
      child: SizedBox(
        width: mapSize,
        height: mapSize,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: drawZoneMode ? _onZoneStart : null,
          onPanUpdate: drawZoneMode ? _onZoneUpdate : null,
          onPanEnd: drawZoneMode ? _onZoneEnd : null,
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.green[50])),
              CustomPaint(
                size: Size(mapSize, mapSize),
                painter: ZonesPainter(zones: zones, current: currentDrawing),
                isComplex: true,
                willChange: true,
              ),

              ...zones.map((z) {
                final x = z.width < 0 ? z.x + z.width : z.x;
                final y = z.height < 0 ? z.y + z.height : z.y;
                final width = z.width.abs();
                final height = z.height.abs();

                return Positioned(
                  left: x,
                  top: y,
                  width: width,
                  height: height,
                  child: Stack(
                    children: [
                      if (editMode)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _deleteZone(z),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () => _assignZoneToController(z),
                              ),

                              IconButton(
                                tooltip: 'Ustaw alarmy strefy',
                                icon: Icon(
                                  Icons.notifications,
                                  size: 20,
                                  color: z.alarmActive
                                      ? Colors.red
                                      : Colors.black54,
                                ),
                                onPressed: () {
                                  if (z.id == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Strefa nie ma jeszcze ID. Zapisz strefę najpierw.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  _editZoneAlarms(z);
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),

              ...endDevices
                  .map(
                    (d) => Positioned(
                      left: d.x,
                      top: d.y,
                      child: GestureDetector(
                        onTap: () {
                          if (!editMode) {
                            setState(() => d.isExpanded = !d.isExpanded);
                          } else {
                            _editEndDevice(d);
                          }
                        },
                        onPanStart: editMode
                            ? (_) => setState(() => d.isDragging = true)
                            : null,
                        onPanUpdate: editMode
                            ? (details) => setState(() {
                                d.x += details.delta.dx;
                                d.y += details.delta.dy;
                              })
                            : null,
                        onPanEnd: editMode
                            ? (_) {
                                d.isDragging = false;
                                ApiService()
                                    .saveEndDevicePosition(d.id, d.x, d.y)
                                    .catchError(
                                      (e) => print(
                                        'Error saving end device position: $e',
                                      ),
                                    );
                              }
                            : null,
                        child: _buildEndDeviceTile(d),
                      ),
                    ),
                  )
                  .toList(),

              ...sensors
                  .map(
                    (s) => Positioned(
                      left: s.x,
                      top: s.y,
                      child: GestureDetector(
                        onTap: () => _onSensorClicked(s),
                        onPanStart: editMode && !changeLocationMode
                            ? (_) => setState(() => s.isDragging = true)
                            : null,
                        onPanUpdate: editMode && !changeLocationMode
                            ? (d) => setState(() {
                                s.x += d.delta.dx;
                                s.y += d.delta.dy;
                              })
                            : null,
                        onPanEnd: editMode && !changeLocationMode
                            ? (_) async {
                                s.isDragging = false;
                                await ApiService().saveSensorPosition(
                                  s.id,
                                  s.x,
                                  s.y,
                                );
                              }
                            : null,
                        child: _buildSensorTile(s),
                      ),
                    ),
                  )
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorTile(SensorTile sensor) {
    final double tileWidth = editMode ? 180 : (sensor.isExpanded ? 160 : 100);

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (!editMode) {
              setState(() {
                sensor.isExpanded = !sensor.isExpanded;
              });
            }
          },
          child: Container(
            width: tileWidth,
            padding: EdgeInsets.fromLTRB(8, 8, editMode ? 40 : 8, 8),

            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.sensors, color: Colors.white, size: 25),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (sensor.isExpanded || editMode)
                        Text(
                          sensor.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (editMode)
                        Text(
                          'ID: ${sensor.id}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                      if (sensor.temperature != null)
                        Text(
                          sensor.isExpanded
                              ? "Temperatura: ${sensor.temperature}°C"
                              : "T: ${_withUnit(sensor.temperature, '°C')}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),

                      if (sensor.humidity != null)
                        Text(
                          sensor.isExpanded
                              ? "Wilgotność: ${_withUnit(sensor.humidity, '%')}"
                              : "W: ${_withUnit(sensor.humidity, '%')}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),

                      if (sensor.light != null)
                        Text(
                          sensor.isExpanded
                              ? "Światło: ${_withUnit(sensor.light, ' lx')}"
                              : "Ś: ${_withUnit(sensor.light, ' lx')}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (editMode)
          Positioned(
            top: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Color.fromARGB(255, 236, 62, 50),
                    size: 18,
                  ),
                  tooltip: 'Odłącz od strefy',
                  onPressed: () async {
                    try {
                      await ApiService().unassignSensorFromZone(sensor.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sensor odłączony od strefy'),
                        ),
                      );
                      _fetchAll();
                    } catch (e) {
                      print('Error unassigning sensor: $e');
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                  tooltip: 'Edytuj sensor',
                  onPressed: () {
                    _editSensor(sensor);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEndDeviceTile(EndDeviceTile device) {
    final double tileWidth = editMode ? 150 : (device.isExpanded ? 180 : 100);

    String lightDisplay(double? light, double? upTemp, double? downTemp) {
      if (light == null) return '-';
      if (upTemp != null && light > upTemp) return 'Wyłącz';
      if (downTemp != null && light < downTemp) return 'Wyłącz';
      return light.toString();
    }

    return GestureDetector(
      onTap: () {
        if (!editMode) {
          setState(() {
            device.isExpanded = !device.isExpanded;
          });
        } else {
          _editEndDevice(device);
        }
      },
      child: Stack(
        children: [
          Container(
            width: tileWidth,
            padding: EdgeInsets.fromLTRB(6, 6, editMode ? 40 : 6, 6),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 74, 0, 126).withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.router, color: Colors.white, size: 25),
                const SizedBox(width: 6),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (device.isExpanded || editMode)
                        Text(
                          device.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      if (editMode)
                        Text(
                          'ID: ${device.id}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                      if (device.upTemp != null)
                        Text(
                          device.isExpanded || editMode
                              ? 'Temperatura wyłączenia: ${_withUnit(device.upTemp, ' °C')}'
                              : 'T↑: ${_withUnit(device.upTemp, '°C')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),

                      if (device.downTemp != null)
                        Text(
                          device.isExpanded || editMode
                              ? 'Temperatura włączenia: ${_withUnit(device.downTemp, ' °C')}'
                              : 'T↓: ${_withUnit(device.downTemp, '°C')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),

                      if (device.upHum != null)
                        Text(
                          device.isExpanded || editMode
                              ? 'Wilgotność wyłączenia: ${_withUnit(device.upHum, ' %')}'
                              : 'W↑: ${_withUnit(device.upHum, '%')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),

                      if (device.downHum != null)
                        Text(
                          device.isExpanded || editMode
                              ? 'Wilgotność włączenia: ${_withUnit(device.downHum, ' %')}'
                              : 'W↓: ${_withUnit(device.downHum, '%')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),

                      if (device.upLight != null)
                        Text(
                          device.isExpanded || editMode
                              ? 'Światło wyłączenia: ${_withUnit(device.upLight, ' lx')}'
                              : 'Ś↑: ${_withUnit(device.upLight, ' lx')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),

                      if (device.downLight != null)
                        Text(
                          device.isExpanded || editMode
                              ? 'Światło włączenia: ${_withUnit(device.downLight, ' lx')}'
                              : 'Ś↓: ${_withUnit(device.downLight, ' lx')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (editMode)
            Positioned(
              top: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Color.fromARGB(255, 245, 70, 57),
                      size: 18,
                    ),
                    tooltip: 'Odłącz od strefy',
                    onPressed: () async {
                      try {
                        await ApiService().unassignEndDeviceFromZone(device.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Urządzenie odłączone od strefy'),
                          ),
                        );
                        _fetchEndDevices();
                      } catch (e) {
                        print('Error unassigning end device: $e');
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    tooltip: 'Edytuj urządzenie',
                    onPressed: () {
                      _editEndDevice(device);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ZonesPainter extends CustomPainter {
  final List<ZoneRect> zones;
  final ZoneRect? current;

  ZonesPainter({required this.zones, this.current});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final z in zones) {
      final x = z.width < 0 ? z.x + z.width : z.x;
      final y = z.height < 0 ? z.y + z.height : z.y;
      final width = z.width.abs();
      final height = z.height.abs();

      if (z.alarmActive) {
        fillPaint.color = Colors.red.withOpacity(0.25);
        canvas.drawRect(Rect.fromLTWH(x, y, width, height), fillPaint);
      }

      strokePaint.color = z.alarmActive ? Colors.red : Colors.orange;
      canvas.drawRect(Rect.fromLTWH(x, y, width, height), strokePaint);

      _drawZoneTexts(canvas, z, x, y, width, height);
    }

    if (current != null) {
      strokePaint.color = Colors.red;
      final x = current!.width < 0 ? current!.x + current!.width : current!.x;
      final y = current!.height < 0 ? current!.y + current!.height : current!.y;
      final width = current!.width.abs();
      final height = current!.height.abs();

      canvas.drawRect(Rect.fromLTWH(x, y, width, height), strokePaint);
      _drawZoneTexts(canvas, current!, x, y, width, height);
    }
  }

  void _drawZoneTexts(
    Canvas canvas,
    ZoneRect z,
    double x,
    double y,
    double width,
    double height,
  ) {
    if (z.name.isNotEmpty) {
      final namePainter = TextPainter(
        text: TextSpan(
          text: z.name,
          style: const TextStyle(
            color: Color.fromARGB(166, 22, 137, 7),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '...',
      );

      namePainter.layout(maxWidth: width);
      namePainter.paint(
        canvas,
        Offset(x + (width - namePainter.width) / 2, y + 6),
      );
    }

    if (z.alarmActive && z.alarmReason != null) {
      final alarmPainter = TextPainter(
        text: TextSpan(
          text: '⚠ ${z.alarmReason}',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
      );

      alarmPainter.layout(maxWidth: width - 8);
      alarmPainter.paint(
        canvas,
        Offset(
          x + (width - alarmPainter.width) / 2,
          y + height / 2 - alarmPainter.height / 2,
        ),
      );
    }

    final controllerText = z.assignedController ?? '⚠ Brak!';
    final controllerPainter = TextPainter(
      text: TextSpan(
        text: 'Kontroler: $controllerText',
        style: TextStyle(
          color: z.assignedController == null ? Colors.red : Colors.blue,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    );

    controllerPainter.layout(maxWidth: width);
    controllerPainter.paint(
      canvas,
      Offset(
        x + (width - controllerPainter.width) / 2,
        y + height - controllerPainter.height - 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

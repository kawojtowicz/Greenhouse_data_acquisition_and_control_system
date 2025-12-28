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

  ZoneRect({
    this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.name,
  });
}

class SensorTile {
  final int id;
  final String name;
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
  final String name;
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
        title: Text('Edytuj ${device.name}'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _numField('Temp ↑', upTempCtrl),
              _numField('Temp ↓', downTempCtrl),
              _numField('Wilg ↑', upHumCtrl),
              _numField('Wilg ↓', downHumCtrl),
              _numField('Światło ↑', upLightCtrl),
              _numField('Światło ↓', downLightCtrl),
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
              _fetchEndDevices();
              setState(() {});
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
                  subtitle: controller.deviceToken != null
                      ? Text('Token: ${controller.deviceToken}')
                      : null,
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

  Future<void> _fetchEndDevices() async {
    try {
      final rawDevices = await ApiService().fetchEndDevices(
        widget.greenhouse.id,
      );
      print('Raw end devices: $rawDevices');

      endDevices = rawDevices.map((d) {
        print('Mapping end device: $d');
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

      print('Mapped end devices: $endDevices');
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

      print('Fetched sensors: $sensors');
    } catch (e) {
      print('Error fetching sensors: $e');
      sensors = [];
    }
  }

  Future<void> _fetchZones() async {
    final fetched = await ApiService().fetchZonesWithSensors(
      widget.greenhouse.id,
    );

    for (final z in fetched) {
      print(
        'Zone: ${z.name}, x: ${z.x}, y: ${z.y}, width: ${z.width}, height: ${z.height}',
      );
    }

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
            ),
          )
          .toList();
    });
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
    if (!changeLocationMode) return;

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
        final int zoneId = newZoneId;
        currentDrawing!.id = zoneId;
        print(
          'Zone saved to DB: $name at (${currentDrawing!.x}, ${currentDrawing!.y}) '
          'size ${currentDrawing!.width}x${currentDrawing!.height}, id: $zoneId',
        );
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
      appBar: AppBar(title: Text(widget.greenhouse.name)),
      body: RefreshIndicator(onRefresh: _fetchAll, child: _buildMainView()),

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
                  child: const Icon(Icons.crop_square),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'move',
                  backgroundColor: changeLocationMode
                      ? Colors.orange
                      : Colors.blue,
                  onPressed: toggleChangeLocationMode,
                  child: const Icon(Icons.swap_horiz),
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

                return Stack(
                  children: [
                    Positioned(
                      left: x,
                      top: y,
                      width: width,
                      height: height,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (editMode)
                            Row(
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
                                    Icons.device_hub,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  onPressed: () => _assignZoneToController(z),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),

              ...endDevices
                  .map(
                    (d) => Positioned(
                      left: d.x,
                      top: d.y,
                      child: GestureDetector(
                        onTap: () {
                          if (editMode) {
                            _editEndDevice(d);
                          } else {
                            setState(() => d.isExpanded = !d.isExpanded);
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

              ...sensors.map(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorTile(SensorTile sensor) {
    return GestureDetector(
      onTap: () {
        setState(() {
          sensor.isExpanded = !sensor.isExpanded;
        });
      },
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.sensors, color: Colors.white, size: 25),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sensor.isExpanded)
                    Text(
                      sensor.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (sensor.temperature != null)
                    Text(
                      sensor.isExpanded
                          ? 'Temperature: ${sensor.temperature}°C'
                          : 'T: ${sensor.temperature}°C',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  if (sensor.humidity != null)
                    Text(
                      sensor.isExpanded
                          ? 'Humidity: ${sensor.humidity}%'
                          : 'H: ${sensor.humidity}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  if (sensor.light != null)
                    Text(
                      sensor.isExpanded
                          ? 'Light: ${sensor.light}lx'
                          : 'L: ${sensor.light}lx',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildEndDeviceTile(EndDeviceTile device) {
  String lightDisplay(double? light, double? upTemp, double? downTemp) {
    if (light == null) return '-';
    if (upTemp != null && light > upTemp) return 'Wyłącz';
    if (downTemp != null && light < downTemp) return 'Wyłącz';
    return light.toString();
  }

  return Container(
    width: 100,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.purple.withOpacity(0.7),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.device_hub, color: Colors.white, size: 20),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                device.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (device.upTemp != null)
          Text(
            'T↑: ${device.upTemp}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        if (device.downTemp != null)
          Text(
            'T↓: ${device.downTemp}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        if (device.upHum != null)
          Text(
            'H↑: ${device.upHum}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        if (device.downHum != null)
          Text(
            'H↓: ${device.downHum}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        if (device.upLight != null)
          Text(
            'L↑: ${device.isExpanded ? lightDisplay(device.upLight, device.upTemp, device.downTemp) : device.upLight}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        if (device.downLight != null)
          Text(
            'L↓: ${device.isExpanded ? lightDisplay(device.downLight, device.upTemp, device.downTemp) : device.downLight}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
      ],
    ),
  );
}

class ZonesPainter extends CustomPainter {
  final List<ZoneRect> zones;
  final ZoneRect? current;

  ZonesPainter({required this.zones, this.current});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    paint.color = Colors.orange;
    for (final z in zones) {
      final x = z.width < 0 ? z.x + z.width : z.x;
      final y = z.height < 0 ? z.y + z.height : z.y;
      final width = z.width.abs();
      final height = z.height.abs();

      canvas.drawRect(Rect.fromLTWH(x, y, width, height), paint);
      _drawZoneName(canvas, z.name, x, y, width, height);
    }

    if (current != null) {
      paint.color = Colors.red;
      final x = current!.width < 0 ? current!.x + current!.width : current!.x;
      final y = current!.height < 0 ? current!.y + current!.height : current!.y;
      final width = current!.width.abs();
      final height = current!.height.abs();

      canvas.drawRect(Rect.fromLTWH(x, y, width, height), paint);
      _drawZoneName(canvas, current!.name, x, y, width, height);
    }
  }

  void _drawZoneName(
    Canvas canvas,
    String name,
    double x,
    double y,
    double width,
    double height,
  ) {
    if (name.isEmpty) return;

    final textSpan = TextSpan(
      text: name,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    textPainter.layout(minWidth: 0, maxWidth: width);
    final offset = Offset(
      x + (width - textPainter.width) / 2,
      y + (height - textPainter.height) / 2,
    );

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// import 'package:flutter/material.dart';
// import '../models/greenhouse_controller.dart';
// import '../services/api_service.dart';

// class GreenhouseViewPage extends StatefulWidget {
//   final GreenhouseController controller;

//   const GreenhouseViewPage({super.key, required this.controller});

//   @override
//   State<GreenhouseViewPage> createState() => _GreenhouseViewPageState();
// }

// class _GreenhouseViewPageState extends State<GreenhouseViewPage> {
//   late double _temperature;
//   double? _lastTemp;
//   int? _lastHumidity;
//   int? _lastLight;
//   List<Map<String, dynamic>> _lastLogs = [];

//   @override
//   void initState() {
//     super.initState();
//     _temperature = widget.controller.temperatureSet;
//     _fetchLastLogs();
//   }

//   Future<void> _fetchLastLogs() async {
//     final logs = await ApiService().fetchLastHTLLogs(widget.controller.id);
//     setState(() => _lastLogs = logs);
//   }

//   Future<void> _refreshAll() async {
//     await _fetchLastLogs();
//     setState(() {
//       _temperature = widget.controller.temperatureSet;
//     });
//   }

//   void _showChangeTemperatureDialog() {
//     final TextEditingController tempController = TextEditingController(
//       text: _temperature.toStringAsFixed(1),
//     );

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Zmień temperaturę'),
//         content: TextField(
//           controller: tempController,
//           keyboardType: const TextInputType.numberWithOptions(decimal: true),
//           decoration: const InputDecoration(labelText: 'Nowa temperatura'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Anuluj'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               final newTemp = double.tryParse(tempController.text);
//               if (newTemp == null) return;

//               final success = await ApiService().updateGreenhouseTemperature(
//                 widget.controller.id,
//                 newTemp,
//               );

//               if (success) {
//                 setState(() => _temperature = newTemp);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Temperatura zaktualizowana')),
//                 );
//                 Navigator.of(context).pop();
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Nie udało się zmienić temperatury'),
//                   ),
//                 );
//               }
//             },
//             child: const Text('Zatwierdź'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final controller = widget.controller;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(controller.greenhouseName),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: RefreshIndicator(
//         onRefresh: _refreshAll,
//         child: SingleChildScrollView(
//           physics: const AlwaysScrollableScrollPhysics(),
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               children: [
//                 Card(
//                   elevation: 4,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Padding(
//                     padding: const EdgeInsets.all(24),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Icon(
//                           Icons.thermostat,
//                           size: 64,
//                           color: Colors.redAccent,
//                         ),
//                         const SizedBox(height: 16),
//                         const Text(
//                           'Temperatura zadana:',
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           '${_temperature.toStringAsFixed(1)} °C',
//                           style: const TextStyle(
//                             fontSize: 32,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.blue,
//                           ),
//                         ),
//                         const SizedBox(height: 16),
//                         ElevatedButton(
//                           onPressed: _showChangeTemperatureDialog,
//                           child: const Text('Zmień temperaturę'),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//                 Card(
//                   elevation: 4,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Padding(
//                     padding: const EdgeInsets.all(24),
//                     child: Column(
//                       children: _lastLogs.isEmpty
//                           ? [const Text('Brak logów')]
//                           : _lastLogs.map((log) {
//                               print("UI LOG: $log"); // DEBUG
//                               return ListTile(
//                                 leading: const Icon(Icons.sensors),
//                                 title: Text('Czujnik ${log['id_sensor_node']}'),
//                                 subtitle: Text(
//                                   'T=${log['temperature']}°C | H=${log['humidity']}% | L=${log['light']} lx',
//                                 ),
//                               );
//                             }).toList(),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import '../models/greenhouse_controller.dart';
import '../services/api_service.dart';

class GreenhouseViewPage extends StatefulWidget {
  final GreenhouseController controller;

  const GreenhouseViewPage({super.key, required this.controller});

  @override
  State<GreenhouseViewPage> createState() => _GreenhouseViewPageState();
}

class _GreenhouseViewPageState extends State<GreenhouseViewPage> {
  late double _temperature;
  List<Map<String, dynamic>> _lastLogs = [];

  bool editMode = false; // tryb przesuwania kafelków
  List<SensorTile> sensors = []; // kafelki sensorów

  @override
  void initState() {
    super.initState();
    _temperature = widget.controller.temperatureSet;
    _fetchLastLogs();
  }

  Future<void> _fetchLastLogs() async {
    final logs = await ApiService().fetchLastHTLLogs(widget.controller.id);

    sensors = logs.map((log) {
      return SensorTile(
        id: log['id_sensor_node'],
        name: '${log['id_sensor_node']}',
        x: 50.0 + (log['id_sensor_node'] * 60) % 200,
        y: 50.0 + (log['id_sensor_node'] * 80) % 300,
        temperature: log['temperature'],
        humidity: log['humidity'],
        light: log['light'],
      );
    }).toList();

    setState(() {
      _lastLogs = logs;
    });
  }

  Future<void> _refreshAll() async {
    await _fetchLastLogs();
    setState(() {
      _temperature = widget.controller.temperatureSet;
    });
  }

  void toggleEditMode() {
    setState(() {
      editMode = !editMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.controller.greenhouseName)),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 700,
            child: InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              minScale: 0.5,
              maxScale: 3.0,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: Colors.green[50],
                      child: const Center(
                        child: Text(
                          'Plan szklarni',
                          style: TextStyle(fontSize: 24, color: Colors.green),
                        ),
                      ),
                    ),
                  ),
                  ...sensors.map((sensor) {
                    return Positioned(
                      left: sensor.x,
                      top: sensor.y,
                      child: GestureDetector(
                        onPanUpdate: editMode
                            ? (details) {
                                setState(() {
                                  sensor.x += details.delta.dx;
                                  sensor.y += details.delta.dy;
                                });
                              }
                            : null,
                        child: Container(
                          width: 100,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 88, 189, 239),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color.fromARGB(255, 88, 189, 239),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.sensors, color: Colors.white),
                              const SizedBox(height: 1),
                              Text(
                                sensor.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'T: ${sensor.temperature}°C',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'H: ${sensor.humidity}%',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'L: ${sensor.light} lx',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: toggleEditMode,
                      backgroundColor: editMode
                          ? Colors.green
                          : const Color.fromARGB(255, 95, 229, 200),
                      child: Icon(editMode ? Icons.check : Icons.edit),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SensorTile {
  int id;
  String name;
  double x;
  double y;
  dynamic temperature;
  dynamic humidity;
  dynamic light;

  SensorTile({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.temperature,
    this.humidity,
    this.light,
  });
}

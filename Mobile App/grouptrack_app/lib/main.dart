import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Group Track',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 97, 182, 52)),
      ),
      home: const MyHomePage(title: 'GroupTrack'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _dataSubscription;

  BluetoothDevice? _connectedDevice;
  bool _isConnected = false;
  bool _connectionFailed = false;
  String _connectionError = '';
  Timer? _keepAliveTimer;

  Map<String, dynamic>? _receivedData;

  @override void initState(){
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async{
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
    print("Bluetooth ist ausgeschaltet");
    return;
    }

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });
  }


  void _sendTimestamp() async {
  if (_connectedDevice == null || !_isConnected) return;

  // Diese UUID muss exakt mit #define CTRL_UUID im C++ Code übereinstimmen
  const String ctrlUuid = "7c9a0003-6b6a-4f8f-9c8a-1b2c3d4e5f60";

  try {
    List<BluetoothService> services = await _connectedDevice!.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        // Wir prüfen gezielt auf die Control-UUID
        if (characteristic.uuid.toString().toLowerCase() == ctrlUuid.toLowerCase()) {
          String timestamp = DateTime.now().toIso8601String().substring(11, 19);
          String message = "TS: $timestamp";
          
          await characteristic.write(utf8.encode(message));
          print("Timestamp an Hardware gesendet: $message");
          return;
        }
      }
    }
  } 
  catch (e) {
    print("Fehler beim Senden des Heartbeats: $e");
  }
  
  }

  void _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _connectionFailed = false;
      _connectionError = '';
    });

    try {
      _connectionSubscription = device.connectionState.listen((state) {
        setState(() {
          _isConnected = state == BluetoothConnectionState.connected;
          if (_isConnected) {
            _connectedDevice = device;
            _connectionFailed = false;
            _startReceivingData(device);
            _keepAliveTimer?.cancel();
            _keepAliveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              _sendTimestamp();
            });
          }
        });
      });

      await device.connect(timeout: const Duration(seconds: 15));
      print("Verbunden mit ${device.advName}");

    } catch (e) {
      setState(() {
        _connectionFailed = true;
        _connectionError = e.toString();
        _isConnected = false;
        _connectedDevice = null;
      });
      print("Verbindung fehlgeschlagen: $e");
    }
  }

  Future<void> _startReceivingData(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            _dataSubscription = characteristic.lastValueStream.listen((value) {
              if (value.isNotEmpty) {
                try {
                  String dataString = utf8.decode(value);
                  Map<String, dynamic> jsonData = json.decode(dataString);
                  
                  setState(() {
                    _receivedData = jsonData;
                  });
                  
                  print("Empfangene Daten: $jsonData");
                } catch (e) {
                  print("Fehler beim Parsen der Daten: $e");
                }
              }
            });
            break;
          }
        }
      }
    } catch (e) {
      print("Fehler beim Empfangen von Daten: $e");
    }
  }

  void _disconnect() async {
  _keepAliveTimer?.cancel();
  _keepAliveTimer = null;
  if (_connectedDevice != null) {
    try {
      await _dataSubscription?.cancel();
      _dataSubscription = null;

      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(false);
          }
        }
      }

      await _connectedDevice!.disconnect();
      
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;

      setState(() {
        _connectedDevice = null;
        _isConnected = false;
        _receivedData = null;
        _scanResults = []; 
      });

      print("Sauber getrennt.");
      } catch (e) {
        print("Fehler beim Trennen: $e");
        setState(() {
          _isConnected = false;
          _connectedDevice = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 124, 184, 127),
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isConnected)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth_connected, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Verbunden',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                            Text(
                              _connectedDevice?.advName.isNotEmpty == true 
                                  ? _connectedDevice!.advName 
                                  : _connectedDevice?.platformName ?? 'Unbekannt',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_connectionFailed)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Verbindung fehlgeschlagen',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                            Text(
                              _connectionError,
                              style: const TextStyle(fontSize: 10),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 15),
            
            if (!_isConnected) ...[
              const Text("Gefundene Geräte:", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(
                height: 350,
                child: ListView.builder(
                  itemCount: _scanResults.length,
                  itemBuilder: (context, index) {
                    final res = _scanResults[index];
                    String name = res.advertisementData.advName.isNotEmpty
                        ? res.advertisementData.advName
                        : (res.device.platformName.isNotEmpty ? res.device.platformName : "Unbekannt");
                    return ListTile(
                      leading: Icon(Icons.bluetooth, color: name == "HTL-TRACKER" ? Colors.green : Colors.grey),
                      title: Text(name),
                      subtitle: Text(res.device.remoteId.toString()),
                      onTap: () => _connectToDevice(res.device),
                    );
                  },
                ),
              ),
              const SizedBox(height: 15),
            ],
            
            if (_isConnected && _receivedData != null) ...[
              const Text("Empfangene Daten:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDataRow('Message', _receivedData!['msg']?.toString() ?? 'N/A'),
                      const Divider(),
                      _buildDataRow('RSSI', _receivedData!['rssi']?.toString() ?? 'N/A'),
                      const Divider(),
                      _buildDataRow('SNR', _receivedData!['snr']?.toString() ?? 'N/A'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
            ] else if (_isConnected) ...[
              const Text("Warte auf Daten...", style: TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 15),
            ],
            
            if (_isConnected && _receivedData != null) ...[
              const Text("Empfangene Daten:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    height: 200,
                    child: DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      minWidth: 300,
                      columns: const [
                        DataColumn2(
                          label: Text('Nr.', style: TextStyle(fontWeight: FontWeight.bold)),
                          size: ColumnSize.S,
                        ),
                        DataColumn2(
                          label: Text('Distanz (m)', style: TextStyle(fontWeight: FontWeight.bold)),
                          size: ColumnSize.L,
                        ),
                      ],
                      rows: const [
                        DataRow(cells: [
                          DataCell(Text('10')),
                          DataCell(Text('200')),
                        ]),
                        DataRow(cells: [
                          DataCell(Text('2')),
                          DataCell(Text('10')),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
            ] else if (_isConnected) ...[
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text("Warte auf Daten...", style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(height: 15),
            ]
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
      backgroundColor: _isConnected 
          ? Colors.redAccent
          : const Color.fromARGB(255, 124, 184, 127),
      foregroundColor: Colors.white,
      onPressed: _isConnected ? _disconnect : _startScan,
      tooltip: _isConnected ? 'Verbindung trennen' : 'Scan aktualisieren',
      child: Icon(_isConnected ? Icons.bluetooth_disabled : Icons.update),
    ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }
}

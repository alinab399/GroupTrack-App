import 'dart:async';
import 'package:flutter/foundation.dart';
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
        colorScheme: .fromSeed(seedColor: const Color.fromARGB(255, 97, 182, 52)),
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

  @override void initState(){
    super.initState();
    _startScan();
  }

  void _startScan(){
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    _scanSubscription = FlutterBluePlus.onScanResults.listen((results){
      setState((){
        _scanResults = results;
      });
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    await device.connect();
    print("Verbunden mit ${device.advName}");

    // TODO: DATEN EMPFANGEN
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Gefundene Geräte:", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(
                height: 150,
                child: ListView.builder(itemCount: _scanResults.length,
                itemBuilder: (context, index){
                  final res = _scanResults[index];
                  return ListTile(
                    title: Text(res.device.advName.isEmpty ? "Unbekannt" : res.device.advName),
                    subtitle: Text(res.device.remoteId.toString()),
                    onTap: () => _connectToDevice(res.device),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: DataTable2(
                columnSpacing: 12,
                horizontalMargin: 12,
                columns: const[
                  DataColumn2(label: Text('Nr.')),
                  DataColumn2(label: Text('Distanz (m)'))
                ],
                rows: const[
                  DataRow(cells: [
                    DataCell(Text('10')),
                    DataCell(Text('200')),
                  ]),
                  DataRow(cells: [
                    DataCell(Text('2')),
                    DataCell(Text('10')),
                  ])
                ],
                )
            
            )
          ],
        )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startScan,
        tooltip: 'Update',
        child: const Icon(Icons.update),
      ),
    );
  }
}

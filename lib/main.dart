import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TicketPrintScreen(),
    );
  }
}

class TicketPrintScreen extends StatefulWidget {
  @override
  _TicketPrintScreenState createState() => _TicketPrintScreenState();
}

class _TicketPrintScreenState extends State<TicketPrintScreen> {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  String lotNumber = '';
  String partNumber = '';
  String qty = '';

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  void requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    initBluetooth();
  }

  void initBluetooth() {
    bluetooth.onStateChanged().listen((state) {
      setState(() {
        _isConnected = state == BlueThermalPrinter.CONNECTED;
      });
    });

    bluetooth.getBondedDevices().then((List<BluetoothDevice> devices) {
      setState(() {
        _devices = devices;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Ticket'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Lot Number'),
              onChanged: (value) {
                setState(() {
                  lotNumber = value;
                });
              },
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Part Number'),
              onChanged: (value) {
                setState(() {
                  partNumber = value;
                });
              },
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Qty'),
              onChanged: (value) {
                setState(() {
                  qty = value;
                });
              },
            ),
            const SizedBox(height: 20),
            DropdownButton<BluetoothDevice>(
              items: _devices
                  .map((device) => DropdownMenuItem(
                        child: Text(device.name!),
                        value: device,
                      ))
                  .toList(),
              onChanged: (BluetoothDevice? value) {
                setState(() {
                  _selectedDevice = value;
                });
              },
              value: _selectedDevice,
              hint: const Text('Select Printer'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_selectedDevice != null) {
                  if (_isConnected) {
                    _disconnectFromDevice();
                  } else {
                    _connectToDevice(_selectedDevice!);
                  }
                } else {
                  _showMessage('Please select a printer first.');
                }
              },
              child: Text(_isConnected ? 'Disconnect' : 'Connect to Printer'),
            ),
            if (_isConnected)
              const Text(
                'Bluetooth is connected',
                style: TextStyle(color: Colors.green),
              ),
            ElevatedButton(
              onPressed: _isConnected ? _printTicket : null,
              child: const Text('Print Ticket'),
            ),
          ],
        ),
      ),
    );
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await bluetooth.connect(device);
      setState(() {
        _isConnected = true;
      });
      _showMessage('Connected to ${device.name}');
    } catch (e) {
      _showMessage('Failed to connect to ${device.name}: $e');
    }
  }

  void _disconnectFromDevice() async {
    try {
      await bluetooth.disconnect();
      setState(() {
        _isConnected = false;
      });
      _showMessage('Disconnected from printer');
    } catch (e) {
      _showMessage('Failed to disconnect: $e');
    }
  }

  void _printTicket() async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected == true) {
         var response = await http.get(Uri.parse(
        "https://raw.githubusercontent.com/GalangPratamaS/image/main/sm-logo.png"));
    Uint8List bytesNetwork = response.bodyBytes;
    Uint8List imageBytesFromNetwork = bytesNetwork.buffer
        .asUint8List(bytesNetwork.offsetInBytes, bytesNetwork.lengthInBytes);

      bluetooth.printNewLine();
      bluetooth.printCustom('CURING TAG CARD', 3, 1);
      bluetooth.printNewLine();
      bluetooth.printImageBytes(imageBytesFromNetwork);
      bluetooth.printNewLine();
      bluetooth.printLeftRight('Lot Number:', lotNumber, 1);
      bluetooth.printLeftRight('Part Number:', partNumber, 1);
      bluetooth.printLeftRight('Qty:', qty, 1);
      bluetooth.printNewLine();
     final qrCodeData = '$lotNumber-$partNumber-$qty';
      bluetooth.printQRcode(qrCodeData, 200, 200, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("Body right", 3, 2);
      bluetooth.printNewLine();
      bluetooth.print3Column("Col1", "Col2", "Col3", 1);
      bluetooth.printNewLine();
      bluetooth.paperCut();
        _showMessage('Ticket printed successfully.');
      } else {
        _showMessage('Printer not connected');
      }
    } catch (e) {
      _showMessage('Failed to print ticket: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
    ));
  }
}

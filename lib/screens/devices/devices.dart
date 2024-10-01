import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class Devices extends StatefulWidget {
  const Devices({super.key});

  @override
  _DevicesState createState() => _DevicesState();
}

class _DevicesState extends State<Devices> {
  List<String> availableDevices = [];
  String weight = '';
  File? logFile;

  @override
  void initState() {
    super.initState();
    _initializeLogFile();
    _scanDevices();
    // _requestPermissions();
  }

  Future<void> _initializeLogFile() async {
    // Get the directory path where the log file will be stored
    Directory appDocDirectory = await getApplicationDocumentsDirectory();
    String logFilePath = '${appDocDirectory.path}/scale_logs.txt';
    logFile = File(logFilePath);
    await logFile?.writeAsString('Log initialized on ${DateTime.now()}\n');
    print('Log file initialized at: $logFilePath');
  }

  Future<void> _writeToLogFile(String message) async {
    if (logFile != null) {
      await logFile!.writeAsString('$message\n', mode: FileMode.append);
    }
  }

  // Future<void> _requestPermissions() async {
  //   // Request location permission
  //   if (await Permission.location.request().isGranted) {
  //     // Request USB permission
  //     if (await Permission.manageExternalStorage.request().isGranted) {
  //       // Permissions are granted, proceed with scanning devices
  //       _scanDevices();
  //     } else {
  //       // Handle USB permission denied
  //       print("USB permission denied");
  //     }
  //   } else {
  //     // Handle location permission denied
  //     print("Location permission denied");
  //   }
  // }

  void _scanDevices() {
    setState(() {
      // Get list of all available USB serial devices
      availableDevices = SerialPort.availablePorts;
      print('availableDevices ******** $availableDevices');
      _writeToLogFile('Available devices: $availableDevices');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Devices'),
      ),
      body: ListView.builder(
        itemCount: availableDevices.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(availableDevices[index]),
            onTap: () {
              // On tap, you can handle connecting to the selected device
              _connectToDevice(availableDevices[index]);
            },
          );
        },
      ),
    );
  }

  void _connectToDevice(String port) async {
    try {
      final SerialPort serialPort = SerialPort(port);
      if (serialPort.openReadWrite()) {
        _writeToLogFile('Connected to $port');

        var config = SerialPortConfig();
        config.baudRate = 9600;
        config.bits = 8;
        config.parity = SerialPortParity.none;
        config.stopBits = 1;

        serialPort.config = config;
        _writeToLogFile(
            'Serial Port Config: BaudRate: ${config.baudRate}, Bits: ${config.bits}, Parity: ${config.parity}, StopBits: ${config.stopBits}');
        config.dispose();
        _writeToLogFile(
            'Serial Port Config after dispose(): BaudRate: ${config.baudRate}, Bits: ${config.bits}, Parity: ${config.parity}, StopBits: ${config.stopBits}');

        final reader = SerialPortReader(serialPort);
        reader.stream.listen((data) {
          _logDataInfo(data); // Log data information

          final decodedData = String.fromCharCodes(data);
          _writeToLogFile('Decoded data (assuming ASCII): $decodedData');

          // Detect if the data might not be ASCII
          if (!_isASCII(data)) {
            _writeToLogFile('Warning: Non-ASCII data detected.');
          }

          _showWeightDialog(decodedData);
        });
      } else {
        _writeToLogFile('Failed to open port: $port');
      }
    } catch (e) {
      _writeToLogFile('Error: $e');
    }
  }

  void _logDataInfo(Uint8List data) {
    _writeToLogFile('Raw byte data: $data');
    for (var byte in data) {
      _writeToLogFile(
          'Byte: $byte (${byte.toRadixString(16).toUpperCase()} in hex)');
    }
  }

// Check if the data is ASCII
  bool _isASCII(Uint8List data) {
    return data
        .every((byte) => byte >= 32 && byte <= 126); // Printable ASCII range
  }

  void _showWeightDialog(String decodedData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Weight Data'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weight: $decodedData',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
    _writeToLogFile('Displayed weight: $decodedData');
  }
}

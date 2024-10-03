import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

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

        // var config = SerialPortConfig();
        // config.baudRate = 9600;
        // config.bits = 8;
        // config.parity = SerialPortParity.none;
        // config.stopBits = 1;
        // config.setFlowControl(SerialPortFlowControl.none);

        // serialPort.config = config;
        // _writeToLogFile(
        //     'Serial Port Config: BaudRate: ${config.baudRate}, Bits: ${config.bits}, Parity: ${config.parity}, StopBits: ${config.stopBits}');
        // config.dispose();

        var config = SerialPortConfig()
          ..baudRate = 9600
          ..bits = 8
          ..parity = SerialPortParity.none
          ..stopBits = 1
          ..xonXoff = 0
          ..rts = 1
          ..cts = 0
          ..dsr = 0
          ..dtr = 1;
        serialPort.config = config;
        config.dispose();

        final reader = SerialPortReader(serialPort, timeout: 3000);
        reader.stream.listen((data) {
          try {
            final decodedData = String.fromCharCodes(data);
            _writeToLogFile('Decoded data: $decodedData');
            _writeToLogFile('Raw data: $data');

            // if (!_isASCII(data)) {
            //   _writeToLogFile('Warning: Non-ASCII data detected.');
            //   // _logPossibleDataTypes(
            //   //     data); // Log possible non-ASCII data formats
            // }

            _showWeightDialog(decodedData);
          } catch (e) {
            // Log any errors during decoding
            _writeToLogFile('Error decoding data: $e');
          }
        });
      } else {
        _writeToLogFile('Failed to open port: $port');
      }
    } catch (e) {
      _writeToLogFile('Error: $e');
    }
  }

  void _logDataInfo(Uint8List data) {
    // Log the raw byte data before any decoding
    _writeToLogFile('Raw byte data: $data');
    for (var byte in data) {
      _writeToLogFile(
          'Byte: $byte (${byte.toRadixString(16).toUpperCase()} in hex)');
    }

    // Log the length of the data received
    _writeToLogFile('Data length: ${data.length}');
  }

// Check if the data is ASCII
  bool _isASCII(Uint8List data) {
    return data
        .every((byte) => byte >= 32 && byte <= 126); // Printable ASCII range
  }

// Log possible data types if non-ASCII data is detected
  void _logPossibleDataTypes(Uint8List data) {
    // Log as hexadecimal
    String hexString =
        data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
    _writeToLogFile('Data in hex: $hexString');

    // Log as binary
    String binaryString =
        data.map((byte) => byte.toRadixString(2).padLeft(8, '0')).join(' ');
    _writeToLogFile('Data in binary: $binaryString');

    // Try decoding as UTF-8 (in case it's a different text encoding)
    try {
      String utf8Data = utf8.decode(data);
      _writeToLogFile('Decoded data (UTF-8): $utf8Data');
    } catch (e) {
      _writeToLogFile('Failed to decode data as UTF-8: $e');
    }

    // Log a possible integer interpretation (e.g., weight could be encoded as integers)
    if (data.length >= 2) {
      int integerValue = _parseInteger(data);
      _writeToLogFile('Interpreted data as integer: $integerValue');
    }
  }

// Helper function to parse integer values from the byte array
  int _parseInteger(Uint8List data) {
    // Assume big-endian and 16-bit or 32-bit integer based on data length
    int result = 0;
    for (var byte in data) {
      result = (result << 8) | byte;
    }
    return result;
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

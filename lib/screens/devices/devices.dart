import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:permission_handler/permission_handler.dart';

class Devices extends StatefulWidget {
  const Devices({super.key});

  @override
  _DevicesState createState() => _DevicesState();
}

class _DevicesState extends State<Devices> {
  List<String> availableDevices = [];
  String weight = '';

  @override
  void initState() {
    super.initState();
    _scanDevices();
    // _requestPermissions();
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

  // Method to connect to the device and show a popup with weight data
  void _connectToDevice(String port) async {
    try {
      final SerialPort serialPort = SerialPort(port);
      if (serialPort.openReadWrite()) {
        print('Connected to $port');

        // Set up a reader to continuously read from the port
        final reader = SerialPortReader(serialPort);

        // Listen to the incoming data stream from the serial device
        reader.stream.listen((data) {
          // Assuming the scale sends weight data as bytes, we decode it to a string
          final weight = String.fromCharCodes(data);
          print('Received weight: $weight');

          // Show the weight in a dialog
          _showWeightDialog(weight);
        });
      } else {
        print('Failed to open port: $port');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Show the weight data in a popup dialog
  void _showWeightDialog(String weight) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Weight Data'),
          content: Text('Weight: $weight'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
  // void _connectToDevice(String port) {
  //   try {
  //     final SerialPort serialPort = SerialPort(port);
  //     if (serialPort.openReadWrite()) {
  //       print('Connected to $port');
  //       // Once connected, you can start receiving data from the scale here
  //     } else {
  //       print('Failed to open port: $port');
  //     }
  //   } catch (e) {
  //     print('Error: $e');
  //   }
  // }



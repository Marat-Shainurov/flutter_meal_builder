import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_serial_communication/flutter_serial_communication.dart';
import 'package:flutter_serial_communication/models/device_info.dart';
import 'dart:typed_data';

class Devices extends StatefulWidget {
  const Devices({super.key});

  @override
  _DevicesState createState() => _DevicesState();
}

class _DevicesState extends State<Devices> {
  List<DeviceInfo> availableDevices = [];
  String weight = '';
  String rawDataString = '';
  bool isPopupVisible = false;
  File? logFile;
  final _flutterSerialCommunicationPlugin = FlutterSerialCommunication();
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  void _scanDevices() async {
    try {
      List<DeviceInfo> devices =
          await _flutterSerialCommunicationPlugin.getAvailableDevices();
      setState(() {
        availableDevices = devices;
      });

      print(
          'Available devices: ${devices.map((d) => d.productName).join(", ")}');
    } catch (e) {
      print('Error scanning devices: $e');
    }
  }

  void _connectToDevice(DeviceInfo device) async {
    try {
      int baudRate = 9600;

      bool isConnectionSuccess =
          await _flutterSerialCommunicationPlugin.connect(device, baudRate);

      if (isConnectionSuccess) {
        print('Connected to device: ${device.productName}');

        await _flutterSerialCommunicationPlugin.setParameters(
            baudRate, 8, 1, 0);

        setState(() {
          isConnected = true;
        });

        _startListeningForWeight();
      } else {
        print('Failed to connect to device: ${device.productName}');
      }
    } catch (e) {
      print('Error connecting to device: $e');
    }
  }

  void _startListeningForWeight() {
    _flutterSerialCommunicationPlugin
        .getSerialMessageListener()
        .receiveBroadcastStream()
        .listen((event) {
      try {
        // Raw data from the scales
        Uint8List rawData = event;

        // Decoded data (interpreted as string/weight)
        String decodedData = String.fromCharCodes(rawData);

        // Ensure decodedData is valid and contains weight data
        if (decodedData.trim().isNotEmpty) {
          setState(() {
            weight = decodedData;
            rawDataString = rawData
                .map((e) => e.toRadixString(16).padLeft(2, '0'))
                .join(' ');
          });

          // Show or update the weight dialog with throttling
          if (!isPopupVisible) {
            _showWeightDialog(decodedData, rawData);
          } else {
            // Update the popup contents if already visible
            Navigator.of(context).pop(); // Close previous popup
            _showWeightDialog(decodedData, rawData); // Open new popup
          }
        }
      } catch (e) {
        print('Error decoding data: $e');
      }
    });
  }

  void _showWeightDialog(String decodedData, Uint8List rawData) {
    // Mark the popup as visible
    isPopupVisible = true;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissals
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Weight"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Decoded Weight: $decodedData"),
              SizedBox(height: 16.0),
              Text(
                  "Raw Data: ${rawData.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}"),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Close"),
              onPressed: () {
                isPopupVisible = false; // Mark the popup as closed
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
    print(
        'Displayed weight: $decodedData, Raw Data: ${rawData.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');
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
            title: Text(availableDevices[index].productName),
            onTap: () {
              _connectToDevice(availableDevices[index]);
            },
          );
        },
      ),
    );
  }
}

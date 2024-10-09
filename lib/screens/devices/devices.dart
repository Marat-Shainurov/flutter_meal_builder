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
  String weight = ''; // To hold the decoded weight data
  String rawDataString = ''; // To hold raw data as a string
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

        // Update the state to display the decoded and raw data
        setState(() {
          weight = decodedData;
          rawDataString =
              rawData.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
        });
      } catch (e) {
        print('Error decoding data: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Devices'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
          ),
          // Display weight and raw data at the bottom of the screen
          Container(
            padding: EdgeInsets.all(16.0),
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Decoded Weight: $weight',
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.0),
                Text(
                  'Raw Data: $rawDataString',
                  style: TextStyle(fontSize: 14.0, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

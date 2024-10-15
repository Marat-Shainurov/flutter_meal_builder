import 'package:flutter/material.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';
import 'package:flutter_meal_builder/services/odoo_service.dart';
import 'package:flutter_meal_builder/screens/home/home.dart';
import 'package:flutter_serial_communication/flutter_serial_communication.dart';
import 'package:flutter_serial_communication/models/device_info.dart';
import 'dart:typed_data';

class KitchenWeighingProcess extends StatefulWidget {
  final dynamic record; // Weighing record passed from the Home widget

  const KitchenWeighingProcess({Key? key, required this.record})
      : super(key: key);

  @override
  _KitchenWeighingProcessState createState() => _KitchenWeighingProcessState();
}

class _KitchenWeighingProcessState extends State<KitchenWeighingProcess> {
  bool isLoading = false;
  int currentIndex = 0;
  TextEditingController weightController = TextEditingController();
  Map<String, Map<String, dynamic>> weighingProcess = {};
  double _progressValue = 0;
  dynamic currentTotalWeight = 0.0;
  final OdooService odooService = OdooService('https://evo.migom.cloud');

  final _flutterSerialCommunicationPlugin = FlutterSerialCommunication();
  bool isConnected = false;
  String decodedWeight = ''; // To hold the decoded weight data from scale
  String rawDataString = ''; // To hold raw data as a string
  List<int> buffer = []; // Buffer to accumulate incoming data
  String deviceName = 'No device found';
  double startWeight = 0; // Start weight for the current SKU
  double accumulatedWeight = 0; // Total accumulated weight

  bool getFromScales = false; // To manage the checkbox

  @override
  void initState() {
    super.initState();
    weightController.addListener(_updateProgressBar);
    // Skip already weighed SKUs on initialization
    _skipWeighedSKUs();

    // Initiate connection to USB-Serial Controller
    _connectToUSBSerialController();
  }

  // Method to connect to 'USB-Serial Controller'
  void _connectToUSBSerialController() async {
    try {
      List<DeviceInfo> devices =
          await _flutterSerialCommunicationPlugin.getAvailableDevices();

      if (devices.isNotEmpty) {
        DeviceInfo usbSerialController = devices.first;

        int baudRate = 9600;
        bool isConnectionSuccess = await _flutterSerialCommunicationPlugin
            .connect(usbSerialController, baudRate);

        if (isConnectionSuccess) {
          print('Connected to ${usbSerialController.productName}');
          await _flutterSerialCommunicationPlugin.setParameters(
              baudRate, 8, 1, 0);

          setState(() {
            isConnected = true;
            deviceName = usbSerialController.productName;
          });

          _startListeningForWeight(); // Start receiving data
        } else {
          print('Failed to connect to ${usbSerialController.productName}');
        }
      } else {
        setState(() {
          deviceName = 'No device found';
        });
        print('No devices available');
      }
    } catch (e) {
      setState(() {
        deviceName = 'Connection error';
      });
      print('Error connecting to device: $e');
    }
  }

  // Method to listen to the data from the USB-Serial Controller
  void _startListeningForWeight() {
    _flutterSerialCommunicationPlugin
        .getSerialMessageListener()
        .receiveBroadcastStream()
        .listen((event) {
      try {
        Uint8List rawData = event;
        buffer.addAll(rawData);

        int gIndex = buffer.indexWhere((byte) => byte == 0x67); // 'g' character

        if (gIndex != -1) {
          Uint8List messageBytes =
              Uint8List.fromList(buffer.sublist(0, gIndex + 1));
          buffer.removeRange(0, gIndex + 1);

          String decodedData = String.fromCharCodes(messageBytes);

          setState(() {
            decodedWeight = decodedData;
            rawDataString = messageBytes
                .map((e) => e.toRadixString(16).padLeft(2, '0'))
                .join(' ');

            // Automatically apply the weight if the checkbox is checked
            if (getFromScales) {
              weightController.text = decodedWeight.replaceAll('g', '').trim();
            }
          });
        }

        if (buffer.length > 40) {
          buffer.clear();
        }
      } catch (e) {
        print('Error decoding data: $e');
      }
    });
  }

// Method to skip SKUs that have already been weighed
  void _skipWeighedSKUs() {
    while (currentIndex < widget.record['items'].length &&
        widget.record['items'][currentIndex]['fact'] != 0) {
      accumulatedWeight += widget.record['items'][currentIndex]['fact'];
      currentIndex++; // Skip to next SKU if 'fact' is not 0
    }
    setState(() {
      startWeight =
          accumulatedWeight; // Set startWeight for the next unweighed SKU
      currentTotalWeight = widget.record['current_total_weight'];
    });
  }

  // Update progress bar based on the current weight and total weight
  void _updateProgressBar() {
    final currentItem = widget.record['items'][currentIndex];
    double weight = double.tryParse(weightController.text) ?? 0;
    double expectation = currentItem['expectation'];
    double maxBarValue = expectation * 1.05;
    setState(() {
      // Only update the progress bar for the current ingredient
      _progressValue = weight;
    });
  }

  void _nextSKU() async {
    setState(() {
      isLoading = true;
    });
    if (currentIndex < widget.record['items'].length) {
      final currentItem = widget.record['items'][currentIndex];
      final weight = double.tryParse(weightController.text) ?? 0;

      double endWeight = startWeight + weight;

      try {
        final sessionId = await odooService.fetchSessionId();

        final updateWeighingResponse = await odooService.updateWeighingSKU(
          sessionId,
          widget.record['identifier'],
          currentItem['sku_identifier'],
          weight,
          startWeight,
          endWeight,
          currentIndex == widget.record['items'].length - 1,
        );

        print('updateWeighingResponse $updateWeighingResponse');
        // Extract the current total weight from the response
        setState(() {
          weighingProcess[currentItem['sku_identifier']] = {
            'name': currentItem['sku'],
            'value': weight,
          };

          if (currentIndex == widget.record['items'].length - 1) {
            _showCompletionDialog(); // Last SKU reached
          } else {
            currentIndex++;
            _skipWeighedSKUs();
            accumulatedWeight = endWeight;
            startWeight = accumulatedWeight;
            weightController.clear();
          }

          setState(() {
            currentTotalWeight = updateWeighingResponse['current_total_weight'];
          });
          setState(() {
            isLoading = false;
          });
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update SKU: $e')),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Weighing Complete!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          Home()), // Navigate to Weighing widget
                );
              },
              child: Text('Ok'),
            ),
          ],
        );
      },
    );
  }

  Color _getProgressBarColor(double weight, double expectation) {
    if (weight > expectation * 1.05) {
      return Colors.red;
    } else if (weight < expectation * 0.5) {
      return Colors.yellow;
    } else if (weight < expectation * 0.95) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.record['items'][currentIndex];
    final int totalItems = widget.record['items'].length;
    double expectation = currentItem['expectation'];
    double weight = double.tryParse(weightController.text) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('${currentItem['sku']} weighing',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[500],
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Center(
              child: Text('${currentIndex + 1}/$totalItems',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Checkbox to toggle 'Get data from scales'
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: getFromScales,
                        onChanged: (bool? value) {
                          setState(() {
                            getFromScales = value ?? false;
                          });
                        },
                      ),
                      const Text('Get data from scales'),
                    ],
                  ),
                  // Display SKU info and quantity
                  Text(
                    '${currentItem['qty']} x ${currentItem['sku']} (${currentItem['expectation']} g.)',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Visibility(
                    visible:
                        !getFromScales, // Show the widget only if getFromScales is true
                    child: Center(
                      child: SizedBox(
                        width: 180, // Set the desired width to be narrower
                        child: TextField(
                          controller: weightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Enter weight',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FAProgressBar(
                    currentValue: _progressValue,
                    maxValue: currentItem['expectation'] * 1.05,
                    displayText: ' g',
                    progressColor: _getProgressBarColor(weight, expectation),
                    backgroundColor: Colors.grey[300]!,
                    animatedDuration: const Duration(milliseconds: 400),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Current total weight from scales: $decodedWeight',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  Text(
                    'Current SKU weight: ${decodedWeight.isNotEmpty ? ((double.tryParse(decodedWeight.replaceAll('g', '').trim()) ?? 0.0) - (currentTotalWeight ?? 0.0)) : 'N/A'} g',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  Visibility(
                    visible:
                        !getFromScales, // Show the widget only if getFromScales is true
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          weightController.text =
                              decodedWeight.replaceAll('g', '');
                        });
                      },
                      child: const Text('Apply from scales'),
                    ),
                  )
                ],
              ),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (currentIndex > 0)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Previous:\n${widget.record['items'][currentIndex - 1]['sku']} "
                      "${weighingProcess[widget.record['items'][currentIndex - 1]['sku_identifier']]?['value'] ?? ''} g",
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.left,
                    ),
                  ),
                )
              else
                Expanded(child: SizedBox()),
              SizedBox(
                width: 150, // Button size
                child: ElevatedButton(
                  onPressed: (weight >= expectation * 0.95 &&
                          weight <= expectation * 1.05)
                      ? _nextSKU
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (weight >= expectation * 0.95 &&
                            weight <= expectation * 1.05)
                        ? Colors.blue[500]
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (currentIndex < totalItems - 1)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Next:\n${widget.record['items'][currentIndex + 1]['sku']}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                )
              else
                Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}

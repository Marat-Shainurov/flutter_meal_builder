import 'package:flutter/material.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';
import 'package:flutter_meal_builder/services/odoo_service.dart';
import 'package:flutter_meal_builder/screens/weighing/weighing_home.dart';
import 'package:flutter_serial_communication/flutter_serial_communication.dart';
import 'package:flutter_serial_communication/models/device_info.dart';
import 'dart:typed_data';

class WeighingProcess extends StatefulWidget {
  final dynamic record; // Weighing record passed from Weighing widget
  final bool detailedWeighingMode;

  const WeighingProcess(
      {Key? key, required this.record, required this.detailedWeighingMode})
      : super(key: key);

  @override
  _WeighingProcessState createState() => _WeighingProcessState();
}

class _WeighingProcessState extends State<WeighingProcess>
    with WidgetsBindingObserver {
  bool isLoading = false;
  int currentIndex = 0;
  TextEditingController weightController = TextEditingController();
  Map<String, Map<String, dynamic>> weighingProcess = {};
  double _progressValue = 0;
  final OdooService odooService = OdooService('https://evo.migom.cloud');

  final _flutterSerialCommunicationPlugin = FlutterSerialCommunication();
  bool isConnected = false;
  String decodedWeight = ''; // To hold the decoded weight data from scale
  String rawDataString = ''; // To hold raw data as a string
  List<int> buffer = []; // Buffer to accumulate incoming data
  String deviceName = 'No device found';
  bool getFromScales = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeWidget();
    print('detailedWeighingMode: ${widget.detailedWeighingMode}');
  }

  void _initializeWidget() {
    weightController.addListener(_updateProgressBar);
    // Skip already weighed SKUs on initialization
    _skipWeighedSKUs();
    // Initiate connection to USB-Serial Controller
    _connectToUSBSerialController();
    print('detailedWeighingMode: ${widget.detailedWeighingMode}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    weightController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App is closing or being minimized
      _disconnectFromUSBSerialController();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize when app comes back to the foreground
      _initializeWidget();
    }
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

  void _disconnectFromUSBSerialController() async {
    if (isConnected) {
      try {
        await _flutterSerialCommunicationPlugin.disconnect();
        setState(() {
          isConnected = false;
          deviceName = 'Disconnected';
        });
        print('Successfully disconnected');
      } catch (e) {
        print('Error during disconnection: $e');
      }
    } else {
      print('Successfully disconnected - no device connected');
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
          String weightWithoutUnit = decodedData.replaceAll('g', '').trim();

          setState(() {
            decodedWeight = decodedData;
            rawDataString = messageBytes
                .map((e) => e.toRadixString(16).padLeft(2, '0'))
                .join(' ');

            // Automatically apply the weight from the digital scale
            if (getFromScales) {
              double receivedWeight = double.tryParse(weightWithoutUnit) ?? 0.0;
              weightController.text = receivedWeight.toStringAsFixed(2);
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
      currentIndex++; // Skip to next SKU if 'fact' is not 0
    }
  }

  void _updateProgressBar() {
    double weight = double.tryParse(weightController.text) ?? 0;
    setState(() {
      _progressValue = weight;
    });
  }

  void _nextSKU() async {
    setState(() {
      isLoading = true;
    });
    final currentItem = widget.record['items'][currentIndex];
    final weight = weightController.text;

    try {
      final sessionId = await odooService.fetchSessionId();

      await odooService.updateWeighingSKUStock(
        sessionId,
        widget.record['identifier'],
        currentItem['sku_identifier'],
        double.parse(weight),
        currentIndex == widget.record['items'].length - 1,
      );

      setState(() {
        weighingProcess[currentItem['sku_identifier']] = {
          'name': currentItem['sku'],
          'value': weight,
        };

        // If this was the last SKU, show a popup and navigate to Weighing widget
        if (currentIndex == widget.record['items'].length - 1) {
          _disconnectFromUSBSerialController();
          _showCompletionDialog();
        } else {
          currentIndex++;
          _skipWeighedSKUs();
          weightController.clear();
        }
        setState(() {
          isLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update SKU: $e')),
      );
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
                      builder: (context) => Weighing(
                            detailedWeighingMode: widget.detailedWeighingMode,
                          )), // Navigate to Weighing widget
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

    return PopScope(
        onPopInvoked: (bool didPop) {
          _disconnectFromUSBSerialController(); // Disconnect before navigating back
          return;
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text('${currentItem['sku']} weighing',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
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
                      // Progress bar based on weight input
                      FAProgressBar(
                        currentValue: _progressValue,
                        maxValue: currentItem['expectation'] * 1.05,
                        displayText: ' g',
                        progressColor:
                            _getProgressBarColor(weight, expectation),
                        backgroundColor: Colors.grey[300]!,
                        animatedDuration: const Duration(milliseconds: 400),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Current total weight from scales: $decodedWeight',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      // Centered Weight input field with a small width
                      Visibility(
                        visible: widget.detailedWeighingMode,
                        child: Container(
                          color: Colors.yellow[100],
                          child: Column(
                            children: [
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Checkbox(
                                    value: getFromScales,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        getFromScales = value ?? true;
                                      });
                                      print('getFromScales: $getFromScales');
                                    },
                                  ),
                                  const Text('Get data from scales'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Visibility(
                                visible: !getFromScales,
                                child: Center(
                                  child: SizedBox(
                                    width: 180,
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
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 80, // Set an appropriate height for the bottom bar
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Previous SKU and weight (if available)
                  if (currentIndex > 0)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Previous:\n${widget.record['items'][currentIndex - 1]['sku']} "
                          "${weighingProcess[widget.record['items'][currentIndex - 1]['sku_identifier']]?['value'] ?? ''} g",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    )
                  else
                    Expanded(child: SizedBox()), // Empty space if no previous

                  // Next button in the center
                  SizedBox(
                    width: 150, // Button size
                    child: ElevatedButton(
                      onPressed: _nextSKU,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[500],
                        padding: const EdgeInsets.symmetric(
                            vertical: 16.0), // Button padding
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          color: Colors.white, // White text
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Next SKU info (if available)
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
                    Expanded(child: SizedBox()), // Empty space if no next
                ],
              ),
            ),
          ),
        ));
  }
}

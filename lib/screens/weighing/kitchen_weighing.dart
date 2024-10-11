import 'package:flutter/material.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';
import 'package:flutter_meal_builder/services/odoo_service.dart';
import 'package:flutter_meal_builder/screens/weighing/weighing_home.dart';

class KitchenWeighingProcess extends StatefulWidget {
  final dynamic record; // Weighing record passed from the Home widget

  const KitchenWeighingProcess({Key? key, required this.record})
      : super(key: key);

  @override
  _KitchenWeighingProcessState createState() => _KitchenWeighingProcessState();
}

class _KitchenWeighingProcessState extends State<KitchenWeighingProcess> {
  int currentIndex = 0;
  TextEditingController weightController = TextEditingController();
  Map<String, Map<String, dynamic>> weighingProcess = {};
  double _progressValue = 0;
  final OdooService odooService = OdooService('https://evo.migom.cloud');

  @override
  void initState() {
    super.initState();
    weightController.addListener(_updateProgressBar);
    // Skip already weighed SKUs on initialization
    _skipWeighedSKUs();
  }

// Method to skip SKUs that have already been weighed
  void _skipWeighedSKUs() {
    // Ensure currentIndex is within bounds
    while (currentIndex < widget.record['items'].length &&
        widget.record['items'][currentIndex]['fact'] != 0) {
      currentIndex++; // Skip to the next SKU if 'fact' is not 0
    }

    // If all items are already weighed, ensure currentIndex stays valid
    if (currentIndex >= widget.record['items'].length) {
      currentIndex =
          widget.record['items'].length - 1; // Set to last valid index
    }
  }

  void _updateProgressBar() {
    final currentItem = widget.record['items'][currentIndex];
    double weight = double.tryParse(weightController.text) ?? 0;
    double expectation = currentItem['expectation'];
    double maxBarValue = expectation * 1.05;
    setState(() {
      // _progressValue = (weight / maxBarValue) * 100;
      _progressValue = weight;
    });
  }

  void _nextSKU() async {
    if (currentIndex < widget.record['items'].length) {
      final currentItem = widget.record['items'][currentIndex];
      final weight = weightController.text;

      try {
        final sessionId = await odooService.fetchSessionId();

        await odooService.updateWeighingSKU(
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

          if (currentIndex == widget.record['items'].length - 1) {
            _showCompletionDialog(); // Last SKU reached
          } else {
            currentIndex++;
            _skipWeighedSKUs(); // Skip already weighed SKUs if any
            weightController.clear();
          }
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update SKU: $e')),
        );
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
                          Weighing()), // Navigate to Weighing widget
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
      body: Padding(
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
            // Centered Weight input field with a small width
            Center(
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
            const SizedBox(height: 20),
            // Progress bar based on weight input
            FAProgressBar(
              currentValue: _progressValue,
              maxValue: currentItem['expectation'] * 1.05,
              displayText: ' g',
              progressColor: _getProgressBarColor(weight, expectation),
              backgroundColor: Colors.grey[300]!,
              animatedDuration: const Duration(milliseconds: 400),
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
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                  onPressed: (weight >= expectation * 0.95 &&
                          weight <= expectation * 1.05)
                      ? _nextSKU
                      : null, // Disable button if weight is not in green zone
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (weight >= expectation * 0.95 &&
                            weight <= expectation * 1.05)
                        ? Colors.blue[500]
                        : Colors.grey, // Grey out if disabled
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
    );
  }
}

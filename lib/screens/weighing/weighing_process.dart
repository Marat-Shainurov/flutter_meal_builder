import 'package:flutter/material.dart';

class WeighingProcess extends StatefulWidget {
  final dynamic record; // Weighing record passed from Weighing widget

  const WeighingProcess({Key? key, required this.record}) : super(key: key);

  @override
  _WeighingProcessState createState() => _WeighingProcessState();
}

class _WeighingProcessState extends State<WeighingProcess> {
  int currentIndex = 0;
  TextEditingController weightController = TextEditingController();
  Map<String, Map<String, dynamic>> weighingProcess = {};

  @override
  void initState() {
    super.initState();
  }

  void _nextSKU() {
    final currentItem = widget.record['items'][currentIndex];
    final weight = weightController.text;

    setState(() {
      // Store the current SKU's weight
      weighingProcess[currentItem['sku_identifier']] = {
        'name': currentItem['sku'],
        'value': weight
      };
      // Move to the next SKU if available
      if (currentIndex < widget.record['items'].length - 1) {
        currentIndex++;
      }
      weightController.clear();
      print(weighingProcess);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.record['items'][currentIndex];
    final int totalItems = widget.record['items'].length;

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
              '${currentItem['qty']} x ${currentItem['sku']}',
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
          ],
        ),
      ),

      // 'Next' button with Previous and Next text beside it
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
                  onPressed: _nextSKU,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[500], // Blue background
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

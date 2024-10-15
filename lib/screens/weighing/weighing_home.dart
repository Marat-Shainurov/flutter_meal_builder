import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_meal_builder/services/odoo_service.dart';
import 'package:flutter_meal_builder/screens/weighing/weighing_process.dart';
import 'package:flutter_meal_builder/services/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Weighing extends StatefulWidget {
  const Weighing({super.key});

  @override
  _WeighingState createState() => _WeighingState();
}

class _WeighingState extends State<Weighing> {
  final Utils utils = Utils();
  final OdooService odooService = OdooService('https://evo.migom.cloud');

  List<dynamic> weighingRecords = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  String? restaurantId;

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
    _fetchSessionAndWeighingRecords();
  }

  Future<void> _loadRestaurantData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      restaurantId = prefs.getString('restaurantId');
    });
  }

  Future<void> _fetchSessionAndWeighingRecords() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });
    try {
      final sessionId = await odooService.fetchSessionId();
      final records = await odooService.fetchStockWeighingRecords(sessionId);
      setState(() {
        weighingRecords = records;
        isLoading = false;
      });
      print('Fetched weighing records: $weighingRecords');
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = e.toString();
      });
      print('Error fetching weighing records: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Weighing Records",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[500],
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            onPressed:
                _fetchSessionAndWeighingRecords, // Refresh the weighing records when pressed
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : weighingRecords.isEmpty
              ? const Center(child: Text('No weighing records found'))
              : ListView.builder(
                  itemCount: weighingRecords.length,
                  itemBuilder: (context, index) {
                    final record = weighingRecords[index];
                    DateTime parsedDate = DateTime.parse(record['datetime']);
                    String formattedDate =
                        DateFormat('dd.MM.yyyy HH:mm').format(parsedDate);

                    // Calculate time ago
                    Duration timeDifference =
                        DateTime.now().difference(parsedDate);
                    String timeAgo = utils.formatTimeAgo(timeDifference);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 10.0,
                        horizontal: 15.0,
                      ),
                      child: ListTile(
                        title: Text(record['name'],
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$formattedDate, $timeAgo'),
                        trailing: IconButton(
                          icon: const Icon(Icons.scale),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    WeighingProcess(record: record),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

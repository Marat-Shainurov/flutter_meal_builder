import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_meal_builder/services/odoo_service.dart';
import 'package:flutter_sunmi_printer_plus/flutter_sunmi_printer_plus.dart';
import 'package:flutter_sunmi_printer_plus/enums.dart';
import 'package:flutter_sunmi_printer_plus/sunmi_style.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final OdooService odooService = OdooService('https://evo.migom.cloud');
  // final OdooService odooService = OdooService('http://192.168.100.38:8069');

  List<dynamic> orders = [];
  bool isLoading = true;
  bool isConnected = false;
  String errorMessage = '';
  // Timer? _timer; // Timer instance

  @override
  void initState() {
    super.initState();
    _initializePrinter();
    _fetchSessionAndOrders();
    // _startAutoRefresh(); // Start the periodic refresh
  }

  Future<void> _initializePrinter() async {
    try {
      isConnected = await SunmiPrinter.initPrinter() ?? false;
      setState(() {});
    } catch (err) {
      errorMessage = err.toString();
      setState(() {});
    }
  }

  Future<void> _fetchSessionAndOrders() async {
    setState(() {
      isLoading =
          true; // Set loading state to true when fetching data for refreshing
    });
    try {
      final sessionId = await odooService.fetchSessionId();
      final fetchedOrders = await odooService.fetchOrders(sessionId);
      setState(() {
        orders = fetchedOrders;
        isLoading = false;
      });
      print('Fetched orders: $orders');
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching orders: $e');
    }
  }

  // void _startAutoRefresh() {
  //   _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
  //     _fetchSessionAndOrders(); // Fetch orders every 1 minute
  //   });
  // }

  // @override
  // void dispose() {
  //   _timer?.cancel();
  //   super.dispose();
  // }

  Future<void> _printOrderDetails(dynamic order) async {
    print(order);
    if (!isConnected) {
      print('Printer is not connected.');
      print('$errorMessage');
      return;
    }

    try {
      await SunmiPrinter.printText(
        content: '#001', // Placeholder for an order number
        style: SunmiStyle(
          fontSize: 100,
          bold: true,
          align: SunmiPrintAlign.CENTER,
        ),
      );

      await SunmiPrinter.lineWrap(1);

      // Print the table header
      await SunmiPrinter.printText(
        content: 'Title\t\tScoops\tTotal',
        style: SunmiStyle(
          fontSize: 50,
          bold: true,
          align: SunmiPrintAlign.LEFT,
        ),
      );

      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText(
        content: '--------------------------------',
        style: SunmiStyle(
          fontSize: 20,
          align: SunmiPrintAlign.LEFT,
        ),
      );

      for (var option in order['option_ids']) {
        await SunmiPrinter.printText(
          content:
              '${option['short_name']}\t\t${option['weights_qty']}\t${option['serving_weight']} g',
          style: SunmiStyle(
            fontSize: 40,
            align: SunmiPrintAlign.LEFT,
          ),
        );
        await SunmiPrinter.lineWrap(1);

        await SunmiPrinter.printText(
          content: '--------------------------------',
          style: SunmiStyle(
            fontSize: 20,
            align: SunmiPrintAlign.LEFT,
          ),
        );
      }

      await SunmiPrinter.feedPaper();
    } catch (err) {
      print('Error printing order: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Kitchen Assistant",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[500],
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            color: Colors.white,
            onPressed:
                _fetchSessionAndOrders, // Refresh the orders when pressed
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
              ? const Center(child: Text('No orders found'))
              : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    DateTime parsedDate = DateTime.parse(order['date']);
                    String formattedDate =
                        DateFormat('dd.MM.yyyy').format(parsedDate);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 10.0,
                        horizontal: 15.0,
                      ),
                      child: ListTile(
                        title: Text(order['name'],
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(formattedDate),
                        trailing: IconButton(
                          icon: Icon(Icons.print),
                          onPressed: () {
                            _printOrderDetails(order);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

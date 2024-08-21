import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_meal_builder/services/odoo_service.dart';
import 'package:flutter_meal_builder/services/utils.dart';
import 'package:flutter_sunmi_printer_plus/flutter_sunmi_printer_plus.dart';
import 'package:flutter_sunmi_printer_plus/enums.dart';
import 'package:flutter_sunmi_printer_plus/sunmi_style.dart';
import 'package:flutter_sunmi_printer_plus/column_maker.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final Utils utils = Utils();
  final OdooService odooService = OdooService('https://evo.migom.cloud');
  // final OdooService odooService = OdooService('http://192.168.100.38:8069');

  List<dynamic> orders = [];
  bool isLoading = true;
  bool isConnected = false;
  String errorMessage = '';
  String? restaurantId;
  String? restaurantName;
  // Timer? _timer; // Timer instance

  @override
  void initState() {
    super.initState();
    _initializePrinter();
    _fetchSessionAndOrders();
    // _startAutoRefresh(); // Start the periodic refresh
    print('Current restaurantName: ${restaurantName}');
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
      final fetchedOrders =
          await odooService.fetchOrders(sessionId, restaurantId!);
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
    String orderNumber = order["order_number"];

    print('Title\t\tScoops\tTotal');
    if (!isConnected) {
      print('Printer is not connected.');
      print('$errorMessage');

      for (var option in order['option_ids']) {
        String ingredientLiine =
            '${option['short_name']}\t\t${option['weights_qty'].toInt()}\t${option['serving_weight'].toInt()} g';
        print(ingredientLiine);
      }
      return;
    }

    // Print the order number
    try {
      await SunmiPrinter.printText(
        content: orderNumber,
        style: SunmiStyle(
          fontSize: 40,
          bold: true,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.lineWrap(1);

      // Print the table with the order details
      await SunmiPrinter.printTable(cols: [
        ColumnMaker(text: 'Title', align: SunmiPrintAlign.LEFT, width: 6),
        ColumnMaker(text: 'Scoops', align: SunmiPrintAlign.CENTER, width: 3),
        ColumnMaker(text: 'Total', align: SunmiPrintAlign.RIGHT, width: 3),
      ]);
      await SunmiPrinter.lineWrap(1);

      for (var option in order['option_ids']) {
        await SunmiPrinter.printTable(cols: [
          ColumnMaker(
              text: option['short_name'],
              align: SunmiPrintAlign.LEFT,
              width: 8),
          ColumnMaker(
              text: '${option['weights_qty'].toInt()}',
              align: SunmiPrintAlign.CENTER,
              width: 4),
          ColumnMaker(
              text: '${option['serving_weight'].toInt()} g',
              align: SunmiPrintAlign.RIGHT,
              width: 4),
        ]);
        await SunmiPrinter.lineWrap(1);
      }

      await SunmiPrinter.feedPaper();
      await SunmiPrinter.cutPaper();
    } catch (err) {
      print('Error printing order: $err');
    }
  }

  Future<void> _showSetRestaurantDialog() async {
    TextEditingController restaurantController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please, input your restaurant identifier'),
              TextField(
                controller: restaurantController,
                decoration: const InputDecoration(hintText: "Restaurant ID"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  restaurantId = restaurantController.text;
                });
                final sessionId = await odooService.fetchSessionId();
                _fetchRestaurant(sessionId, restaurantId!);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchRestaurant(String sessionId, String restaurantId) async {
    utils.showLoaderDialog(context);
    try {
      final restaurantData =
          await odooService.fetchRestaurant(sessionId, restaurantId);
      Navigator.pop(context);
      setState(() {
        restaurantName = restaurantData['name'];
        _showsuccessAlert();
        _fetchSessionAndOrders();
      });
    } catch (e) {
      _showErrorAlert("ID is incorrect");
    }
  }

  Future<void> _showErrorAlert(String message) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showsuccessAlert() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: const Text('The restaurant has been successfully set'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue[500],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    restaurantName != null
                        ? 'Restaurant: $restaurantName'
                        : 'Restaurant is not set',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text('Set Restaurant'),
              onTap: _showSetRestaurantDialog,
            ),
          ],
        ),
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
                        title: Text(order['order_number'],
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$formattedDate, $timeAgo'),
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

import 'package:flutter/material.dart';
import 'package:flutter_meal_builder/services/odoo_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final OdooService odooService = OdooService('http://192.168.100.38:8069');
  List<dynamic> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSessionAndOrders();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Meal Builder",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[500],
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
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
                    return ListTile(
                      title: Text(order['name']),
                      subtitle: Text('Identifier: ${order['identifier']}'),
                      onTap: () {
                        // Handle order tap
                      },
                    );
                  },
                ),
    );
  }
}

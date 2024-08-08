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
  dynamic sessionId = '';

  @override
  void initState() {
    super.initState();
    _fetchSessionAndOrders();
  }

  Future<void> _fetchSessionAndOrders() async {
    try {
      final fetchedOrders = await odooService.fetchSessionId();
      setState(() {
        sessionId = fetchedOrders;
      });
      print('Session id: $sessionId');
    } catch (e) {
      // Handle error
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
      ),
      body: Container(child: Text('Odoo Session id: $sessionId')),
    );
  }
}

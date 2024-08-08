import 'package:flutter/material.dart';

class OrderDetails extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetails({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(order['name'],
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[500],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Identifier: ${order['identifier']}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: order['option_ids'].length,
                itemBuilder: (context, index) {
                  final option = order['option_ids'][index];
                  return Card(
                    child: ListTile(
                      title: Text('${option['name']} (${option['base']})'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Weight: ${option['weight_id']}'),
                          Text('Quantity: ${option['weights_qty']}'),
                          Text('Serving Weight: ${option['serving_weight']}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

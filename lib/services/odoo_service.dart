import 'dart:convert';
import 'package:http/http.dart' as http;

class OdooService {
  final String baseUrl;
  OdooService(this.baseUrl);

  Future<dynamic> fetchSessionId() async {
    const odooUser = 'admin@admin.com';
    const odooPassword = '2qr-MbX-2Eu-Xg9';
    const odooDb = 'db_odoo_head';

    const data = {
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "db": odooDb,
        "login": odooUser,
        "password": odooPassword,
      },
    };

    final sessionResponse = await http.post(
      Uri.parse('$baseUrl/web/session/authenticate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    if (sessionResponse.statusCode == 200) {
      final sessionData = json.decode(sessionResponse.body);
      if (sessionData['result'] != null) {
        final cookieHeader = sessionResponse.headers['set-cookie']!;
        final sessionId = _getSessionIdFromCookie(cookieHeader);
        print('Cookie header: $cookieHeader');
        return sessionId;
      } else {
        throw Exception('Failed to authenticate session');
      }
    } else {
      throw Exception('Failed to load session');
    }
  }

  String? _getSessionIdFromCookie(String cookieHeader) {
    // Parse the session ID from the cookie header
    final cookies = cookieHeader.split(';');
    for (var cookie in cookies) {
      final cookieParts = cookie.split('=');
      if (cookieParts.length == 2 && cookieParts[0].trim() == 'session_id') {
        return cookieParts[1].trim();
      }
    }
    return null;
  }

  Future<List<dynamic>> fetchOrders(
      String sessionId, String restaurantId) async {
    Map<String, dynamic> data = {"restaurant_id": restaurantId};

    final headers = {"Cookie": "session_id=$sessionId"};
    final ordersResponse = await http.post(
      Uri.parse('$baseUrl/api/kitchen_orders'),
      headers: headers,
      body: json.encode(data),
    );

    if (ordersResponse.statusCode == 200) {
      final ordersData = json.decode(ordersResponse.body);
      if (ordersData is List) {
        return ordersData;
      } else {
        print('Failed to load orders');
        return [];
      }
    } else {
      throw Exception('Failed to fetch orders');
    }
  }

  Future<dynamic> fetchRestaurant(
      String sessionId, dynamic restaurantId) async {
    final headers = {
      "Cookie": "session_id=$sessionId",
      'Content-Type': 'application/json',
    };

    Map<String, dynamic> data = {"restaurant_id": restaurantId};

    final response = await http.post(
      Uri.parse('$baseUrl/api/restaurant'),
      headers: headers,
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      final restaurantData = json.decode(response.body);
      if (restaurantData['name'] != null) {
        return restaurantData;
      } else {
        print("Fetching error: ${response.body}");
        throw Exception('Fetching error: ${response.body}');
      }
    } else {
      throw Exception(
          'Failed to fetch restaurant, Status Code: ${response.statusCode}');
    }
  }

  Future<dynamic> fetchWeighingRecords(String sessionId) async {
    final headers = {"Cookie": "session_id=$sessionId"};
    final weighingResponse = await http.post(
      Uri.parse('$baseUrl/api/weighing_records'),
      headers: headers,
    );

    if (weighingResponse.statusCode == 200) {
      final weighingData = json.decode(weighingResponse.body);
      if (weighingData is List) {
        return weighingData;
      } else {
        print('Failed to load weighing records');
        return [];
      }
    } else {
      throw Exception('Failed to fetch weighing records');
    }
  }

  Future<dynamic> fetchStockWeighingRecords(String sessionId) async {
    final headers = {"Cookie": "session_id=$sessionId"};
    final weighingResponse = await http.post(
      Uri.parse('$baseUrl/api/stock_weighing_records'),
      headers: headers,
    );

    if (weighingResponse.statusCode == 200) {
      final weighingData = json.decode(weighingResponse.body);
      if (weighingData is List) {
        return weighingData;
      } else {
        print('Failed to load stock weighing records');
        return [];
      }
    } else {
      throw Exception('Failed to fetch stock weighing records');
    }
  }

  Future<Map<String, dynamic>> updateWeighingSKU(
      String sessionId,
      String weighingIdentifier,
      String skuIdentifier,
      dynamic weightValue,
      dynamic startWeight,
      dynamic endWeight,
      dynamic isLast) async {
    final headers = {
      "Cookie": "session_id=$sessionId",
      'Content-Type': 'application/json',
    };

    final data = {
      "weighing_identifier": weighingIdentifier,
      "sku_identifier": skuIdentifier,
      "weight_value": weightValue,
      "start_weight": startWeight,
      "end_weight": endWeight,
      "is_last": isLast
    };

    final updateResponse = await http.post(
      Uri.parse('$baseUrl/api/update_weighing_sku'),
      headers: headers,
      body: json.encode(data),
    );

    if (updateResponse.statusCode == 200) {
      final updateData = json.decode(updateResponse.body);

      // Accept any value types and convert them to strings
      if (updateData is Map<String, dynamic>) {
        return updateData.map((key, value) => MapEntry(key, value.toString()));
      } else {
        throw Exception("Unexpected response format: ${updateResponse.body}");
      }
    } else {
      throw Exception(
          'Failed to update weighing SKU, Status Code: ${updateResponse.statusCode}');
    }
  }

  Future<Map<String, dynamic>> updateWeighingSKUStock(
      String sessionId,
      String weighingIdentifier,
      String skuIdentifier,
      dynamic weightValue,
      dynamic isLast) async {
    final headers = {
      "Cookie": "session_id=$sessionId",
      'Content-Type': 'application/json',
    };

    final data = {
      "weighing_identifier": weighingIdentifier,
      "sku_identifier": skuIdentifier,
      "weight_value": weightValue,
      "is_last": isLast
    };

    final updateResponse = await http.post(
      Uri.parse('$baseUrl/api/update_stock_weighing_sku'),
      headers: headers,
      body: json.encode(data),
    );

    if (updateResponse.statusCode == 200) {
      final updateData = json.decode(updateResponse.body);

      // Accept any value types and convert them to strings
      if (updateData is Map<String, dynamic>) {
        return updateData.map((key, value) => MapEntry(key, value.toString()));
      } else {
        throw Exception("Unexpected response format: ${updateResponse.body}");
      }
    } else {
      throw Exception(
          'Failed to update weighing SKU, Status Code: ${updateResponse.statusCode}');
    }
  }

  Future<dynamic> fetchKitchenWeighing(
      String sessionId, dynamic kitchenOrderId) async {
    final headers = {
      "Cookie": "session_id=$sessionId",
      'Content-Type': 'application/json',
    };

    Map<String, dynamic> data = {"kitchen_order_identifier": kitchenOrderId};

    final response = await http.post(
      Uri.parse('$baseUrl/api/get_kitchen_weighing'),
      headers: headers,
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      final weighingData = json.decode(response.body);
      if (weighingData['identifier'] != null) {
        return weighingData;
      } else {
        print("Wieghing fetching error: ${response.body}");
        throw Exception('Wieghing fetching error: ${response.body}');
      }
    } else {
      throw Exception(
          'Failed to fetch kitchen weighing, Status Code: ${response.statusCode}');
    }
  }
}

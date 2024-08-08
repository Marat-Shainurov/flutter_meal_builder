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
}

import 'dart:convert';
import 'dart:io'; // �Ω� HttpClient
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart'; // �פJ IOClient
import 'api_models.dart'; // �פJ�A����Ƽҫ�

class ApiService {
  // ������A������ URL�]���ݭn�A�b�{���X�����r��^
  static const String _chatUrl =
      "https://icps-system-product-name.tailb6dda9.ts.net:10000/api/chat";

  late final IOClient _client;

  ApiService() {
    final httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    _client = IOClient(httpClient);
  }

  void dispose() {
    _client.close();
  }

  Future<ChatResponse> sendMessage(ChatRequest request) async {
    final url = Uri.parse(_chatUrl);
    final headers = {"Content-Type": "application/json"};
    final body = jsonEncode(request.toJson());

    try {
      final resp = await _client.post(url, headers: headers, body: body);
      if (resp.statusCode == 200) {
        final responseBody = utf8.decode(resp.bodyBytes);
        return ChatResponse.fromJson(jsonDecode(responseBody));
      } else {
        throw Exception('API Error: Status Code ${resp.statusCode}');
      }
    } on SocketException {
      throw Exception('Network Error: Please check your connection.');
    } catch (e) {
      throw Exception('Failed to connect to the API: $e');
    }
  }
}

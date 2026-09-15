import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? AppConfig.backendBaseUrl).replaceAll(
        RegExp(r'/+$'),
        '',
      );

  final http.Client _client;
  final String _baseUrl;

  Uri uri(String path, [Map<String, Object?> query = const {}]) {
    final params = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.toString().isNotEmpty) {
        params[entry.key] = value.toString();
      }
    }
    return Uri.parse('$_baseUrl$path').replace(queryParameters: params);
  }

  Future<dynamic> getJson(
    String path, [
    Map<String, Object?> query = const {},
  ]) async {
    final response = await _client.get(uri(path, query));
    return _decode(response);
  }

  Future<dynamic> postJson(String path, Map<String, Object?> body) async {
    final response = await _client.post(
      uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
    if (response.body.isEmpty) {
      return null;
    }
    return jsonDecode(response.body);
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'API request failed with HTTP $statusCode: $body';
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static String get baseUrl => 'https://portal.hitechpragati.in/api';
  
  static void Function()? onUnauthorized;
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, String>> getHeaders() async {
    String? cookie = await _storage.read(key: 'session_cookie');
    print('DEBUG: Sending Cookie: $cookie');
    return {
      'Content-Type': 'application/json',
      if (cookie != null) 'Cookie': cookie,
    };
  }

  Never _handleError(dynamic e) {
    if (e is ApiException) throw e;
    final errStr = e.toString();
    if (e is SocketException || errStr.contains('SocketException') || errStr.contains('HandshakeException')) {
      throw ApiException('Connection error. Please check your internet connection.');
    }
    if (e is TimeoutException || errStr.contains('TimeoutException')) {
      throw ApiException('Connection timed out. Please check your internet connection and try again.');
    }
    if (e is FormatException || errStr.contains('FormatException')) {
      throw ApiException('Server returned an invalid response. Please try again.');
    }
    throw ApiException('Unable to connect to the server. Please try again.');
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: await getHeaders(),
      ).timeout(const Duration(seconds: 15));
      _updateCookie(response);
      return _processResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: await getHeaders(),
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      _updateCookie(response);
      return _processResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$endpoint'),
        headers: await getHeaders(),
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      _updateCookie(response);
      return _processResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> delete(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$endpoint'),
        headers: await getHeaders(),
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      _updateCookie(response);
      return _processResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  void _updateCookie(http.Response response) async {
    String? rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      print('DEBUG: Received Set-Cookie: $rawCookie');
      int index = rawCookie.indexOf(';');
      String cookie = (index == -1) ? rawCookie : rawCookie.substring(0, index);
      await _storage.write(key: 'session_cookie', value: cookie);
      print('DEBUG: Saved Cookie: $cookie');
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {
      throw ApiException('Server returned an invalid response. Please try again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      if (response.statusCode == 401 ||
          (response.statusCode == 403 &&
              body is Map &&
              body['message'] != null &&
              body['message'].toString().contains('Outside allowed login hours'))) {
        onUnauthorized?.call();
      }
      throw ApiException((body is Map && body['message'] != null) ? body['message'] : 'API error');
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'session_service.dart';

class ApiException implements Exception {
  const ApiException({required this.message, this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static const Duration requestTimeout = Duration(seconds: 12);
  static http.Client _client = http.Client();

  static Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}$path',
    ).replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll(_headers)
      ..body = body == null ? '' : jsonEncode(body);

    try {
      final streamedResponse = await _client
          .send(request)
          .timeout(requestTimeout);
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(requestTimeout);
      final decoded = _decodeBody(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _statusException(response.statusCode, decoded);
      }

      return {
        'success': decoded['success'] ?? true,
        'status_code': response.statusCode,
        ...decoded,
      };
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        message: 'The request took too long. Please try again.',
        code: 'request_timeout',
      );
    } on FormatException {
      throw const ApiException(
        message: 'Something went wrong. Please try again.',
        code: 'invalid_response',
      );
    } catch (error) {
      final normalized = error.toString().toLowerCase();
      final noInternet = [
        'socketexception',
        'failed host lookup',
        'network is unreachable',
        'network error',
        'xmlhttprequest error',
        'failed to fetch',
      ].any(normalized.contains);

      throw ApiException(
        message: noInternet
            ? 'No internet connection. Please check your network and try again.'
            : 'Could not reach GuardianNode server. Please try again.',
        code: noInternet ? 'no_internet' : 'server_unreachable',
      );
    }
  }

  static Future<Map<String, dynamic>> safeRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    try {
      return await request(method, path, body: body, query: query);
    } on ApiException catch (error) {
      return {
        'success': false,
        'status_code': error.statusCode,
        'code': error.code,
        'message': error.message,
      };
    }
  }

  static String friendlyMessage(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is ApiException) {
      return error.message;
    }

    return fallback;
  }

  static Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw const FormatException('Response is not a JSON object.');
  }

  static ApiException _statusException(
    int statusCode,
    Map<String, dynamic> body,
  ) {
    final code = body['code']?.toString();
    final backendMessage = _safeBackendMessage(body['message']?.toString());

    if (statusCode == 401 ||
        (statusCode == 403 && code != 'ACCOUNT_NOT_ALLOWED')) {
      SessionService.clearSession();
      return ApiException(
        message: 'Session expired. Please login again.',
        code: code ?? 'session_expired',
        statusCode: statusCode,
      );
    }

    if (statusCode == 400 || statusCode == 409 || statusCode == 422) {
      return ApiException(
        message:
            backendMessage ??
            'Something went wrong. Please try again.',
        code: code ?? 'validation_error',
        statusCode: statusCode,
      );
    }

    if (statusCode == 403) {
      return ApiException(
        message:
            backendMessage ??
            'Something went wrong. Please try again.',
        code: code ?? 'forbidden',
        statusCode: statusCode,
      );
    }

    if (statusCode == 404) {
      return ApiException(
        message:
            backendMessage ?? 'Something went wrong. Please try again.',
        code: code ?? 'not_found',
        statusCode: statusCode,
      );
    }

    if (statusCode >= 500) {
      return ApiException(
        message: 'Could not reach GuardianNode server. Please try again.',
        code: code ?? 'server_error',
        statusCode: statusCode,
      );
    }

    return ApiException(
      message: backendMessage ?? 'Something went wrong. Please try again.',
      code: code ?? 'request_failed',
      statusCode: statusCode,
    );
  }

  static String? _safeBackendMessage(String? message) {
    final value = message?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final normalized = value.toLowerCase();
    final isTechnical = [
      'http://',
      'https://',
      'socketexception',
      'dioexception',
      'xmlhttprequest',
      'stack trace',
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
    ].any(normalized.contains);

    return isTechnical ? null : value;
  }

  static Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = SessionService.accessToken;

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  static void setClientForTesting(http.Client client) {
    _client.close();
    _client = client;
  }

  static void resetClientForTesting() {
    _client.close();
    _client = http.Client();
  }
}

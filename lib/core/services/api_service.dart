import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'session_service.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiAuthBaseUrl;

  static Future<Map<String, dynamic>> requestOtp(String phoneNumber) async {
    return startLoginVerification(phoneNumber);
  }

  static Future<Map<String, dynamic>> startLoginVerification(
    String phoneNumber,
  ) async {
    return _post(
      '/login/start-verification',
      body: {'phone_number': phoneNumber},
    );
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
    String? otpSessionId,
  }) async {
    return _post(
      '/verify-otp',
      body: {
        'phone_number': phoneNumber,
        'otp_code': otpCode,
        if (otpSessionId != null && otpSessionId.isNotEmpty)
          'otp_session_id': otpSessionId,
      },
    );
  }

  static Future<Map<String, dynamic>> register({
    required Map<String, dynamic> registrationData,
  }) async {
    return startRegistrationVerification(registrationData: registrationData);
  }

  static Future<Map<String, dynamic>> startRegistrationVerification({
    required Map<String, dynamic> registrationData,
  }) async {
    return _post('/register/start-verification', body: registrationData);
  }

  static Future<Map<String, dynamic>> getVerificationStatus(
    String verificationId,
  ) async {
    return _get('/api/verification/status/$verificationId');
  }

  static Future<Map<String, dynamic>> resendOtp({
    required String phoneNumber,
    String? otpSessionId,
  }) async {
    return _post(
      '/resend-otp',
      body: {
        'phone_number': phoneNumber,
        if (otpSessionId != null && otpSessionId.isNotEmpty)
          'otp_session_id': otpSessionId,
      },
    );
  }

  static Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    try {
      final response = await http.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode(body),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': _buildRequestErrorMessage(e, uri)};
    }
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');

    try {
      final response = await http.get(uri, headers: _buildHeaders());

      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': _buildRequestErrorMessage(e, uri)};
    }
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    final decodedBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    return {
      'success': response.statusCode >= 200 && response.statusCode < 300
          ? (decodedBody['success'] ?? true)
          : (decodedBody['success'] ?? false),
      'status_code': response.statusCode,
      ...decodedBody,
    };
  }

  static Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    final token = SessionService.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  static String _buildRequestErrorMessage(Object error, Uri uri) {
    final rawMessage = error.toString();
    final normalizedMessage = rawMessage.toLowerCase();
    final looksLikeConnectivityIssue = [
      'socketexception',
      'failed host lookup',
      'connection refused',
      'connection reset',
      'network is unreachable',
      'xmlhttprequest error',
      'clientexception',
      'failed to fetch',
    ].any(normalizedMessage.contains);

    if (looksLikeConnectivityIssue) {
      return 'Could not reach the backend at $uri. ${AppConfig.apiAuthBaseUrlHint}';
    }

    return rawMessage;
  }
}

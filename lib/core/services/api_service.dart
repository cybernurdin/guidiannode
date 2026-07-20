import 'api_client.dart';

class ApiService {
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

  static Future<Map<String, dynamic>> confirmWhatsappClick({
    required String verificationId,
    required String phoneNumber,
  }) async {
    return ApiClient.safeRequest(
      'POST',
      '/api/verification/confirm-whatsapp-click',
      body: {'verificationId': verificationId, 'phone_number': phoneNumber},
    );
  }

  /// Demo/competition-only shortcut: signs in with just a registered phone
  /// number, no password or OTP required.
  static Future<Map<String, dynamic>> loginPhoneOnly(String phoneNumber) async {
    return _post('/login/phone-only', body: {'phone_number': phoneNumber});
  }

  static Future<Map<String, dynamic>> registerWithPassword({
    required String fullName,
    required String phoneNumber,
    required String password,
    String? email,
    String? quarter,
  }) async {
    return _post(
      '/register/password',
      body: {
        'full_name': fullName,
        'phone_number': phoneNumber,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
        if (quarter != null && quarter.isNotEmpty) 'quarter': quarter,
      },
    );
  }

  static Future<Map<String, dynamic>> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    return _post(
      '/login/password',
      body: {'identifier': identifier, 'password': password},
    );
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
    return ApiClient.safeRequest('POST', '/api/auth$path', body: body);
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    return ApiClient.safeRequest('GET', path);
  }
}

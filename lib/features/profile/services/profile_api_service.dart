import '../../../core/services/api_client.dart';
import '../models/profile_models.dart';

class ProfileApiService {
  static Future<UserProfile> fetchCurrentProfile() async {
    final response = await _request('GET', '/api/profile/me');
    final data = Map<String, dynamic>.from(
      response['data'] as Map? ?? const {},
    );

    return UserProfile.fromJson(
      Map<String, dynamic>.from(data['profile'] as Map? ?? const {}),
    );
  }

  static Future<UserProfile> updateCurrentProfile({
    required String fullName,
    required String neighborhood,
    required EmergencyContactProfile emergencyContact,
  }) async {
    final response = await _request(
      'PUT',
      '/api/profile/me',
      body: {
        'full_name': fullName,
        'quarter': neighborhood,
        'emergency_contact': emergencyContact.toUpdatePayload(),
      },
    );
    final data = Map<String, dynamic>.from(
      response['data'] as Map? ?? const {},
    );

    return UserProfile.fromJson(
      Map<String, dynamic>.from(data['profile'] as Map? ?? const {}),
    );
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return ApiClient.request(method, path, body: body);
  }
}

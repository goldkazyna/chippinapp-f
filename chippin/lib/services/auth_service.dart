import 'package:dio/dio.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  /// Dev login: POST /api/auth/dev-login
  Future<Map<String, dynamic>> devLogin(String email) async {
    final response = await _apiClient.dio.post(
      '/auth/dev-login',
      data: {'email': email},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// OAuth login: POST /api/auth/{provider}
  Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String token,
    String? telegramId,
    String? name,
  }) async {
    final body = <String, dynamic>{'token': token};
    if (provider == 'telegram') {
      body['telegram_id'] = telegramId;
      body['name'] = name;
    }
    final response = await _apiClient.dio.post('/auth/$provider', data: body);
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Get current user: GET /api/user
  Future<User> getProfile() async {
    final response = await _apiClient.dio.get('/user');
    return User.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Update profile: PUT /api/user
  Future<User> updateProfile({String? name, String? avatar}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (avatar != null) body['avatar'] = avatar;
    final response = await _apiClient.dio.put('/user', data: body);
    return User.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Update settings: PUT /api/user/settings
  Future<User> updateSettings({String? currency, String? language}) async {
    final body = <String, dynamic>{};
    if (currency != null) body['default_currency'] = currency;
    if (language != null) body['language'] = language;
    final response = await _apiClient.dio.put('/user/settings', data: body);
    return User.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Logout: POST /api/auth/logout
  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/auth/logout');
    } on DioException {
      // Ignore — clear token regardless
    } finally {
      await _apiClient.clearToken();
    }
  }
}

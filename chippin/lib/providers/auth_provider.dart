import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

final needsOnboardingProvider = StateProvider<bool>((ref) => false);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(
    ref.watch(authServiceProvider),
    ref.watch(apiClientProvider),
  );
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;
  final ApiClient _apiClient;

  AuthNotifier(this._authService, this._apiClient)
      : super(const AsyncValue.data(null));

  /// Check if we have a saved token → load profile
  Future<void> checkAuth() async {
    final token = await _apiClient.getToken();
    if (token == null) {
      state = const AsyncValue.data(null);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final user = await _authService.getProfile();
      state = AsyncValue.data(user);
    } catch (e, st) {
      await _apiClient.clearToken();
      state = AsyncValue.error(e, st);
    }
  }

  /// Dev login: POST /api/auth/dev-login
  Future<void> devLogin(String email) async {
    state = const AsyncValue.loading();
    try {
      final data = await _authService.devLogin(email);
      await _apiClient.setToken(data['token'] as String);
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// OAuth login via provider (google / apple / telegram)
  /// Sets needsOnboarding BEFORE auth state to avoid race condition with router.
  Future<void> socialLogin({
    required String provider,
    required String token,
    required StateController<bool> onboardingController,
    String? telegramId,
    String? name,
  }) async {
    state = const AsyncValue.loading();
    try {
      final data = await _authService.socialLogin(
        provider: provider,
        token: token,
        telegramId: telegramId,
        name: name,
      );
      await _apiClient.setToken(data['token'] as String);
      final user = User.fromJson(data['user'] as Map<String, dynamic>);

      // Check onboarding BEFORE setting auth state (to avoid redirect race)
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_done_${user.id}') ?? false;
      if (!onboardingDone) {
        onboardingController.state = true;
      }

      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Mark onboarding as completed for current user
  Future<void> completeOnboarding() async {
    final user = state.valueOrNull;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done_${user.id}', true);
    }
  }

  /// Update user data in state (after profile/settings change)
  void setUser(User user) {
    state = AsyncValue.data(user);
  }

  /// Logout
  Future<void> logout() async {
    await _authService.logout();
    state = const AsyncValue.data(null);
  }

  /// Mock login for testing without backend
  void mockLogin() {
    state = const AsyncValue.data(
      User(
        id: 1,
        name: 'Denis',
        email: 'denis@gmail.com',
        defaultCurrency: 'KZT',
        language: 'en',
      ),
    );
  }

  bool get isAuthenticated => state.valueOrNull != null;
}

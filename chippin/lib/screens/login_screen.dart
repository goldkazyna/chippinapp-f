import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../config/l10n.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'telegram_auth_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final googleSignIn = GoogleSignIn(
        clientId: '884588420497-gukcgkgbrchk551016bph2fkjpf39sum.apps.googleusercontent.com',
        serverClientId: '884588420497-ioltpm8r1am5tvu182h7slof98921e9q.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        setState(() => _loading = false);
        return; // User cancelled
      }
      final auth = await account.authentication;
      final accessToken = auth.accessToken;
      if (accessToken == null) throw Exception('No access token');

      await ref.read(authStateProvider.notifier).socialLogin(
            provider: 'google',
            token: accessToken,
            onboardingController: ref.read(needsOnboardingProvider.notifier),
          );
    } catch (e) {
      setState(() => _error = 'Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (!Platform.isIOS) {
      setState(() => _error = 'Apple Sign In is only available on iOS.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null) throw Exception('No identity token');

      // Apple only sends name on first sign-in, build it if available
      String? name;
      if (credential.givenName != null || credential.familyName != null) {
        name = [credential.givenName, credential.familyName]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');
        if (name.isEmpty) name = null;
      }

      await ref.read(authStateProvider.notifier).socialLogin(
            provider: 'apple',
            token: identityToken,
            name: name,
            onboardingController: ref.read(needsOnboardingProvider.notifier),
          );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        setState(() => _error = 'Apple Sign In failed. Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'Apple Sign In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithTelegram() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const TelegramAuthScreen()),
      );
      if (result == null) {
        setState(() => _loading = false);
        return; // User cancelled
      }

      await ref.read(authStateProvider.notifier).socialLogin(
            provider: 'telegram',
            token: result, // JSON-encoded Telegram auth data
            onboardingController: ref.read(needsOnboardingProvider.notifier),
          );
    } catch (e) {
      setState(() => _error = 'Telegram login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Dev login via POST /api/auth/dev-login
  Future<void> _devLogin() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref
          .read(authStateProvider.notifier)
          .devLogin('test@test.com');
    } catch (e) {
      setState(() => _error = 'Dev login failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final s = ref.watch(l10nProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.accent,
                  size: 32,
                ),
              ),

              const SizedBox(height: 24),

              // App name
              Text(
                s.appName,
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                s.loginSubtitle,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),

              const Spacer(flex: 3),

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 18, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Loading
              if (_loading) ...[
                const CircularProgressIndicator(color: AppTheme.accent),
                const SizedBox(height: 24),
              ],

              // Google button
              _OAuthButton(
                label: s.continueWithGoogle,
                icon: _GoogleIcon(),
                onTap: _loading ? null : _signInWithGoogle,
              ),

              if (Platform.isIOS) ...[
                const SizedBox(height: 12),

                // Apple button (iOS only)
                _OAuthButton(
                  label: s.continueWithApple,
                  icon: const Icon(Icons.apple, color: Colors.white, size: 22),
                  onTap: _loading ? null : _signInWithApple,
                ),
              ],

              const SizedBox(height: 12),

              // Telegram button
              _OAuthButton(
                label: s.continueWithTelegram,
                icon: const _TelegramIcon(),
                onTap: _loading ? null : _signInWithTelegram,
              ),

              const SizedBox(height: 16),

              // Dev login button
              TextButton(
                onPressed: _loading ? null : _devLogin,
                child: Text(
                  s.devLogin,
                  style: GoogleFonts.manrope(
                      fontSize: 13, color: AppTheme.textMuted),
                ),
              ),

              const SizedBox(height: 16),

              // Terms footer
              Text.rich(
                TextSpan(
                  text: s.termsIntro,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: s.termsOfService,
                      style: GoogleFonts.manrope(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const TextSpan(text: ' & '),
                    TextSpan(
                      text: s.privacyPolicy,
                      style: GoogleFonts.manrope(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _OAuthButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;

  const _OAuthButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: disabled ? 0.5 : 1.0,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.blue.shade600,
          ),
        ),
      ),
    );
  }
}

class _TelegramIcon extends StatelessWidget {
  const _TelegramIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF2AABEE),
      ),
      child: const Center(
        child: Icon(Icons.send_rounded, color: Colors.white, size: 14),
      ),
    );
  }
}

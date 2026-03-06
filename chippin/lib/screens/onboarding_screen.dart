import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _selectedLanguage = 'en';
  String _selectedCurrency = 'KZT';
  bool _saving = false;

  final _currencies = [
    ('KZT', 'Tenge', '₸'),
    ('USD', 'US Dollar', '\$'),
    ('EUR', 'Euro', '\u20AC'),
    ('RUB', 'Ruble', '₽'),
    ('AED', 'Dirham', 'د.إ'),
    ('GBP', 'Pound', '£'),
  ];

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final authService = ref.read(authServiceProvider);
      final updatedUser = await authService.updateSettings(
        language: _selectedLanguage,
        currency: _selectedCurrency,
      );
      ref.read(authStateProvider.notifier).setUser(updatedUser);
    } catch (e) {
      // Even if save fails, proceed — user can change later in profile
      final currentUser = ref.read(authStateProvider).valueOrNull;
      if (currentUser != null) {
        ref.read(authStateProvider.notifier).setUser(
          currentUser.copyWith(
            language: _selectedLanguage,
            defaultCurrency: _selectedCurrency,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    // Mark onboarding as done and navigate to home
    await ref.read(authStateProvider.notifier).completeOnboarding();
    ref.read(needsOnboardingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // Title
              Center(
                child: Text(
                  'Welcome to Chippin!',
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  'Choose your preferences',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Language section
              Text(
                'LANGUAGE',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _OptionCard(
                      label: 'English',
                      selected: _selectedLanguage == 'en',
                      onTap: () => setState(() => _selectedLanguage = 'en'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OptionCard(
                      label: 'Русский',
                      selected: _selectedLanguage == 'ru',
                      onTap: () => setState(() => _selectedLanguage = 'ru'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Currency section
              Text(
                _selectedLanguage == 'ru' ? 'ВАЛЮТА' : 'CURRENCY',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: _currencies.length,
                  itemBuilder: (context, index) {
                    final (code, name, symbol) = _currencies[index];
                    return _OptionCard(
                      label: '$symbol  $code',
                      selected: _selectedCurrency == code,
                      onTap: () => setState(() => _selectedCurrency = code),
                    );
                  },
                ),
              ),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _selectedLanguage == 'ru' ? 'Продолжить' : 'Continue',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.accent : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

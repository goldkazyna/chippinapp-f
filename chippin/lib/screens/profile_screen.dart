import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/l10n.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/bills_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _savingLanguage = false;

  static const List<_LanguageOption> _languages = [
    _LanguageOption(code: 'en', name: 'English'),
    _LanguageOption(code: 'ru', name: 'Русский'),
    _LanguageOption(code: 'kk', name: 'Қазақша'),
    _LanguageOption(code: 'es', name: 'Español'),
    _LanguageOption(code: 'de', name: 'Deutsch'),
    _LanguageOption(code: 'fr', name: 'Français'),
    _LanguageOption(code: 'tr', name: 'Türkçe'),
    _LanguageOption(code: 'zh', name: '中文'),
  ];

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, 1).toUpperCase();
  }

  String _formatAmount(double amount, String currency) {
    final intPart = amount.toInt();
    final formatted = intPart.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    return '$formatted $currency';
  }

  int _languageIndex(String code) {
    final idx = _languages.indexWhere((l) => l.code == code);
    return idx >= 0 ? idx : 0;
  }

  void _showLanguageSheet(String currentCode) {
    final messenger = ScaffoldMessenger.of(context);
    final s = ref.read(l10nProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _SelectionSheet(
        title: s.language,
        items: _languages.map((l) => l.name).toList(),
        selectedIndex: _languageIndex(currentCode),
        onSelected: (index) async {
          Navigator.pop(sheetContext);
          final code = _languages[index].code;
          if (code == currentCode) return;
          setState(() => _savingLanguage = true);
          try {
            final updated = await ref
                .read(authServiceProvider)
                .updateSettings(language: code);
            ref.read(authStateProvider.notifier).setUser(updated);
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppTheme.error),
              );
            }
          } finally {
            if (mounted) setState(() => _savingLanguage = false);
          }
        },
      ),
    );
  }

  Future<void> _logout() async {
    await ref.read(authStateProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(l10nProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final bills = ref.watch(billsProvider).valueOrNull ?? [];

    final userName = user?.name ?? 'User';
    final userEmail = user?.email ?? '';
    final languageCode = user?.language ?? 'en';
    final totalSpent = bills.fold(0.0, (sum, b) => sum + b.total);
    final currency = bills.isNotEmpty ? bills.first.currency : 'KZT';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Header with back button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/home');
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(Icons.chevron_left_rounded,
                            color: Color(0x99FFFFFF), size: 24),
                      ),
                    ),
                    Expanded(
                      child: Text(s.profile,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              )),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Avatar
              Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.border, width: 2),
                    ),
                    child: Center(
                      child: Text(_getInitials(userName),
                          style: GoogleFonts.manrope(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent,
                        border:
                            Border.all(color: AppTheme.background, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_outlined,
                          size: 14, color: AppTheme.accentText),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Text(userName,
                  style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              if (userEmail.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email_outlined,
                        size: 14, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Text(userEmail,
                        style: GoogleFonts.manrope(
                            fontSize: 13, color: AppTheme.textMuted)),
                  ],
                ),

              const SizedBox(height: 24),

              // Stats row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  Expanded(
                      child: _StatBox(
                          value: '${bills.length}', label: s.bills)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      value: _formatAmount(totalSpent, currency),
                      label: s.total,
                      valueColor: AppTheme.accent,
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 28),

              // PREFERENCES section
              _SectionLabel(label: s.preferences),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(children: [
                    _SettingsRow(
                      icon: Icons.language_rounded,
                      title: s.language,
                      subtitle: s.languageSubtitle,
                      trailing: _savingLanguage
                          ? null
                          : _languages[_languageIndex(languageCode)].name,
                      isLoading: _savingLanguage,
                      onTap: () => _showLanguageSheet(languageCode),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 28),

              // GENERAL section
              _SectionLabel(label: s.general),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(children: [
                    _SettingsRow(
                      icon: Icons.info_outline_rounded,
                      title: s.aboutApp,
                      subtitle: s.aboutAppSubtitle,
                      onTap: () {},
                    ),
                    Divider(
                        height: 1, color: AppTheme.border, indent: 54),
                    _SettingsRow(
                      icon: Icons.star_outline_rounded,
                      title: s.rateApp,
                      subtitle: s.rateAppSubtitle,
                      onTap: () {},
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 28),

              // Log Out
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: _logout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(children: [
                      Icon(Icons.logout_rounded,
                          size: 20, color: AppTheme.error),
                      const SizedBox(width: 14),
                      Text(s.logOut,
                          style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.error)),
                    ]),
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5)),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _StatBox({
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        Text(value,
            style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
                letterSpacing: 0.5)),
      ]),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final bool isLoading;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 18, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: GoogleFonts.manrope(
                        fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent))
          else if (trailing != null)
            Text(trailing!,
                style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: AppTheme.textMuted),
        ]),
      ),
    );
  }
}

class _SelectionSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _SelectionSheet({
    required this.title,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      )),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final isSelected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => onSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentDim
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected
                              ? AppTheme.accent
                              : Colors.transparent),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(items[index],
                            style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.accent
                                    : AppTheme.textPrimary)),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppTheme.accent
                              : Colors.transparent,
                          border: Border.all(
                              color: isSelected
                                  ? AppTheme.accent
                                  : AppTheme.border,
                              width: 2),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                size: 14, color: AppTheme.accentText)
                            : null,
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption {
  final String code;
  final String name;
  const _LanguageOption({required this.code, required this.name});
}

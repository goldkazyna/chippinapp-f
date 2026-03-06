import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/l10n.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/current_bill_provider.dart';

class NewBillScreen extends ConsumerStatefulWidget {
  const NewBillScreen({super.key});

  @override
  ConsumerState<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends ConsumerState<NewBillScreen> {
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _activeTag;
  String _selectedCurrency = 'KZT';
  bool _loading = false;

  static const List<_CurrencyOption> _currencies = [
    _CurrencyOption(code: 'USD', symbol: '\$'),
    _CurrencyOption(code: 'AED', symbol: 'د.إ'),
    _CurrencyOption(code: 'KZT', symbol: '₸'),
    _CurrencyOption(code: 'RUB', symbol: '₽'),
  ];

  bool get _isValid => _nameController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _locale {
    final lang = ref.read(authStateProvider).valueOrNull?.language ?? 'en';
    return lang == 'ru' ? 'ru_RU' : 'en_US';
  }

  String _formatDate(DateTime date, String todayLabel, String tomorrowLabel) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);
    final tomorrow = today.add(const Duration(days: 1));
    final locale = _locale;

    String prefix;
    if (selected == today) {
      prefix = todayLabel;
    } else if (selected == tomorrow) {
      prefix = tomorrowLabel;
    } else {
      prefix = DateFormat('EEEE', locale).format(date);
    }
    return '$prefix, ${DateFormat('d MMMM yyyy', locale).format(date)}';
  }

  Future<void> _pickDate() async {
    final lang = ref.read(authStateProvider).valueOrNull?.language ?? 'en';
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      locale: Locale(lang),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accent,
              onPrimary: AppTheme.accentText,
              surface: Color(0xFF1A1A1F),
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _createBill() async {
    if (!_isValid || _loading) return;
    setState(() => _loading = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final bill = await ref.read(currentBillProvider.notifier).createBill(
            name: _nameController.text.trim(),
            date: dateStr,
            currency: _selectedCurrency,
          );

      if (mounted) {
        context.push('/bills/${bill.id}/participants');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create bill: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(l10nProvider);
    final quickTags = [s.tagDinner, s.tagTrip, s.tagParty, s.tagGroceries, s.tagRent];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top nav
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: Color(0x99FFFFFF),
                        size: 24,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      s.newBill,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.billName,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: s.billNameHint,
                        hintStyle: GoogleFonts.manrope(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: quickTags.map((tag) {
                        final isActive = _activeTag == tag;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeTag = isActive ? null : tag;
                              _nameController.text = isActive ? '' : tag;
                              _nameController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: _nameController.text.length),
                              );
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color:
                                    isActive ? AppTheme.accent : AppTheme.border,
                              ),
                              color: isActive
                                  ? AppTheme.accentDim
                                  : Colors.transparent,
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isActive
                                    ? AppTheme.accent
                                    : AppTheme.textMuted,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      s.date,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatDate(_selectedDate, s.today, s.tomorrow),
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      s.currency,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _currencies.map((c) {
                        final isActive = _selectedCurrency == c.code;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCurrency = c.code),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive ? AppTheme.accent : AppTheme.border,
                                ),
                                color: isActive ? AppTheme.accentDim : Colors.transparent,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    c.symbol,
                                    style: GoogleFonts.manrope(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isActive ? AppTheme.accent : AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    c.code,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isActive ? AppTheme.accent : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0x0A6CFFB3),
                        border: Border.all(
                          color: const Color(0x0F6CFFB3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppTheme.accent.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            s.nextStepHint,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom action
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isValid && !_loading ? _createBill : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.accentText,
                    disabledBackgroundColor:
                        AppTheme.accent.withValues(alpha: 0.35),
                    disabledForegroundColor:
                        AppTheme.accentText.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accentText,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s.next,
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.chevron_right_rounded, size: 20),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyOption {
  final String code;
  final String symbol;
  const _CurrencyOption({required this.code, required this.symbol});
}

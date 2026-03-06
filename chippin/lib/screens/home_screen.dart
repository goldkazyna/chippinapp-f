import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/l10n.dart';
import '../config/theme.dart';
import '../models/bill.dart';
import '../providers/auth_provider.dart';
import '../providers/bills_provider.dart';
import '../providers/current_bill_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final Set<String> _expandedMonths;
  late final Set<String> _expandedDays;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final dayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _expandedMonths = {monthKey};
    _expandedDays = {dayKey};
    Future.microtask(() => ref.read(billsProvider.notifier).loadBills());
  }

  String _formatAmount(double amount, String currency) {
    final intPart = amount.toInt();
    final formatted = intPart.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    return '$formatted $currency';
  }

  String get _locale {
    final lang = ref.read(authStateProvider).valueOrNull?.language ?? 'en';
    return lang == 'ru' ? 'ru_RU' : 'en_US';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime date, AppStrings s) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return s.today;
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return s.yesterday;
    }
    final locale = _locale;
    if (date.year == now.year) {
      return DateFormat('d MMMM', locale).format(date);
    }
    return DateFormat('d MMMM yyyy', locale).format(date);
  }

  String _monthLabel(DateTime date) {
    return DateFormat('MMMM yyyy', _locale).format(date).toUpperCase();
  }

  bool _isDayHighlighted(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now) ||
        _isSameDay(date, now.subtract(const Duration(days: 1)));
  }

  List<_MonthGroup> _groupBills(List<Bill> bills) {
    // Parse dates, sort newest first
    final parsed = <_ParsedBill>[];
    for (final bill in bills) {
      try {
        final date = DateTime.parse(bill.date);
        parsed.add(_ParsedBill(bill: bill, date: date));
      } catch (_) {
        parsed.add(_ParsedBill(bill: bill, date: DateTime(2000)));
      }
    }
    parsed.sort((a, b) => b.date.compareTo(a.date));

    // Group by month, then by day
    final months = <String, List<_ParsedBill>>{};
    final monthOrder = <String>[];

    for (final p in parsed) {
      final mKey = '${p.date.year}-${p.date.month.toString().padLeft(2, '0')}';
      if (!months.containsKey(mKey)) {
        months[mKey] = [];
        monthOrder.add(mKey);
      }
      months[mKey]!.add(p);
    }

    final s = ref.read(l10nProvider);
    final result = <_MonthGroup>[];

    for (final mKey in monthOrder) {
      final monthBills = months[mKey]!;
      final monthDate = monthBills.first.date;

      // Group by day within month
      final days = <String, List<Bill>>{};
      final dayOrder = <String>[];
      final dayDates = <String, DateTime>{};

      for (final p in monthBills) {
        final dKey = '${p.date.year}-${p.date.month.toString().padLeft(2, '0')}-${p.date.day.toString().padLeft(2, '0')}';
        if (!days.containsKey(dKey)) {
          days[dKey] = [];
          dayOrder.add(dKey);
          dayDates[dKey] = p.date;
        }
        days[dKey]!.add(p.bill);
      }

      final dayGroups = dayOrder.map((dKey) {
        final date = dayDates[dKey]!;
        return _DayGroup(
          key: dKey,
          label: _dayLabel(date, s),
          bills: days[dKey]!,
          isHighlighted: _isDayHighlighted(date),
        );
      }).toList();

      result.add(_MonthGroup(
        key: mKey,
        label: _monthLabel(monthDate),
        days: dayGroups,
      ));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(l10nProvider);
    final billsAsync = ref.watch(billsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.myBills,
                      style: GoogleFonts.manrope(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          )),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Icon(Icons.person_outline_rounded,
                          color: AppTheme.textSecondary, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: billsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent)),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.failedToLoadBills,
                          style: GoogleFonts.manrope(
                              fontSize: 16, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Text('$e',
                          style: GoogleFonts.manrope(
                              fontSize: 13, color: AppTheme.textMuted)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(billsProvider.notifier).loadBills(),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent),
                        child: Text(s.retry),
                      ),
                    ],
                  ),
                ),
                data: (bills) {
                  if (bills.isEmpty) return _buildEmptyState(s);
                  return _buildBillsList(bills, s);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.accent,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: IconButton(
          onPressed: () => context.push('/bills/new'),
          icon: const Icon(Icons.add, color: AppTheme.accentText, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBillsList(List<Bill> bills, AppStrings s) {
    final totalSpent = bills.fold(0.0, (sum, b) => sum + b.total);
    final currency = bills.isNotEmpty ? bills.first.currency : 'KZT';
    final groups = _groupBills(bills);

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: () => ref.read(billsProvider.notifier).loadBills(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 20),

          // Stats row
          Row(children: [
            Expanded(
                child: _StatBox(
                    value: '${bills.length}', label: s.bills)),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _StatBox(
                value: _formatAmount(totalSpent, currency),
                label: s.totalSpent,
                valueColor: AppTheme.accent,
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // Grouped bills
          for (var mIdx = 0; mIdx < groups.length; mIdx++) ...[
            _buildMonthHeader(groups[mIdx], isFirst: mIdx == 0),
            if (_expandedMonths.contains(groups[mIdx].key))
              for (var dIdx = 0; dIdx < groups[mIdx].days.length; dIdx++) ...[
                _buildDayHeader(groups[mIdx].days[dIdx]),
                if (_expandedDays.contains(groups[mIdx].days[dIdx].key))
                  for (var bIdx = 0;
                      bIdx < groups[mIdx].days[dIdx].bills.length;
                      bIdx++)
                    _buildTimelineBillCard(
                      groups[mIdx].days[dIdx].bills[bIdx],
                      s,
                      isLast: bIdx ==
                          groups[mIdx].days[dIdx].bills.length - 1,
                      isHighlighted: groups[mIdx].days[dIdx].isHighlighted,
                    ),
              ],
          ],

          const SizedBox(height: 80), // space for FAB
        ],
      ),
    );
  }

  Widget _buildMonthHeader(_MonthGroup month, {bool isFirst = false}) {
    final isExpanded = _expandedMonths.contains(month.key);
    final totalBills = month.days.fold(0, (sum, d) => sum + d.bills.length);
    final totalAmount = month.days.fold(0.0, (sum, d) =>
        sum + d.bills.fold(0.0, (s, b) => s + b.total));
    final currency = month.days.first.bills.first.currency;
    final s = ref.read(l10nProvider);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedMonths.remove(month.key);
          } else {
            _expandedMonths.add(month.key);
          }
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(top: isFirst ? 16 : 24, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 4),
                Text(month.label,
                    style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5)),
                const Spacer(),
                if (!isExpanded)
                  Text('${s.nBills(totalBills)} · ${_formatAmount(totalAmount, currency)}',
                      style: GoogleFonts.manrope(
                          fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 0.5, color: AppTheme.border),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader(_DayGroup dayGroup) {
    final isExpanded = _expandedDays.contains(dayGroup.key);
    final color =
        dayGroup.isHighlighted ? AppTheme.accent : AppTheme.textPrimary;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedDays.remove(dayGroup.key);
          } else {
            _expandedDays.add(dayGroup.key);
          }
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Row(
          children: [
            Text(dayGroup.label,
                style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color)),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: isExpanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.chevron_right_rounded,
                  size: 14, color: AppTheme.textMuted),
            ),
            const Spacer(),
            Text('${dayGroup.bills.length}',
                style: GoogleFonts.manrope(
                    fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineBillCard(
    Bill bill,
    AppStrings s, {
    required bool isLast,
    required bool isHighlighted,
  }) {
    return _BillCard(
      name: bill.name,
      date: bill.date,
      peopleLabel: s.nPeople(bill.peopleCount),
      amount: _formatAmount(bill.total, bill.currency),
      onTap: () async {
        // Load full bill data to get paidByParticipantId etc.
        final fullBill = await ref.read(billServiceProvider).getBill(bill.id);
        if (mounted) context.push(fullBill.route);
      },
    );
  }

  Widget _buildEmptyState(AppStrings s) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BillIllustration(),
          const SizedBox(height: 24),
          Text(s.noBillsYet,
              style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text(s.noBillsDescription,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                  fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// --- Grouping models ---

class _ParsedBill {
  final Bill bill;
  final DateTime date;
  const _ParsedBill({required this.bill, required this.date});
}

class _MonthGroup {
  final String key;
  final String label;
  final List<_DayGroup> days;
  const _MonthGroup({required this.key, required this.label, required this.days});
}

class _DayGroup {
  final String key;
  final String label;
  final List<Bill> bills;
  final bool isHighlighted;
  const _DayGroup({
    required this.key,
    required this.label,
    required this.bills,
    this.isHighlighted = false,
  });
}

// --- Widgets ---

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

class _BillCard extends StatelessWidget {
  final String name;
  final String date;
  final String peopleLabel;
  final String amount;
  final VoidCallback onTap;

  const _BillCard({
    required this.name,
    required this.date,
    required this.peopleLabel,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.receipt_outlined,
                size: 20, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(date,
                      style: GoogleFonts.manrope(
                          fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(width: 10),
                  Icon(Icons.people_outline_rounded,
                      size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(peopleLabel,
                      style: GoogleFonts.manrope(
                          fontSize: 12, color: AppTheme.textMuted)),
                ]),
              ],
            ),
          ),
          Text(amount,
              style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ]),
      ),
    );
  }
}

class _BillIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border, width: 1.5),
            ),
          ),
          Container(
            width: 80,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _line(48),
                const SizedBox(height: 6),
                _line(40),
                const SizedBox(height: 6),
                _line(52),
                const SizedBox(height: 6),
                _line(36),
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 40,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                  color: AppTheme.accent, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(double width) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

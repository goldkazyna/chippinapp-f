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

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    // Filter by search
    final filtered = _searchQuery.isEmpty
        ? bills
        : bills
            .where((b) =>
                b.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    // Parse dates, sort newest first
    final parsed = <_ParsedBill>[];
    for (final bill in filtered) {
      try {
        final date = DateTime.parse(bill.date);
        parsed.add(_ParsedBill(bill: bill, date: date));
      } catch (_) {
        parsed.add(_ParsedBill(bill: bill, date: DateTime(2000)));
      }
    }
    parsed.sort((a, b) => b.date.compareTo(a.date));

    // Group by month
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
    final billsAsync = ref.watch(billsProvider);
    final s = ref.watch(l10nProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.history,
                      style: GoogleFonts.manrope(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          )),
                  billsAsync.whenOrNull(
                        data: (bills) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentDim,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(s.nBills(bills.length),
                              style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accent)),
                        ),
                      ) ??
                      const SizedBox.shrink(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.manrope(
                      fontSize: 14, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: s.searchBills,
                    hintStyle: GoogleFonts.manrope(
                        fontSize: 14, color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 20, color: AppTheme.textMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Bills list
            Expanded(
              child: billsAsync.when(
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.accent)),
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
                  final groups = _groupBills(bills);
                  if (groups.isEmpty) {
                    return Center(
                      child: Text(s.noBillsFound,
                          style: GoogleFonts.manrope(
                              fontSize: 15,
                              color: AppTheme.textSecondary)),
                    );
                  }
                  final searching = _searchQuery.isNotEmpty;
                  return RefreshIndicator(
                    color: AppTheme.accent,
                    onRefresh: () =>
                        ref.read(billsProvider.notifier).loadBills(),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        for (var mIdx = 0; mIdx < groups.length; mIdx++) ...[
                          _buildMonthHeader(groups[mIdx],
                              isFirst: mIdx == 0, forceExpanded: searching),
                          if (searching || _expandedMonths.contains(groups[mIdx].key))
                            for (var dIdx = 0;
                                dIdx < groups[mIdx].days.length;
                                dIdx++) ...[
                              _buildDayHeader(groups[mIdx].days[dIdx],
                                  forceExpanded: searching),
                              if (searching || _expandedDays.contains(groups[mIdx].days[dIdx].key))
                                for (var bIdx = 0;
                                    bIdx <
                                        groups[mIdx].days[dIdx].bills.length;
                                    bIdx++)
                                  _buildTimelineBillCard(
                                    groups[mIdx].days[dIdx].bills[bIdx],
                                    s,
                                    isLast: bIdx ==
                                        groups[mIdx].days[dIdx].bills.length -
                                            1,
                                    isHighlighted:
                                        groups[mIdx].days[dIdx].isHighlighted,
                                  ),
                            ],
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader(_MonthGroup month, {bool isFirst = false, bool forceExpanded = false}) {
    final isExpanded = forceExpanded || _expandedMonths.contains(month.key);
    final totalBills = month.days.fold(0, (sum, d) => sum + d.bills.length);
    final totalAmount = month.days.fold(0.0, (sum, d) =>
        sum + d.bills.fold(0.0, (s, b) => s + b.total));
    final currency = month.days.first.bills.first.currency;
    final s = ref.read(l10nProvider);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_expandedMonths.contains(month.key)) {
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

  Widget _buildDayHeader(_DayGroup dayGroup, {bool forceExpanded = false}) {
    final isExpanded = forceExpanded || _expandedDays.contains(dayGroup.key);
    final color =
        dayGroup.isHighlighted ? AppTheme.accent : AppTheme.textPrimary;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_expandedDays.contains(dayGroup.key)) {
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
    return _HistoryBillCard(
      name: bill.name,
      date: bill.date,
      people: bill.peopleCount,
      amount: _formatAmount(bill.total, bill.currency),
      onTap: () => context.push(bill.route),
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

class _HistoryBillCard extends StatelessWidget {
  final String name;
  final String date;
  final int people;
  final String amount;
  final VoidCallback onTap;

  const _HistoryBillCard({
    required this.name,
    required this.date,
    required this.people,
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
                  const SizedBox(width: 8),
                  Icon(Icons.people_outline_rounded,
                      size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text('$people',
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

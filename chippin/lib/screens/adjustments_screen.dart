import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/l10n.dart';
import '../config/theme.dart';
import '../models/bill.dart';
import '../models/bill_adjustment.dart';
import '../providers/current_bill_provider.dart';
import '../widgets/delete_bill_button.dart';

class _AdjState {
  bool enabled = false;
  String calcMode = 'percent'; // 'percent' or 'fixed'
  double value = 0;
  String splitMode = 'proportional'; // 'proportional' or 'equal'
  int? selectedPercentIndex; // index of quick % button, null if custom/fixed
}

class AdjustmentsScreen extends ConsumerStatefulWidget {
  final int billId;
  const AdjustmentsScreen({super.key, required this.billId});

  @override
  ConsumerState<AdjustmentsScreen> createState() => _AdjustmentsScreenState();
}

class _AdjustmentsScreenState extends ConsumerState<AdjustmentsScreen> {
  late final Map<String, _AdjState> _states;
  final Map<String, TextEditingController> _fixedControllers = {};
  final Map<String, TextEditingController> _customPercentControllers = {};
  bool _submitting = false;
  bool _initialized = false;

  static const _types = ['tip', 'service', 'tax', 'delivery', 'discount'];
  static const _percentOptions = {
    'tip': [10, 15, 20],
    'service': [10, 15, 20],
    'tax': [10, 15, 20],
    'discount': [5, 10, 15],
  };

  @override
  void initState() {
    super.initState();
    _states = {for (final t in _types) t: _AdjState()};
    for (final t in _types) {
      _fixedControllers[t] = TextEditingController();
      _customPercentControllers[t] = TextEditingController();
    }

    final bill = ref.read(currentBillProvider).valueOrNull;
    if (bill == null || bill.id != widget.billId) {
      Future.microtask(
          () => ref.read(currentBillProvider.notifier).loadBill(widget.billId));
    } else {
      _initFromBill(bill);
    }
  }

  void _initFromBill(Bill bill) {
    if (_initialized) return;
    _initialized = true;
    for (final adj in bill.adjustments) {
      final st = _states[adj.type];
      if (st == null) continue;
      st.enabled = true;
      st.calcMode = adj.calcMode;
      st.value = adj.value;
      st.splitMode = adj.splitMode;

      if (adj.calcMode == 'fixed') {
        _fixedControllers[adj.type]!.text = _formatValue(adj.value);
      } else {
        // Check if it matches a quick percent
        final opts = _percentOptions[adj.type];
        if (opts != null) {
          final idx = opts.indexOf(adj.value.toInt());
          if (idx >= 0) {
            st.selectedPercentIndex = idx;
          } else {
            // Custom percent
            _customPercentControllers[adj.type]!.text =
                _formatValue(adj.value);
          }
        }
      }
    }
  }

  String _formatValue(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  @override
  void dispose() {
    for (final c in _fixedControllers.values) {
      c.dispose();
    }
    for (final c in _customPercentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _typeLabel(String type, AppStrings s) {
    return switch (type) {
      'tip' => s.tips,
      'service' => s.serviceFee,
      'tax' => s.tax,
      'delivery' => s.delivery,
      'discount' => s.discount,
      _ => type,
    };
  }

  bool _hasPercentOptions(String type) => type != 'delivery';
  bool _hasSplitMode(String type) => type != 'discount';

  double _computeAmount(String type, double subtotal) {
    final st = _states[type]!;
    if (!st.enabled || st.value <= 0) return 0;
    if (st.calcMode == 'percent') {
      return subtotal * st.value / 100;
    }
    return st.value;
  }

  String _formatAmount(double amount, String currency) {
    String num;
    if (amount == amount.truncateToDouble()) {
      num = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    } else {
      num = amount.toStringAsFixed(2);
    }
    return '$num $currency';
  }

  void _selectQuickPercent(String type, int index) {
    final opts = _percentOptions[type]!;
    setState(() {
      final st = _states[type]!;
      st.calcMode = 'percent';
      st.value = opts[index].toDouble();
      st.selectedPercentIndex = index;
      _fixedControllers[type]!.clear();
      _customPercentControllers[type]!.clear();
    });
  }

  void _onCustomPercentChanged(String type, String text) {
    final val = double.tryParse(text) ?? 0;
    setState(() {
      final st = _states[type]!;
      st.calcMode = 'percent';
      st.value = val;
      st.selectedPercentIndex = null;
      _fixedControllers[type]!.clear();
    });
  }

  void _onFixedChanged(String type, String text) {
    final val = double.tryParse(text) ?? 0;
    setState(() {
      final st = _states[type]!;
      st.calcMode = 'fixed';
      st.value = val;
      st.selectedPercentIndex = null;
      _customPercentControllers[type]!.clear();
    });
  }

  Future<void> _submit({bool skip = false}) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final List<BillAdjustment> adjustments;
      if (skip) {
        adjustments = [];
      } else {
        adjustments = _types
            .where((t) => _states[t]!.enabled && _states[t]!.value > 0)
            .map((t) {
          final st = _states[t]!;
          return BillAdjustment(
            type: t,
            calcMode: st.calcMode,
            value: st.value,
            splitMode: st.splitMode,
          );
        }).toList();
      }

      await ref
          .read(billServiceProvider)
          .syncAdjustments(widget.billId, adjustments);
      await ref.read(currentBillProvider.notifier).refresh();

      if (mounted) {
        context.push('/bills/${widget.billId}/split');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(l10nProvider);
    final billAsync = ref.watch(currentBillProvider);

    return billAsync.when(
      loading: () => const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.accent)),
      ),
      error: (e, _) => Scaffold(
        body: Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppTheme.error))),
      ),
      data: (bill) {
        if (bill == null) {
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: AppTheme.accent)),
          );
        }

        // Initialize from existing adjustments on first data load
        if (!_initialized) {
          _initFromBill(bill);
        }

        final subtotal = bill.total;
        final currency = bill.currency;

        // Compute amounts
        final amounts = <String, double>{};
        for (final t in _types) {
          amounts[t] = _computeAmount(t, subtotal);
        }

        final grandTotal = subtotal +
            amounts.entries.fold<double>(0, (sum, e) {
              if (e.key == 'discount') return sum - e.value;
              return sum + e.value;
            });

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top nav
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Row(children: [
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
                        child: const Icon(Icons.chevron_left_rounded,
                            color: Color(0x99FFFFFF), size: 24),
                      ),
                    ),
                    Expanded(
                      child: Text(s.adjustments,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                    ),
                    DeleteBillButton(billId: widget.billId),
                  ]),
                ),

                // Toggle cards
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    children: [
                      for (final type in _types) ...[
                        _buildToggleCard(
                            type, subtotal, currency, amounts[type]!, s),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 16),
                      // Summary section
                      _buildSummary(
                          subtotal, currency, amounts, grandTotal, s),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: TextButton(
                            onPressed:
                                _submitting ? null : () => _submit(skip: true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(s.skipAdjustments,
                                style: GoogleFonts.manrope(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : () => _submit(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: AppTheme.accentText,
                              disabledBackgroundColor:
                                  AppTheme.accent.withValues(alpha: 0.35),
                              disabledForegroundColor:
                                  AppTheme.accentText.withValues(alpha: 0.5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.accentText))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(s.next,
                                          style: GoogleFonts.manrope(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right_rounded,
                                          size: 20),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggleCard(String type, double subtotal, String currency,
      double computedAmount, AppStrings s) {
    final st = _states[type]!;
    final isDiscount = type == 'discount';
    final sign = isDiscount ? '-' : '+';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: st.enabled ? AppTheme.accentDim : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: st.enabled ? AppTheme.accent.withValues(alpha: 0.3) : AppTheme.border),
      ),
      child: Column(
        children: [
          // Header row (always visible)
          GestureDetector(
            onTap: () {
              setState(() {
                st.enabled = !st.enabled;
              });
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Toggle circle
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: st.enabled ? AppTheme.accent : Colors.transparent,
                      border: Border.all(
                          color:
                              st.enabled ? AppTheme.accent : AppTheme.border,
                          width: 1.5),
                    ),
                    child: st.enabled
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: AppTheme.accentText)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_typeLabel(type, s),
                        style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: st.enabled
                                ? AppTheme.accent
                                : AppTheme.textPrimary)),
                  ),
                  if (st.enabled && computedAmount > 0)
                    Text(
                      '$sign${_formatAmount(computedAmount, currency)}',
                      style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDiscount
                              ? AppTheme.error
                              : AppTheme.accent),
                    ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (st.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick percent buttons (not for delivery)
                  if (_hasPercentOptions(type)) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...(_percentOptions[type] ?? [])
                            .asMap()
                            .entries
                            .map((entry) {
                          final idx = entry.key;
                          final pct = entry.value;
                          final isSelected =
                              st.calcMode == 'percent' &&
                                  st.selectedPercentIndex == idx;
                          return GestureDetector(
                            onTap: () => _selectQuickPercent(type, idx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: isSelected
                                    ? AppTheme.accent
                                    : AppTheme.surface,
                                border: Border.all(
                                    color: isSelected
                                        ? AppTheme.accent
                                        : AppTheme.border),
                              ),
                              child: Text(
                                '$pct%',
                                style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppTheme.accentText
                                        : AppTheme.textPrimary),
                              ),
                            ),
                          );
                        }),
                        // Custom percent button
                        _buildCustomPercentChip(type, s),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Fixed amount input
                    Row(
                      children: [
                        Text(
                          type == 'delivery'
                              ? ''
                              : s.customAmount == 'Custom'
                                  ? 'Or fixed:'
                                  : '\u0418\u043B\u0438 \u0444\u0438\u043A\u0441:',
                          style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.textMuted),
                        ),
                        if (type != 'delivery') const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _fixedControllers[type],
                              onChanged: (v) => _onFixedChanged(type, v),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d.]'))
                              ],
                              style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                hintText: '0',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                filled: true,
                                fillColor: const Color(0x08FFFFFF),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: AppTheme.border)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: AppTheme.border)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: AppTheme.borderFocus)),
                                suffixText: currency,
                                suffixStyle: GoogleFonts.manrope(
                                    fontSize: 13,
                                    color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Delivery: only fixed amount input
                  if (!_hasPercentOptions(type)) ...[
                    Row(
                      children: [
                        Text(
                          s.customAmount == 'Custom' ? 'Amount:' : '\u0421\u0443\u043C\u043C\u0430:',
                          style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.textMuted),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _fixedControllers[type],
                              onChanged: (v) => _onFixedChanged(type, v),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d.]'))
                              ],
                              style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                hintText: '0',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                filled: true,
                                fillColor: const Color(0x08FFFFFF),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: AppTheme.border)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: AppTheme.border)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: AppTheme.borderFocus)),
                                suffixText: currency,
                                suffixStyle: GoogleFonts.manrope(
                                    fontSize: 13,
                                    color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Split mode (not for discount)
                  if (_hasSplitMode(type)) ...[
                    const SizedBox(height: 14),
                    Text(
                      s.customAmount == 'Custom' ? 'Split:' : '\u0414\u0435\u043B\u0438\u0442\u044C:',
                      style: GoogleFonts.manrope(
                          fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSplitModeChip(
                            type, 'proportional', s.proportional),
                        const SizedBox(width: 10),
                        _buildSplitModeChip(type, 'equal', s.equalSplit),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomPercentChip(String type, AppStrings s) {
    final st = _states[type]!;
    final isCustomPercent = st.calcMode == 'percent' &&
        st.selectedPercentIndex == null &&
        _customPercentControllers[type]!.text.isNotEmpty;

    return GestureDetector(
      onTap: () {
        // Focus the custom percent field
        setState(() {
          st.selectedPercentIndex = null;
        });
      },
      child: Container(
        width: 90,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isCustomPercent ? AppTheme.accent : AppTheme.surface,
          border: Border.all(
              color: isCustomPercent ? AppTheme.accent : AppTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customPercentControllers[type],
                onChanged: (v) => _onCustomPercentChanged(type, v),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCustomPercent
                        ? AppTheme.accentText
                        : AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: s.customAmount,
                  hintStyle: GoogleFonts.manrope(
                      fontSize: 12,
                      color: isCustomPercent
                          ? AppTheme.accentText.withValues(alpha: 0.5)
                          : AppTheme.textMuted),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
            Text('%',
                style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isCustomPercent
                        ? AppTheme.accentText
                        : AppTheme.textMuted)),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitModeChip(String type, String mode, String label) {
    final st = _states[type]!;
    final isSelected = st.splitMode == mode;

    return GestureDetector(
      onTap: () {
        setState(() {
          st.splitMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? AppTheme.accent : AppTheme.surface,
          border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected
                        ? AppTheme.accentText
                        : AppTheme.textMuted,
                    width: 1.5),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accentText),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? AppTheme.accentText
                        : AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(double subtotal, String currency,
      Map<String, double> amounts, double grandTotal, AppStrings s) {
    final enabledTypes =
        _types.where((t) => _states[t]!.enabled && amounts[t]! > 0).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Subtotal
          _summaryRow(
            s.subtotal,
            _formatAmount(subtotal, currency),
            AppTheme.textSecondary,
          ),
          // Each enabled adjustment
          for (final type in enabledTypes) ...[
            const SizedBox(height: 8),
            _summaryRow(
              _summaryLabel(type, s),
              '${type == 'discount' ? '-' : '+'}${_formatAmount(amounts[type]!, currency)}',
              type == 'discount' ? AppTheme.error : AppTheme.accent,
            ),
          ],
          if (enabledTypes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
                height: 1,
                color: AppTheme.border),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 8),
          // Grand total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.total,
                  style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              Text(_formatAmount(grandTotal, currency),
                  style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3)),
            ],
          ),
        ],
      ),
    );
  }

  String _summaryLabel(String type, AppStrings s) {
    final st = _states[type]!;
    final label = _typeLabel(type, s);
    if (st.calcMode == 'percent') {
      return '$label (${_formatValue(st.value)}%)';
    }
    return label;
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary)),
        Text(value,
            style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor)),
      ],
    );
  }
}

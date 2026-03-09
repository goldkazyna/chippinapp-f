import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/env.dart';

import '../config/l10n.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/bills_provider.dart';
import '../providers/current_bill_provider.dart';
import '../utils/json_converters.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  final int billId;
  const SummaryScreen({super.key, required this.billId});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  Map<String, dynamic>? _summary;
  bool _loadingSummary = true;
  bool _loadingPdf = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final bill = ref.read(currentBillProvider).valueOrNull;
    if (bill == null || bill.id != widget.billId) {
      Future.microtask(
          () => ref.read(currentBillProvider.notifier).loadBill(widget.billId));
    }
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final data =
          await ref.read(billServiceProvider).getSummary(widget.billId);
      if (mounted) setState(() { _summary = data; _loadingSummary = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loadingSummary = false; });
    }
  }

  String _formatAmount(double amount, String currency) {
    if (amount == amount.truncateToDouble()) {
      // Whole number — no decimals
      final formatted = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
      return '$formatted $currency';
    }
    // Has decimals — show 2 decimal places
    final parts = amount.toStringAsFixed(2).split('.');
    final intFormatted = int.parse(parts[0]).toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    return '$intFormatted.${parts[1]} $currency';
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _downloadAndSharePdf() async {
    if (_loadingPdf) return;
    setState(() => _loadingPdf = true);
    try {
      final token = await ref.read(apiClientProvider).getToken();
      final lang = ref.read(authStateProvider).valueOrNull?.language ?? 'en';
      final params = <String, String>{};
      if (token != null) params['token'] = token;
      params['lang'] = lang;
      final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final url = '${Env.baseUrl}/bills/${widget.billId}/pdf?$query';
      final uri = Uri.parse(url);

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('Could not open PDF link');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  Future<void> _confirmDelete() async {
    final s = ref.read(l10nProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.deleteBill,
            style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        content: Text(s.deleteBillConfirm,
            style: GoogleFonts.manrope(
                fontSize: 14, color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel,
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.delete,
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(billsProvider.notifier).deleteBill(widget.billId);
      if (mounted) {
        ref.read(billsProvider.notifier).loadBills();
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(currentBillProvider);

    return billAsync.when(
      loading: () {
        return Scaffold(
          body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.accent),
                  const SizedBox(height: 12),
                  Text('Loading bill...', style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.textMuted)),
                ],
              )));
      },
      error: (e, _) {
        return Scaffold(
          body: SafeArea(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                Text('Bill load error', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.error)),
                const SizedBox(height: 8),
                SelectableText('$e', style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          )));
      },
      data: (bill) {
        if (bill == null || _loadingSummary) {
          return Scaffold(
              body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.accent),
                      const SizedBox(height: 12),
                      Text(bill == null ? 'bill is null...' : 'Loading summary...', style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  )));
        }

        final s = ref.watch(l10nProvider);

        if (_error != null) {
          final debugInfo = 'billId: ${bill.id}\n'
              'name: ${bill.name}\n'
              'total: ${bill.total}\n'
              'currency: ${bill.currency}\n'
              'paidBy: ${bill.paidByParticipantId}\n'
              'participants: ${bill.participants.length} ${bill.participants.map((p) => '${p.id}:${p.name}').join(', ')}\n'
              'items: ${bill.items.length} ${bill.items.map((i) => '${i.id}:${i.name}(${i.total}, splits=${i.splits.length})').join(', ')}\n'
              'itemsCount: ${bill.itemsCount}\n'
              'peopleCount: ${bill.peopleCount}';
          return Scaffold(
              body: SafeArea(
                  child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                Text(s.failedToLoadSummary,
                    style: GoogleFonts.manrope(
                        fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                Text('ERROR:', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.error)),
                const SizedBox(height: 4),
                SelectableText(_error!,
                    style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 16),
                Text('BILL DATA:', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                const SizedBox(height: 4),
                SelectableText(debugInfo,
                    style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() { _error = null; _loadingSummary = true; });
                      _loadSummary();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent),
                    child: Text(s.retry),
                  ),
                ),
              ],
            ),
          )));
        }

        final currency = bill.currency;
        final items = bill.items;
        final payerName = _summary!['payer'] as String? ?? '';
        final shares = (_summary!['shares'] as List<dynamic>?) ?? [];
        final debts = (_summary!['debts'] as List<dynamic>?) ?? [];

        // Find payer participant for initials
        final payer = bill.participants
            .where((p) => p.name == payerName)
            .toList();
        final payerInitials = payer.isNotEmpty
            ? (payer.first.isOwner ? 'YO' : _getInitials(payer.first.name))
            : _getInitials(payerName);

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(s.billSummary,
                                style: GoogleFonts.manrope(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary)),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.accent),
                              child: const Icon(Icons.check_rounded,
                                  color: AppTheme.accentText, size: 22),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Bill info card
                        Container(
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
                              child: const Icon(Icons.restaurant_outlined,
                                  size: 20, color: AppTheme.textMuted),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(bill.name,
                                      style: GoogleFonts.manrope(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(bill.date,
                                      style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 24),

                        // ITEMS section
                        Row(
                          children: [
                            Text(s.items,
                                style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                    letterSpacing: 0.5)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                await context.push('/bills/${bill.id}/items');
                                if (mounted) {
                                  ref.read(currentBillProvider.notifier).loadBill(widget.billId);
                                  setState(() { _loadingSummary = true; _error = null; });
                                  _loadSummary();
                                }
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: const Icon(Icons.add_rounded,
                                    size: 16, color: AppTheme.accent),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        ...List.generate(items.length, (index) {
                          final item = items[index];
                          final splitNames = item.splits
                              .map((s) => s.participantName)
                              .toList();
                          final peopleStr = splitNames.length ==
                                  bill.participants.length
                              ? s.everyone
                              : splitNames.join(', ');
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                    color: index < items.length - 1
                                        ? AppTheme.border
                                        : Colors.transparent),
                              ),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.name,
                                  style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Text(peopleStr,
                                    style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: AppTheme.textMuted)),
                                if (item.quantity > 1)
                                  Text('  ${item.quantity}×',
                                      style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: AppTheme.textMuted)),
                                const Spacer(),
                                Text(_formatAmount(item.total, currency),
                                    style: GoogleFonts.manrope(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary)),
                              ]),
                            ]),
                          );
                        }),
                        const SizedBox(height: 24),

                        // Adjustments breakdown (if any)
                        ...() {
                          final adjustments = (_summary!['adjustments'] as List<dynamic>?) ?? [];
                          if (adjustments.isEmpty) return <Widget>[];

                          final subtotal = toDouble(_summary!['subtotal'] ?? _summary!['total']);

                          String adjustmentLabel(Map<String, dynamic> adj) {
                            final type = adj['type'] as String? ?? '';
                            final calcMode = adj['calc_mode'] as String? ?? 'fixed';
                            final value = toDouble(adj['value'] ?? 0);
                            String name;
                            switch (type) {
                              case 'tip': name = s.tips; break;
                              case 'service': name = s.serviceFee; break;
                              case 'tax': name = s.tax; break;
                              case 'delivery': name = s.delivery; break;
                              case 'discount': name = s.discount; break;
                              default: name = type;
                            }
                            if (calcMode == 'percent') {
                              final sign = type == 'discount' ? '-' : '+';
                              final pct = value == value.truncateToDouble()
                                  ? value.toInt().toString()
                                  : value.toStringAsFixed(1);
                              return '$name ($sign$pct%)';
                            }
                            return name;
                          }

                          return <Widget>[
                            // Subtotal line
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: AppTheme.border)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(s.subtotal,
                                      style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textSecondary)),
                                  Text(_formatAmount(subtotal, currency),
                                      style: GoogleFonts.manrope(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            // Each adjustment
                            ...adjustments.map((a) {
                              final adj = a as Map<String, dynamic>;
                              final amount = toDouble(adj['amount'] ?? 0);
                              final type = adj['type'] as String? ?? '';
                              final isDiscount = type == 'discount';
                              final sign = isDiscount ? '-' : '+';
                              final displayAmount = amount.abs();
                              final label = adjustmentLabel(adj);
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(label,
                                        style: GoogleFonts.manrope(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isDiscount ? AppTheme.error : AppTheme.textSecondary)),
                                    Text('$sign${_formatAmount(displayAmount, currency)}',
                                        style: GoogleFonts.manrope(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDiscount ? AppTheme.error : AppTheme.textPrimary)),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ];
                        }(),

                        // TOTAL section
                        Text(s.total,
                            style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: AppTheme.accentDim,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.accent.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(s.grandTotal,
                                  style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary)),
                              Text(
                                  _formatAmount(
                                    ((_summary!['adjustments'] as List<dynamic>?) ?? []).isNotEmpty
                                        ? toDouble(_summary!['total'])
                                        : bill.total,
                                    currency),
                                  style: GoogleFonts.manrope(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accent,
                                      letterSpacing: -0.3)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // PAID BY section
                        Text(s.paidBy,
                            style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        Container(
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
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.accent),
                              child: Center(
                                child: Text(payerInitials,
                                    style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.accentText)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(payerName,
                                      style: GoogleFonts.manrope(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(s.coveredFullBill,
                                      style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: AppTheme.accent)),
                                ],
                              ),
                            ),
                          ]),
                        ),

                        // SHARES section
                        if (shares.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(s.eachPersonShare,
                              style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 8),
                          ...shares.map((s) {
                            final sMap = s as Map<String, dynamic>;
                            final name = sMap['name'] as String;
                            final amount = toDouble(sMap['amount']);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.accentDim,
                                    border: Border.all(
                                        color: AppTheme.accent
                                            .withValues(alpha: 0.25)),
                                  ),
                                  child: Center(
                                    child: Text(_getInitials(name),
                                        style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.accent)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(name,
                                      style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textPrimary)),
                                ),
                                Text(_formatAmount(amount, currency),
                                    style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary)),
                              ]),
                            );
                          }),
                        ],

                        // DEBTS section
                        if (debts.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(s.whoOwesWhat,
                              style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 8),
                          ...debts.map((d) {
                            final dMap = d as Map<String, dynamic>;
                            final from = dMap['from'] as String;
                            final to = dMap['to'] as String;
                            final amount = toDouble(dMap['amount']);
                            return Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0x0AF59E0B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0x1AF59E0B)),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.surface,
                                    border:
                                        Border.all(color: AppTheme.border),
                                  ),
                                  child: Center(
                                    child: Text(_getInitials(from),
                                        style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textSecondary)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('$from → $to',
                                          style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary)),
                                      const SizedBox(height: 2),
                                      Text(s.owes,
                                          style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: AppTheme.textMuted)),
                                    ],
                                  ),
                                ),
                                Text(_formatAmount(amount, currency),
                                    style: GoogleFonts.manrope(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFF59E0B))),
                              ]),
                            );
                          }),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        // Share / PDF button
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: _loadingPdf ? null : _downloadAndSharePdf,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textPrimary,
                                side: const BorderSide(color: AppTheme.border),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _loadingPdf
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.textMuted))
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.ios_share_rounded,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Text(s.share,
                                            style: GoogleFonts.manrope(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Done button
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                ref.read(billsProvider.notifier).loadBills();
                                context.go('/home');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: AppTheme.accentText,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(s.done,
                                      style: GoogleFonts.manrope(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      // Delete button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton(
                          onPressed: _deleting ? null : _confirmDelete,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _deleting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.error))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.delete_outline_rounded,
                                        size: 18, color: AppTheme.error),
                                    const SizedBox(width: 8),
                                    Text(s.deleteBill,
                                        style: GoogleFonts.manrope(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.error)),
                                  ],
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
}

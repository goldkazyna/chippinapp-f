import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/l10n.dart';
import '../config/theme.dart';
import '../providers/current_bill_provider.dart';
import '../widgets/delete_bill_button.dart';

class PaidByScreen extends ConsumerStatefulWidget {
  final int billId;
  const PaidByScreen({super.key, required this.billId});

  @override
  ConsumerState<PaidByScreen> createState() => _PaidByScreenState();
}

class _PaidByScreenState extends ConsumerState<PaidByScreen> {
  int? _selectedParticipantId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final bill = ref.read(currentBillProvider).valueOrNull;
    if (bill == null || bill.id != widget.billId) {
      Future.microtask(
          () => ref.read(currentBillProvider.notifier).loadBill(widget.billId));
    } else if (bill.paidByParticipantId != null) {
      _selectedParticipantId = bill.paidByParticipantId;
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _formatAmount(double amount) {
    final intPart = amount.toInt();
    return intPart.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
  }

  Future<void> _finish() async {
    if (_selectedParticipantId == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(billServiceProvider)
          .setPaidBy(widget.billId, _selectedParticipantId!);
      if (mounted) {
        context.push('/bills/${widget.billId}/summary');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(currentBillProvider);

    return billAsync.when(
      loading: () => const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: AppTheme.accent))),
      error: (e, _) => Scaffold(
          body: Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: AppTheme.error)))),
      data: (bill) {
        if (bill == null) {
          return const Scaffold(
              body: Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.accent)));
        }

        final s = ref.watch(l10nProvider);
        final participants = bill.participants;
        final currency = bill.currency;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top nav
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border)),
                        child: const Icon(Icons.chevron_left_rounded,
                            color: Color(0x99FFFFFF), size: 24),
                      ),
                    ),
                    Expanded(
                        child: Text(s.whoPaid,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary))),
                    DeleteBillButton(billId: widget.billId),
                  ]),
                ),

                // Bill total
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(children: [
                    Text(s.billTotal,
                        style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Text('${_formatAmount(bill.total)} $currency',
                        style: GoogleFonts.manrope(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 6),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_outlined,
                              size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                              s.itemsAndPeople(bill.items.length, participants.length),
                              style: GoogleFonts.manrope(
                                  fontSize: 13, color: AppTheme.textMuted)),
                        ]),
                  ]),
                ),
                const SizedBox(height: 32),

                // Section label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(s.selectWhoPaid,
                        style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(height: 12),

                // People list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final p = participants[index];
                      final isSelected = _selectedParticipantId == p.id;
                      return _PersonRadioCard(
                        initials: p.isOwner ? 'YO' : _getInitials(p.name),
                        name: p.isOwner ? s.you : p.name,
                        tag: p.isOwner ? s.organizer : s.participant,
                        paidLabel: s.paid,
                        isYou: p.isOwner,
                        isSelected: isSelected,
                        onTap: () =>
                            setState(() => _selectedParticipantId = p.id),
                      );
                    },
                  ),
                ),

                // Finish button
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _selectedParticipantId != null && !_submitting
                          ? _finish
                          : null,
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
                                  Text(s.finish,
                                      style: GoogleFonts.manrope(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.check_rounded, size: 20),
                                ]),
                    ),
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

class _PersonRadioCard extends StatelessWidget {
  final String initials, name, tag, paidLabel;
  final bool isYou, isSelected;
  final VoidCallback onTap;

  const _PersonRadioCard(
      {required this.initials,
      required this.name,
      required this.tag,
      required this.paidLabel,
      required this.isYou,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentDim : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.border),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppTheme.accent
                  : (isYou ? AppTheme.accentDim : AppTheme.surface),
              border: Border.all(
                  color: isSelected
                      ? AppTheme.accent
                      : (isYou
                          ? AppTheme.accent.withValues(alpha: 0.25)
                          : AppTheme.border)),
            ),
            child: Center(
                child: Text(initials,
                    style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.accentText
                            : (isYou
                                ? AppTheme.accent
                                : AppTheme.textSecondary)))),
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
                const SizedBox(height: 2),
                Text(tag,
                    style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: isSelected
                            ? AppTheme.accent
                            : AppTheme.textMuted)),
              ])),
          if (isSelected)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppTheme.accent.withValues(alpha: 0.2)),
              child: Text(paidLabel,
                  style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                      letterSpacing: 0.5)),
            ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppTheme.accent : Colors.transparent,
              border: Border.all(
                  color: isSelected ? AppTheme.accent : AppTheme.border,
                  width: 2),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accentText)))
                : null,
          ),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/l10n.dart';
import '../config/theme.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/participant.dart';
import '../providers/current_bill_provider.dart';
import '../widgets/delete_bill_button.dart';

class SplitItemsScreen extends ConsumerStatefulWidget {
  final int billId;
  const SplitItemsScreen({super.key, required this.billId});

  @override
  ConsumerState<SplitItemsScreen> createState() => _SplitItemsScreenState();
}

class _SplitItemsScreenState extends ConsumerState<SplitItemsScreen> {
  @override
  void initState() {
    super.initState();
    final bill = ref.read(currentBillProvider).valueOrNull;
    if (bill == null || bill.id != widget.billId) {
      Future.microtask(
          () => ref.read(currentBillProvider.notifier).loadBill(widget.billId));
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _formatAmount(double amount) {
    if (amount == amount.truncateToDouble()) {
      return amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    }
    return amount.toStringAsFixed(2);
  }

  String _itemSubtitle(BillItem item) {
    if (item.splits.isEmpty) {
      return '${item.quantity} × ${_formatAmount(item.pricePerUnit)}';
    }
    final names = item.splits.map((s) => s.participantName ?? 'Unknown').toSet();
    return names.join(', ');
  }

  void _openSplitSheet(Bill bill, BillItem item, AppStrings s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SplitBottomSheet(
        item: item,
        participants: bill.participants,
        getInitials: _getInitials,
        strings: s,
        onSplitEqual: () async {
          Navigator.of(ctx).pop();
          try {
            await ref.read(billServiceProvider).splitEqual(widget.billId, item.id);
            await ref.read(currentBillProvider.notifier).refresh();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
              );
            }
          }
        },
        onSplitCustom: (splits) async {
          Navigator.of(ctx).pop();
          try {
            await ref.read(billServiceProvider).splitCustom(widget.billId, item.id, splits);
            await ref.read(currentBillProvider.notifier).refresh();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(l10nProvider);
    final billAsync = ref.watch(currentBillProvider);

    return billAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
      ),
      data: (bill) {
        if (bill == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.accent)));
        }

        final items = bill.items;
        final assignedCount = items.where((i) => i.isSplit).length;
        final canProceed = assignedCount == items.length && items.isNotEmpty;

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
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                        child: const Icon(Icons.chevron_left_rounded, color: Color(0x99FFFFFF), size: 24),
                      ),
                    ),
                    Expanded(child: Text(s.splitItems, textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
                    DeleteBillButton(billId: widget.billId),
                  ]),
                ),

                // Progress
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      s.itemsOfTotal(assignedCount, items.length),
                      style: GoogleFonts.manrope(fontSize: 13, color: canProceed ? AppTheme.accent : AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Items list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ItemSplitCard(
                        name: item.name,
                        meta: _itemSubtitle(item),
                        total: _formatAmount(item.total),
                        isAssigned: item.isSplit,
                        onTap: () => _openSplitSheet(bill, item, s),
                      );
                    },
                  ),
                ),

                // Bottom bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(s.total, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                        Text(_formatAmount(bill.total), style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.3)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity, height: 56,
                      child: ElevatedButton(
                        onPressed: canProceed ? () => context.push('/bills/${widget.billId}/paid-by') : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent, foregroundColor: AppTheme.accentText,
                          disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.35),
                          disabledForegroundColor: AppTheme.accentText.withValues(alpha: 0.5),
                          elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(s.next, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                          const SizedBox(width: 10),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- Item card ---

class _ItemSplitCard extends StatelessWidget {
  final String name, meta, total;
  final bool isAssigned;
  final VoidCallback onTap;

  const _ItemSplitCard({required this.name, required this.meta, required this.total, required this.isAssigned, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isAssigned ? AppTheme.accent.withValues(alpha: 0.3) : AppTheme.border),
        ),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAssigned ? AppTheme.accent : Colors.transparent,
              border: Border.all(color: isAssigned ? AppTheme.accent : AppTheme.border, width: 1.5),
            ),
            child: isAssigned ? const Icon(Icons.check_rounded, size: 16, color: AppTheme.accentText) : null,
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Row(children: [
              Text(meta, style: GoogleFonts.manrope(fontSize: 12, color: isAssigned ? AppTheme.accent : AppTheme.textMuted)),
              const Spacer(),
              Text(total, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ]),
          ])),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textMuted),
        ]),
      ),
    );
  }
}

// --- Bottom Sheet ---

class _SplitBottomSheet extends StatefulWidget {
  final BillItem item;
  final List<Participant> participants;
  final String Function(String) getInitials;
  final AppStrings strings;
  final Future<void> Function() onSplitEqual;
  final Future<void> Function(List<Map<String, dynamic>> splits) onSplitCustom;

  const _SplitBottomSheet({required this.item, required this.participants, required this.getInitials, required this.strings, required this.onSplitEqual, required this.onSplitCustom});

  @override
  State<_SplitBottomSheet> createState() => _SplitBottomSheetState();
}

class _SplitBottomSheetState extends State<_SplitBottomSheet> {
  String _mode = 'none';
  final Set<int> _chosenPeopleIds = {};
  final Map<int, int> _chosenQty = {};
  bool _submitting = false;

  int get _distributedQty => _chosenQty.values.fold(0, (a, b) => a + b);
  int get _remainingQty => widget.item.quantity - _distributedQty;

  void _selectMode(String mode) {
    setState(() {
      _mode = mode;
      if (mode == 'equal') {
        _chosenPeopleIds.clear();
        _chosenQty.clear();
      }
    });
  }

  void _togglePerson(int id) {
    setState(() {
      if (_chosenPeopleIds.contains(id)) {
        _chosenPeopleIds.remove(id);
      } else {
        _chosenPeopleIds.add(id);
      }
    });
  }

  void _incrementQty(int id) {
    if (_remainingQty <= 0) return;
    setState(() => _chosenQty[id] = (_chosenQty[id] ?? 0) + 1);
  }

  void _decrementQty(int id) {
    final current = _chosenQty[id] ?? 0;
    if (current <= 0) return;
    setState(() {
      if (current == 1) {
        _chosenQty.remove(id);
      } else {
        _chosenQty[id] = current - 1;
      }
    });
  }

  Future<void> _handleDone() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    if (_mode == 'equal') {
      await widget.onSplitEqual();
    } else if (_mode == 'choose') {
      List<Map<String, dynamic>> splits;
      if (widget.item.quantity == 1) {
        // Each checked person gets quantity: 1
        splits = _chosenPeopleIds.map((id) => {'participant_id': id, 'quantity': 1}).toList();
      } else {
        // Use assigned quantities
        splits = _chosenQty.entries
            .where((e) => e.value > 0)
            .map((e) => {'participant_id': e.key, 'quantity': e.value})
            .toList();
      }
      await widget.onSplitCustom(splits);
    }
  }

  bool get _canDone {
    if (_mode == 'equal') return true;
    if (_mode == 'choose') {
      if (widget.item.quantity == 1) return _chosenPeopleIds.isNotEmpty;
      return _distributedQty == widget.item.quantity;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF141418), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),

            // Item header
            Text(widget.item.name, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
              child: Text('${widget.item.quantity} × ${widget.item.pricePerUnit.toStringAsFixed(0)}', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
            ),
            const SizedBox(height: 20),

            _ModeCard(icon: Icons.groups_outlined, title: widget.strings.splitEqually, subtitle: widget.strings.divideAmongEveryone, isActive: _mode == 'equal', onTap: () => _selectMode('equal')),
            const SizedBox(height: 10),
            _ModeCard(icon: Icons.person_add_alt_outlined, title: widget.strings.choosePeople, subtitle: widget.strings.pickWhoPays, isActive: _mode == 'choose', onTap: () => _selectMode('choose')),

            if (_mode == 'choose') ...[
              const SizedBox(height: 20),
              Text(widget.strings.selectParticipants, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 0.5)),
              const SizedBox(height: 12),

              if (widget.item.quantity == 1)
                ...widget.participants.map((p) => _ParticipantCheckRow(
                      initials: widget.getInitials(p.name),
                      name: p.isOwner ? widget.strings.you : p.name,
                      isChecked: _chosenPeopleIds.contains(p.id),
                      onTap: () => _togglePerson(p.id),
                    )),

              if (widget.item.quantity > 1) ...[
                ...widget.participants.map((p) => _ParticipantQtyRow(
                      initials: widget.getInitials(p.name),
                      name: p.isOwner ? widget.strings.you : p.name,
                      qty: _chosenQty[p.id] ?? 0,
                      canIncrement: _remainingQty > 0,
                      onIncrement: () => _incrementQty(p.id),
                      onDecrement: () => _decrementQty(p.id),
                    )),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppTheme.surface, border: Border.all(color: AppTheme.border)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(widget.strings.distributed, style: GoogleFonts.manrope(fontSize: 14, color: AppTheme.textSecondary)),
                    Text('$_distributedQty of ${widget.item.quantity}', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: _distributedQty == widget.item.quantity ? AppTheme.accent : AppTheme.textSecondary)),
                  ]),
                ),
              ],
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _canDone && !_submitting ? _handleDone : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent, foregroundColor: AppTheme.accentText, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentText))
                    : Text(widget.strings.done, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeCard({required this.icon, required this.title, required this.subtitle, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isActive ? AppTheme.accentDim : AppTheme.surface,
          border: Border.all(color: isActive ? AppTheme.accent : AppTheme.border),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.surface,
              border: Border.all(color: isActive ? AppTheme.accent : AppTheme.border),
            ),
            child: Icon(icon, size: 20, color: isActive ? AppTheme.accent : AppTheme.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: isActive ? AppTheme.accent : AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.textMuted)),
          ])),
        ]),
      ),
    );
  }
}

class _ParticipantCheckRow extends StatelessWidget {
  final String initials, name;
  final bool isChecked;
  final VoidCallback onTap;

  const _ParticipantCheckRow({required this.initials, required this.name, required this.isChecked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.surface, border: Border.all(color: AppTheme.border)),
            child: Center(child: Text(initials, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)))),
          const SizedBox(width: 14),
          Expanded(child: Text(name, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary))),
          Container(width: 24, height: 24,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: isChecked ? AppTheme.accent : Colors.transparent, border: Border.all(color: isChecked ? AppTheme.accent : AppTheme.border, width: 1.5)),
            child: isChecked ? const Icon(Icons.check_rounded, size: 16, color: AppTheme.accentText) : null),
        ]),
      ),
    );
  }
}

class _ParticipantQtyRow extends StatelessWidget {
  final String initials, name;
  final int qty;
  final bool canIncrement;
  final VoidCallback onIncrement, onDecrement;

  const _ParticipantQtyRow({required this.initials, required this.name, required this.qty, required this.canIncrement, required this.onIncrement, required this.onDecrement});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.surface, border: Border.all(color: AppTheme.border)),
          child: Center(child: Text(initials, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)))),
        const SizedBox(width: 14),
        Expanded(child: Text(name, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary))),
        Row(children: [
          GestureDetector(onTap: qty > 0 ? onDecrement : null, child: Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: qty > 0 ? AppTheme.surface : Colors.transparent, border: Border.all(color: qty > 0 ? AppTheme.border : Colors.transparent)), child: Icon(Icons.remove_rounded, size: 16, color: qty > 0 ? AppTheme.textSecondary : Colors.transparent))),
          SizedBox(width: 40, child: Text('$qty', textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600, color: qty > 0 ? AppTheme.textPrimary : AppTheme.textMuted))),
          GestureDetector(onTap: canIncrement ? onIncrement : null, child: Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: canIncrement ? AppTheme.surface : Colors.transparent, border: Border.all(color: canIncrement ? AppTheme.border : Colors.transparent)), child: Icon(Icons.add_rounded, size: 16, color: canIncrement ? AppTheme.textSecondary : AppTheme.textMuted))),
        ]),
      ]),
    );
  }
}

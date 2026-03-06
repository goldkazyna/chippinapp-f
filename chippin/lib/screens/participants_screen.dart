import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/l10n.dart';
import '../config/theme.dart';
import '../models/participant.dart';
import '../providers/current_bill_provider.dart';
import '../widgets/delete_bill_button.dart';

class ParticipantsScreen extends ConsumerStatefulWidget {
  final int billId;
  const ParticipantsScreen({super.key, required this.billId});

  @override
  ConsumerState<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends ConsumerState<ParticipantsScreen> {
  final _nameController = TextEditingController();
  final _focusNode = FocusNode();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    // Load bill if not already loaded
    final bill = ref.read(currentBillProvider).valueOrNull;
    if (bill == null || bill.id != widget.billId) {
      Future.microtask(
          () => ref.read(currentBillProvider.notifier).loadBill(widget.billId));
    }
  }

  bool get _canAdd => _nameController.text.trim().isNotEmpty && !_adding;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name
        .trim()
        .substring(0, name.trim().length >= 2 ? 2 : 1)
        .toUpperCase();
  }

  Future<void> _addParticipant() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _adding) return;

    setState(() => _adding = true);
    try {
      final billService = ref.read(billServiceProvider);
      await billService.addParticipant(widget.billId, name);
      _nameController.clear();
      await ref.read(currentBillProvider.notifier).refresh();
      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeParticipant(Participant p) async {
    try {
      final billService = ref.read(billServiceProvider);
      await billService.removeParticipant(widget.billId, p.id);
      await ref.read(currentBillProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot remove: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(currentBillProvider);
    final s = ref.watch(l10nProvider);

    return billAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e',
                  style: const TextStyle(color: AppTheme.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref
                    .read(currentBillProvider.notifier)
                    .loadBill(widget.billId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (bill) {
        if (bill == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          );
        }

        final participants = bill.participants;
        final canProceed = participants.length >= 2;
        final totalCount = participants.length;

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
                          s.addParticipants,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      DeleteBillButton(billId: widget.billId),
                    ],
                  ),
                ),

                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Input row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                focusNode: _focusNode,
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) {
                                  if (_canAdd) _addParticipant();
                                },
                                maxLength: 30,
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: s.enterName,
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide:
                                        const BorderSide(color: AppTheme.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide:
                                        const BorderSide(color: AppTheme.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: AppTheme.borderFocus),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _canAdd ? _addParticipant : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: _canAdd
                                      ? AppTheme.accentDim
                                      : AppTheme.surface,
                                  border: Border.all(
                                    color: _canAdd
                                        ? AppTheme.accent
                                        : AppTheme.border,
                                  ),
                                ),
                                child: _adding
                                    ? const Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.accent,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.add_rounded,
                                        size: 22,
                                        color: _canAdd
                                            ? AppTheme.accent
                                            : AppTheme.textMuted,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Section label
                        Row(
                          children: [
                            Text(
                              s.participants,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 7),
                              height: 22,
                              constraints:
                                  const BoxConstraints(minWidth: 22),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                color: canProceed
                                    ? AppTheme.accentDim
                                    : AppTheme.surface,
                                border: Border.all(
                                  color: canProceed
                                      ? AppTheme.accent
                                      : AppTheme.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$totalCount',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: canProceed
                                        ? AppTheme.accent
                                        : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Participants list
                        Expanded(
                          child: ListView(
                            children: [
                              ...participants.map((p) {
                                final isOwner = p.isOwner;
                                return _ParticipantTile(
                                  key: ValueKey(p.id),
                                  initials: isOwner
                                      ? 'Y'
                                      : _getInitials(p.name),
                                  name: isOwner ? s.you : p.name,
                                  tag: isOwner ? s.organizer : null,
                                  isYou: isOwner,
                                  onRemove: isOwner
                                      ? null
                                      : () => _removeParticipant(p),
                                );
                              }),
                              if (participants.length <= 1)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 40),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.person_add_outlined,
                                        size: 40,
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        s.addPersonHint,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          color: AppTheme.textMuted,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
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
                      onPressed: canProceed
                          ? () => context
                              .push('/bills/${widget.billId}/items')
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
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
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
      },
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final String initials;
  final String name;
  final String? tag;
  final bool isYou;
  final VoidCallback? onRemove;

  const _ParticipantTile({
    super.key,
    required this.initials,
    required this.name,
    this.tag,
    this.isYou = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isYou ? AppTheme.accentDim : AppTheme.surface,
              border: Border.all(
                color: isYou
                    ? AppTheme.accent.withValues(alpha: 0.25)
                    : AppTheme.border,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isYou ? AppTheme.accent : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (tag != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    tag!,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

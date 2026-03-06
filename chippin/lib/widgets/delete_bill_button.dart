import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/l10n.dart';
import '../config/theme.dart';
import '../providers/bills_provider.dart';

class DeleteBillButton extends ConsumerStatefulWidget {
  final int billId;
  const DeleteBillButton({super.key, required this.billId});

  @override
  ConsumerState<DeleteBillButton> createState() => _DeleteBillButtonState();
}

class _DeleteBillButtonState extends ConsumerState<DeleteBillButton> {
  bool _deleting = false;

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
                    fontWeight: FontWeight.w700, color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(billsProvider.notifier).deleteBill(widget.billId);
      if (mounted) context.go('/home');
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
    return GestureDetector(
      onTap: _deleting ? null : _confirmDelete,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: _deleting
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.error),
              )
            : const Icon(Icons.delete_outline_rounded,
                color: AppTheme.error, size: 20),
      ),
    );
  }
}

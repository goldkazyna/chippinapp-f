import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/l10n.dart';
import '../config/theme.dart';
import '../models/bill_item.dart';
import '../providers/auth_provider.dart';
import '../providers/current_bill_provider.dart';
import '../widgets/delete_bill_button.dart';

class AddItemsScreen extends ConsumerStatefulWidget {
  final int billId;
  const AddItemsScreen({super.key, required this.billId});

  @override
  ConsumerState<AddItemsScreen> createState() => _AddItemsScreenState();
}

class _AddItemsScreenState extends ConsumerState<AddItemsScreen> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _nameFocus = FocusNode();

  String? _activeMethod;
  int? _editItemId; // id of item being edited
  bool _saving = false;

  // Scan receipt state
  bool _scanning = false;
  String? _scanError;

  // Voice recording state
  AudioRecorder? _audioRecorder;
  bool _recording = false;
  bool _processingVoice = false;
  String? _voiceError;

  @override
  void initState() {
    super.initState();
    final bill = ref.read(currentBillProvider).valueOrNull;
    if (bill == null || bill.id != widget.billId) {
      Future.microtask(
          () => ref.read(currentBillProvider.notifier).loadBill(widget.billId));
    }
  }

  bool get _canAddItem {
    final hasName = _nameController.text.trim().isNotEmpty;
    final price = double.tryParse(_priceController.text) ?? 0;
    final qty = int.tryParse(_qtyController.text) ?? 0;
    return hasName && price > 0 && qty > 0 && !_saving;
  }

  void _toggleMethod(String method) {
    setState(() {
      if (_activeMethod == method) {
        _activeMethod = null;
      } else {
        _activeMethod = method;
        if (method == 'manual') {
          Future.delayed(const Duration(milliseconds: 300), () {
            _nameFocus.requestFocus();
          });
        }
      }
    });
  }

  Future<void> _addOrUpdateItem() async {
    if (!_canAddItem) return;
    final name = _nameController.text.trim();
    final qty = int.tryParse(_qtyController.text) ?? 1;
    final price = double.tryParse(_priceController.text) ?? 0;

    setState(() => _saving = true);
    try {
      final svc = ref.read(billServiceProvider);
      if (_editItemId != null) {
        await svc.updateItem(widget.billId, _editItemId!,
            name: name, quantity: qty, pricePerUnit: price);
        _editItemId = null;
      } else {
        await svc.addItem(widget.billId,
            name: name, quantity: qty, pricePerUnit: price);
      }
      _nameController.clear();
      _qtyController.text = '1';
      _priceController.clear();
      await ref.read(currentBillProvider.notifier).refresh();
      _nameFocus.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startEdit(BillItem item) {
    setState(() {
      _editItemId = item.id;
      _activeMethod = 'manual';
      _nameController.text = item.name;
      _qtyController.text = item.quantity.toString();
      _priceController.text = item.pricePerUnit.toStringAsFixed(2);
    });
    _nameFocus.requestFocus();
  }

  Future<void> _deleteItem(int itemId) async {
    try {
      await ref.read(billServiceProvider).deleteItem(widget.billId, itemId);
      await ref.read(currentBillProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 70);
      if (picked == null) return;

      setState(() {
        _scanning = true;
        _scanError = null;
      });

      final svc = ref.read(billServiceProvider);
      final lang = ref.read(authStateProvider).valueOrNull?.language ?? 'en';
      final items = await svc.scanReceipt(widget.billId, picked.path,
          lang: lang);

      if (!mounted) return;
      if (items.isEmpty) {
        setState(() {
          _scanning = false;
          _scanError = 'empty';
        });
        return;
      }

      // Save scanned items directly
      final itemsToSave = items.map((item) => {
        'name': item['name']?.toString() ?? '',
        'quantity': item['quantity'] is int
            ? item['quantity']
            : int.tryParse(item['quantity'].toString()) ?? 1,
        'price_per_unit': item['price_per_unit'] is num
            ? item['price_per_unit']
            : double.tryParse(item['price_per_unit'].toString()) ?? 0,
      }).toList();
      await svc.addItemsBulk(widget.billId, itemsToSave);
      await ref.read(currentBillProvider.notifier).refresh();

      if (mounted) {
        setState(() {
          _scanning = false;
          _activeMethod = null;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMsg;
        if (e is DioException && e.response != null) {
          errorMsg = '${e.response!.statusCode}: ${e.response!.data}';
        } else {
          errorMsg = e.toString();
        }
        setState(() {
          _scanning = false;
          _scanError = errorMsg;
        });
      }
    }
  }


  Future<void> _startVoiceRecording() async {
    _audioRecorder = AudioRecorder();
    final hasPermission = await _audioRecorder!.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        final s = ref.read(l10nProvider);
        setState(() {
          _voiceError = s.micPermissionRequired;
        });
      }
      await _audioRecorder!.dispose();
      _audioRecorder = null;
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: filePath,
      );

      if (mounted) {
        setState(() {
          _recording = true;
          _voiceError = null;
        });
      }
    } catch (e) {
      await _audioRecorder!.dispose();
      _audioRecorder = null;
      if (mounted) {
        setState(() {
          _voiceError = e.toString();
        });
      }
    }
  }

  Future<void> _stopAndProcessVoice() async {
    if (_audioRecorder == null) return;

    try {
      final path = await _audioRecorder!.stop();
      await _audioRecorder!.dispose();
      _audioRecorder = null;

      if (path == null || !mounted) return;

      setState(() {
        _recording = false;
        _processingVoice = true;
        _voiceError = null;
      });

      final svc = ref.read(billServiceProvider);
      final lang = ref.read(authStateProvider).valueOrNull?.language ?? 'en';
      final items = await svc.parseVoice(widget.billId, path,
          lang: lang);

      if (!mounted) return;
      if (items.isEmpty) {
        setState(() {
          _processingVoice = false;
          _voiceError = 'empty';
        });
        return;
      }

      final itemsToSave = items.map((item) => {
        'name': item['name']?.toString() ?? '',
        'quantity': item['quantity'] is int
            ? item['quantity']
            : int.tryParse(item['quantity'].toString()) ?? 1,
        'price_per_unit': item['price_per_unit'] is num
            ? item['price_per_unit']
            : double.tryParse(item['price_per_unit'].toString()) ?? 0,
      }).toList();
      await svc.addItemsBulk(widget.billId, itemsToSave);
      await ref.read(currentBillProvider.notifier).refresh();

      if (mounted) {
        setState(() {
          _processingVoice = false;
          _activeMethod = null;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMsg;
        if (e is DioException && e.response != null) {
          errorMsg = '${e.response!.statusCode}: ${e.response!.data}';
        } else {
          errorMsg = e.toString();
        }
        setState(() {
          _recording = false;
          _processingVoice = false;
          _voiceError = errorMsg;
        });
      }
    }
  }

  String _formatAmount(double amount) {
    if (amount == amount.truncateToDouble()) {
      return amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    }
    return amount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _audioRecorder?.dispose();
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(currentBillProvider);

    return billAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
      ),
      data: (bill) {
        final s = ref.watch(l10nProvider);
        if (bill == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          );
        }

        final items = bill.items;
        final canProceed = items.isNotEmpty;
        final totalAmount = bill.total;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top nav
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const Icon(Icons.chevron_left_rounded, color: Color(0x99FFFFFF), size: 24),
                        ),
                      ),
                      Expanded(
                        child: Text(s.addItems, textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      ),
                      DeleteBillButton(billId: widget.billId),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: CustomScrollView(
                      slivers: [
                        // Method buttons
                        SliverToBoxAdapter(child: Row(
                          children: [
                            Expanded(child: _MethodButton(icon: Icons.camera_alt_outlined, label: s.scanReceipt, isActive: _activeMethod == 'scan', onTap: () => _toggleMethod('scan'))),
                            const SizedBox(width: 10),
                            Expanded(child: _MethodButton(icon: Icons.edit_outlined, label: s.addManually, isActive: _activeMethod == 'manual', onTap: () => _toggleMethod('manual'))),
                          ],
                        )),
                        const SliverToBoxAdapter(child: SizedBox(height: 20)),

                        if (_activeMethod == 'scan') SliverToBoxAdapter(child: _buildScanOverlay()),
                        if (_activeMethod == 'manual') SliverToBoxAdapter(child: _buildManualForm()),

                        // Section header
                        SliverToBoxAdapter(child: Row(
                          children: [
                            Text(s.items, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7), height: 22,
                              constraints: const BoxConstraints(minWidth: 22),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                color: items.isNotEmpty ? AppTheme.accentDim : AppTheme.surface,
                                border: Border.all(color: items.isNotEmpty ? AppTheme.accent : AppTheme.border),
                              ),
                              child: Center(child: Text('${items.length}', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: items.isNotEmpty ? AppTheme.accent : AppTheme.textMuted))),
                            ),
                          ],
                        )),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),

                        // Items list
                        if (items.isEmpty)
                          SliverFillRemaining(hasScrollBody: false, child: _buildEmptyHint())
                        else
                          SliverList(delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = items[index];
                              return _ItemCard(
                                name: item.name,
                                meta: '${item.quantity} × ${_formatAmount(item.pricePerUnit)} ${bill.currency}',
                                total: '${_formatAmount(item.total)} ${bill.currency}',
                                onEdit: () => _startEdit(item),
                                onDelete: () => _deleteItem(item.id),
                              );
                            },
                            childCount: items.length,
                          )),
                      ],
                    ),
                  ),
                ),

                // Bottom bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(s.total, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                            Text('${_formatAmount(totalAmount)} ${bill.currency}', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w700, color: totalAmount > 0 ? AppTheme.textPrimary : AppTheme.textMuted, letterSpacing: -0.3)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity, height: 56,
                        child: ElevatedButton(
                          onPressed: canProceed ? () => context.push('/bills/${widget.billId}/adjustments') : null,
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

  Widget _buildScanOverlay() {
    final s = ref.watch(l10nProvider);

    // Scan loading state
    if (_scanning) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.accent)),
            const SizedBox(height: 16),
            Text(s.scanningReceipt, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ]),
        ),
      );
    }

    // Voice recording state
    if (_recording) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            const _PulsingMicIcon(),
            const SizedBox(height: 16),
            Text(s.recording, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _stopAndProcessVoice,
                icon: const Icon(Icons.stop_rounded, size: 20),
                label: Text('Stop', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ),
      );
    }

    // Voice processing state
    if (_processingVoice) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.accent)),
            const SizedBox(height: 16),
            Text(s.processingVoice, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ]),
        ),
      );
    }

    // Voice error state
    if (_voiceError != null) {
      final isEmptyResult = _voiceError == 'empty';
      final isMicError = _voiceError == s.micPermissionRequired;
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            Icon(isMicError ? Icons.mic_off_rounded : Icons.error_outline_rounded,
                size: 32, color: AppTheme.error.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(
                isMicError ? s.micPermissionRequired
                    : isEmptyResult ? s.noItemsFromVoice
                    : s.voiceFailed,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
            if (!isEmptyResult && !isMicError) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: SelectableText(_voiceError!, textAlign: TextAlign.left,
                      style: GoogleFonts.manrope(fontSize: 10, color: AppTheme.textMuted, height: 1.4)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _voiceError = null);
                  _startVoiceRecording();
                },
                icon: const Icon(Icons.mic_outlined, size: 16),
                label: Text(s.retry, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, side: const BorderSide(color: AppTheme.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _voiceError = null);
                      _pickAndScan(ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: Text(s.takePhoto, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, side: const BorderSide(color: AppTheme.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _voiceError = null);
                      _pickAndScan(ImageSource.gallery);
                    },
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: Text(s.chooseFromGallery, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, side: const BorderSide(color: AppTheme.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      );
    }

    // Scan error state
    if (_scanError != null) {
      final isEmptyResult = _scanError == 'empty';
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            Icon(Icons.error_outline_rounded, size: 32, color: AppTheme.error.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(isEmptyResult ? s.noItemsRecognized : s.scanFailed,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
            if (!isEmptyResult) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: SelectableText(_scanError!, textAlign: TextAlign.left,
                      style: GoogleFonts.manrope(fontSize: 10, color: AppTheme.textMuted, height: 1.4)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickAndScan(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: Text(s.takePhoto, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, side: const BorderSide(color: AppTheme.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickAndScan(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: Text(s.chooseFromGallery, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, side: const BorderSide(color: AppTheme.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _scanError = null);
                  _startVoiceRecording();
                },
                icon: const Icon(Icons.mic_outlined, size: 16),
                label: Text(s.dictate, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, side: const BorderSide(color: AppTheme.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
        ),
      );
    }

    // Idle state — pick source
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(child: _SquareIconButton(icon: Icons.camera_alt_outlined, onTap: () => _pickAndScan(ImageSource.camera))),
          const SizedBox(width: 10),
          Expanded(child: _SquareIconButton(icon: Icons.photo_library_outlined, onTap: () => _pickAndScan(ImageSource.gallery))),
          const SizedBox(width: 10),
          Expanded(child: _SquareIconButton(icon: Icons.mic_outlined, onTap: _startVoiceRecording)),
        ],
      ),
    );
  }

  Widget _buildManualForm() {
    final s = ref.watch(l10nProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.itemName, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 5),
          TextField(
            controller: _nameController, focusNode: _nameFocus, onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _priceController.text.isEmpty ? FocusScope.of(context).nextFocus() : _addOrUpdateItem(),
            style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
            decoration: _inputDecoration(s.itemNameHint),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.qty, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 5),
              TextField(
                controller: _qtyController, onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                decoration: _inputDecoration(null),
              ),
            ])),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.pricePerUnit, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 5),
              TextField(
                controller: _priceController, onChanged: (_) => setState(() {}), onSubmitted: (_) => _addOrUpdateItem(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                decoration: _inputDecoration('0.00'),
              ),
            ])),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity, height: 44,
            child: ElevatedButton(
              onPressed: _canAddItem ? _addOrUpdateItem : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent, foregroundColor: AppTheme.accentText,
                disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.35),
                disabledForegroundColor: AppTheme.accentText.withValues(alpha: 0.5),
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentText))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(_editItemId != null ? Icons.check_rounded : Icons.add_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(_editItemId != null ? s.update : s.addItem, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                    ]),
            ),
          ),
        ]),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      filled: true, fillColor: const Color(0x08FFFFFF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderFocus)),
    );
  }

  Widget _buildEmptyHint() {
    final s = ref.watch(l10nProvider);
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.description_outlined, size: 40, color: Colors.white.withValues(alpha: 0.18)),
      const SizedBox(height: 12),
      Text(s.noItemsHint, textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 14, color: AppTheme.textMuted, height: 1.5)),
    ]));
  }
}

class _MethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MethodButton({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isActive ? AppTheme.accentDim : AppTheme.surface,
          border: Border.all(color: isActive ? AppTheme.accent : AppTheme.border),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: isActive ? AppTheme.accent : AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500, color: isActive ? AppTheme.accent : AppTheme.textSecondary, letterSpacing: 0.2)),
        ]),
      ),
    );
  }
}

class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon();

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.error.withValues(alpha: _animation.value * 0.3),
          ),
          child: const Icon(Icons.mic_rounded, size: 32, color: AppTheme.error),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  final String name;
  final String meta;
  final String total;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemCard({required this.name, required this.meta, required this.total, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(name, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
          const SizedBox(width: 12),
          GestureDetector(onTap: onEdit, child: Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.textMuted))),
          GestureDetector(onTap: onDelete, child: Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted))),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(meta, style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.textMuted)),
          Text(total, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ]),
      ]),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SquareIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, size: 22, color: AppTheme.textSecondary),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill.dart';
import '../services/bill_service.dart';
import 'auth_provider.dart';

final billServiceProvider = Provider<BillService>((ref) {
  return BillService(ref.watch(apiClientProvider));
});

/// Holds the bill currently being created / edited across the multi-step flow.
final currentBillProvider =
    StateNotifierProvider<CurrentBillNotifier, AsyncValue<Bill?>>((ref) {
  return CurrentBillNotifier(ref.watch(billServiceProvider));
});

class CurrentBillNotifier extends StateNotifier<AsyncValue<Bill?>> {
  final BillService _billService;

  CurrentBillNotifier(this._billService)
      : super(const AsyncValue.data(null));

  /// Create a new bill → store it
  Future<Bill> createBill({
    required String name,
    required String date,
    required String currency,
  }) async {
    state = const AsyncValue.loading();
    final bill = await _billService.createBill(
      name: name,
      date: date,
      currency: currency,
    );
    state = AsyncValue.data(bill);
    return bill;
  }

  /// Load an existing bill by id
  Future<void> loadBill(int id) async {
    state = const AsyncValue.loading();
    try {
      final bill = await _billService.getBill(id);
      state = AsyncValue.data(bill);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Reload the current bill from API
  Future<void> refresh() async {
    final bill = state.valueOrNull;
    if (bill == null) return;
    try {
      final updated = await _billService.getBill(bill.id);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Clear current bill (when flow is complete)
  void clear() {
    state = const AsyncValue.data(null);
  }
}

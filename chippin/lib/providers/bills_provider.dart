import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill.dart';
import '../services/bill_service.dart';
import 'current_bill_provider.dart';

final billsProvider =
    StateNotifierProvider<BillsNotifier, AsyncValue<List<Bill>>>((ref) {
  return BillsNotifier(ref.watch(billServiceProvider));
});

class BillsNotifier extends StateNotifier<AsyncValue<List<Bill>>> {
  final BillService _billService;

  BillsNotifier(this._billService) : super(const AsyncValue.data([]));

  Future<void> loadBills() async {
    state = const AsyncValue.loading();
    try {
      final bills = await _billService.getBills();
      state = AsyncValue.data(bills);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteBill(int id) async {
    await _billService.deleteBill(id);
    await loadBills();
  }
}

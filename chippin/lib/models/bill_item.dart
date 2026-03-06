import '../utils/json_converters.dart';
import 'item_split.dart';

class BillItem {
  final int id;
  final String name;
  final int quantity;
  final double pricePerUnit;
  final double total;
  final List<ItemSplit> splits;

  const BillItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.pricePerUnit,
    required this.total,
    this.splits = const [],
  });

  factory BillItem.fromJson(Map<String, dynamic> json) => BillItem(
        id: json['id'] as int,
        name: json['name'] as String,
        quantity: toInt(json['quantity']),
        pricePerUnit: toDouble(json['price_per_unit']),
        total: toDouble(json['total']),
        splits: (json['splits'] as List<dynamic>?)
                ?.map((e) => ItemSplit.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'price_per_unit': pricePerUnit,
        'total': total,
        'splits': splits.map((s) => s.toJson()).toList(),
      };

  bool get isSplit => splits.isNotEmpty;
}

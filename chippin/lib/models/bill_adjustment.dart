import '../utils/json_converters.dart';

class BillAdjustment {
  final int? id;
  final String type; // tip, service, tax, delivery, discount
  final String calcMode; // percent, fixed
  final double value;
  final double amount;
  final String splitMode; // proportional, equal

  const BillAdjustment({
    this.id,
    required this.type,
    required this.calcMode,
    required this.value,
    this.amount = 0,
    this.splitMode = 'proportional',
  });

  factory BillAdjustment.fromJson(Map<String, dynamic> json) => BillAdjustment(
    id: json['id'] as int?,
    type: json['type'] as String,
    calcMode: json['calc_mode'] as String,
    value: toDouble(json['value']),
    amount: toDouble(json['amount']),
    splitMode: (json['split_mode'] as String?) ?? 'proportional',
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'calc_mode': calcMode,
    'value': value,
    'split_mode': splitMode,
  };

  bool get isDiscount => type == 'discount';
}

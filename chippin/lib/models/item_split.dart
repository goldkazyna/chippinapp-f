import '../utils/json_converters.dart';

class ItemSplit {
  final int id;
  final int participantId;
  final String? participantName;
  final double quantity;
  final double amount;

  const ItemSplit({
    required this.id,
    required this.participantId,
    this.participantName,
    required this.quantity,
    required this.amount,
  });

  factory ItemSplit.fromJson(Map<String, dynamic> json) => ItemSplit(
        id: json['id'] as int,
        participantId: json['participant_id'] as int,
        participantName: json['participant_name'] as String?,
        quantity: toDouble(json['quantity']),
        amount: toDouble(json['amount']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'participant_id': participantId,
        'participant_name': participantName,
        'quantity': quantity,
        'amount': amount,
      };
}

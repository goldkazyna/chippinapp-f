import '../utils/json_converters.dart';
import 'participant.dart';
import 'bill_item.dart';

class Bill {
  final int id;
  final String name;
  final String date; // "2026-02-25"
  final String currency;
  final double total;
  final int? paidByParticipantId;
  final List<Participant> participants;
  final List<BillItem> items;
  // From list endpoint only
  final int? participantsCount;
  final int? itemsCount;
  final String? createdAt;

  const Bill({
    required this.id,
    required this.name,
    required this.date,
    this.currency = 'KZT',
    this.total = 0,
    this.paidByParticipantId,
    this.participants = const [],
    this.items = const [],
    this.participantsCount,
    this.itemsCount,
    this.createdAt,
  });

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: json['id'] as int,
        name: json['name'] as String,
        date: json['date'] as String,
        currency: (json['currency'] as String?) ?? 'KZT',
        total: toDouble(json['total']),
        paidByParticipantId: json['paid_by_participant_id'] as int?,
        participants: (json['participants'] as List<dynamic>?)
                ?.map((e) => Participant.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => BillItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        participantsCount: json['participants_count'] as int?,
        itemsCount: json['items_count'] as int?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date,
        'currency': currency,
        'total': total,
        'paid_by_participant_id': paidByParticipantId,
        'participants': participants.map((p) => p.toJson()).toList(),
        'items': items.map((i) => i.toJson()).toList(),
      };

  /// Helper: get number of people (from detail or list endpoint)
  int get peopleCount =>
      participants.isNotEmpty ? participants.length : (participantsCount ?? 0);

  /// Route to navigate to based on bill completeness
  String get route {
    if (peopleCount == 0) return '/bills/$id/participants';
    if ((itemsCount ?? items.length) == 0 && total == 0) return '/bills/$id/items';
    if (paidByParticipantId == null) return '/bills/$id/paid-by';
    return '/bills/$id/summary';
  }
}

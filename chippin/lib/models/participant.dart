class Participant {
  final int id;
  final String name;
  final bool isOwner;

  const Participant({
    required this.id,
    required this.name,
    this.isOwner = false,
  });

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: json['id'] as int,
        name: json['name'] as String,
        isOwner: json['is_owner'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_owner': isOwner,
      };
}

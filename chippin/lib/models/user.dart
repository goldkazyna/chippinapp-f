class User {
  final int id;
  final String name;
  final String email;
  final String? avatar;
  final String? provider;
  final String defaultCurrency;
  final String language;
  final String? createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.provider,
    this.defaultCurrency = 'KZT',
    this.language = 'en',
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        email: (json['email'] as String?) ?? '',
        avatar: json['avatar'] as String?,
        provider: json['provider'] as String?,
        defaultCurrency: (json['default_currency'] as String?) ?? 'KZT',
        language: (json['language'] as String?) ?? 'en',
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar': avatar,
        'provider': provider,
        'default_currency': defaultCurrency,
        'language': language,
        'created_at': createdAt,
      };

  User copyWith({
    String? name,
    String? email,
    String? avatar,
    String? defaultCurrency,
    String? language,
  }) =>
      User(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        avatar: avatar ?? this.avatar,
        provider: provider,
        defaultCurrency: defaultCurrency ?? this.defaultCurrency,
        language: language ?? this.language,
        createdAt: createdAt,
      );
}

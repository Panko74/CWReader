class Substitution {
  final String from;
  final String to;
  final bool enabled;

  const Substitution({
    required this.from,
    required this.to,
    this.enabled = true,
  });

  Substitution copyWith({String? from, String? to, bool? enabled}) {
    return Substitution(
      from: from ?? this.from,
      to: to ?? this.to,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'enabled': enabled,
      };

  factory Substitution.fromJson(Map<String, dynamic> json) => Substitution(
        from: json['from'] as String,
        to: json['to'] as String,
        enabled: json['enabled'] as bool? ?? true,
      );
}

class RedeemCodeItem {
  final int id;
  final String code;
  final String reward;
  final DateTime expiresAt;
  final bool active;
  final DateTime? createdAt;

  const RedeemCodeItem({
    required this.id,
    required this.code,
    required this.reward,
    required this.expiresAt,
    required this.active,
    this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory RedeemCodeItem.fromJson(Map<String, dynamic> json) {
    return RedeemCodeItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      code: json['code']?.toString() ?? '',
      reward: json['reward']?.toString() ?? '',
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now(),
      active: json['active'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
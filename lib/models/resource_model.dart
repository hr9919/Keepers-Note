class ResourceModel {
  final int id;
  final String name;
  final String iconPath;
  final double x;
  final double y;
  final String category; // Enum 변환 시 예외 방지를 위해 일단 String 권장
  final String? displayInfo; // 백엔드에서 계산해서 보내주는 시간 정보

  ResourceModel({
    required this.id,
    required this.name,
    required this.iconPath,
    required this.x,
    required this.y,
    required this.category,
    this.displayInfo,
  });

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    return ResourceModel(
      id: json['id'],
      name: json['name'],
      // 백엔드 ResourceResponse의 필드명과 똑같이 맞춰야 합니다!
      iconPath: json['iconPath'] ?? '',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      category: json['category'],
      displayInfo: json['displayInfo'],
    );
  }
}
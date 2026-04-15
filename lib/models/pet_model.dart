class Pet {
  final int? id;
  final String name;
  final bool isCat;

  final String? memo;
  final String? color;

  final String? catVariantId;
  final String? dogVariantId;

  final String? imagePath;
  final String? favoriteSnack;

  final Set<String> triedSnacks;
  final int? sortOrder;

  const Pet({
    this.id,
    required this.name,
    required this.isCat,
    this.memo,
    this.color,
    this.catVariantId,
    this.dogVariantId,
    this.imagePath,
    this.favoriteSnack,
    required this.triedSnacks,
    this.sortOrder,
  });

  /// 🔥 JSON 파싱 안정화
  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as int?,
      name: (json['name'] ?? '').toString(),
      isCat: json['isCat'] ?? true,

      memo: json['memo']?.toString(),
      color: json['color']?.toString(),

      catVariantId: json['catVariantId']?.toString(),
      dogVariantId: json['dogVariantId']?.toString(),

      imagePath: json['imagePath']?.toString(),
      favoriteSnack: json['favoriteSnack']?.toString(),

      triedSnacks: (json['triedSnacks'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toSet() ??
          <String>{},

      sortOrder: json['sortOrder'] as int?,
    );
  }

  /// 🔥 서버 전송용
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isCat': isCat,
      'memo': memo,
      'color': color,
      'catVariantId': catVariantId,
      'dogVariantId': dogVariantId,
      'imagePath': imagePath,
      'favoriteSnack': favoriteSnack,
      'triedSnacks': triedSnacks.toList(),
      'sortOrder': sortOrder,
    };
  }

  /// 🔥 immutable 대응 핵심
  Pet copyWith({
    int? id,
    String? name,
    bool? isCat,
    String? memo,
    String? color,
    String? catVariantId,
    String? dogVariantId,
    String? imagePath,
    String? favoriteSnack,
    Set<String>? triedSnacks,
    int? sortOrder,
  }) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      isCat: isCat ?? this.isCat,
      memo: memo ?? this.memo,
      color: color ?? this.color,
      catVariantId: catVariantId ?? this.catVariantId,
      dogVariantId: dogVariantId ?? this.dogVariantId,
      imagePath: imagePath ?? this.imagePath,
      favoriteSnack: favoriteSnack ?? this.favoriteSnack,
      triedSnacks: triedSnacks ?? this.triedSnacks,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class FishItem {
  final String id;
  final String name;
  final String? nameKo;
  final String image;

  const FishItem({
    required this.id,
    required this.name,
    this.nameKo,
    required this.image,
  });

  factory FishItem.fromJson(Map<String, dynamic> json) {
    return FishItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameKo: (json['name_ko'] ?? json['nameKo'])?.toString(),
      image: (json['image'] ?? '').toString(),
    );
  }

  /// 표시용 이름 (한글 우선)
  String get displayName {
    final ko = (nameKo ?? '').trim();
    if (ko.isNotEmpty) return ko;
    return name;
  }
}
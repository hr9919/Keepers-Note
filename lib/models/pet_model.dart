class PetSnackChoice {
  final String sourceType;
  final String itemId;

  const PetSnackChoice({
    required this.sourceType,
    required this.itemId,
  });

  factory PetSnackChoice.fromJson(Map<String, dynamic> json) {
    return PetSnackChoice(
      sourceType: (json['sourceType'] ?? '').toString(),
      itemId: (json['itemId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sourceType': sourceType,
      'itemId': itemId,
    };
  }

  String get key => '$sourceType::$itemId';

  @override
  bool operator ==(Object other) {
    return other is PetSnackChoice &&
        other.sourceType == sourceType &&
        other.itemId == itemId;
  }

  @override
  int get hashCode => Object.hash(sourceType, itemId);
}

class PetSnackOption {
  final String sourceType;
  final String itemId;
  final String nameKo;
  final String imagePath;
  final String category;

  const PetSnackOption({
    required this.sourceType,
    required this.itemId,
    required this.nameKo,
    required this.imagePath,
    required this.category,
  });

  factory PetSnackOption.fromJson(Map<String, dynamic> json) {
    return PetSnackOption(
      sourceType: (json['sourceType'] ?? '').toString(),
      itemId: (json['itemId'] ?? '').toString(),
      nameKo: (json['nameKo'] ?? '').toString(),
      imagePath: (json['imagePath'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
    );
  }

  String get key => '$sourceType::$itemId';
}

class Pet {
  final int? id;
  final String name;
  final bool isCat;

  final String? memo;
  final String? color;

  final String? catVariantId;
  final String? dogVariantId;

  final String? imagePath;

  final Set<PetSnackChoice> favoriteSnacks;
  final Set<PetSnackChoice> dislikedSnacks;
  final Set<PetSnackChoice> triedSnacks;

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
    required this.favoriteSnacks,
    required this.dislikedSnacks,
    required this.triedSnacks,
    this.sortOrder,
  });

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
      favoriteSnacks: ((json['favoriteSnacks'] as List<dynamic>?) ?? const [])
          .map((e) => PetSnackChoice.fromJson(Map<String, dynamic>.from(e)))
          .toSet(),
      dislikedSnacks: ((json['dislikedSnacks'] as List<dynamic>?) ?? const [])
          .map((e) => PetSnackChoice.fromJson(Map<String, dynamic>.from(e)))
          .toSet(),
      triedSnacks: ((json['triedSnacks'] as List<dynamic>?) ?? const [])
          .map((e) => PetSnackChoice.fromJson(Map<String, dynamic>.from(e)))
          .toSet(),
      sortOrder: json['sortOrder'] as int?,
    );
  }

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
      'favoriteSnacks': favoriteSnacks.map((e) => e.toJson()).toList(),
      'dislikedSnacks': dislikedSnacks.map((e) => e.toJson()).toList(),
      'triedSnacks': triedSnacks.map((e) => e.toJson()).toList(),
      'sortOrder': sortOrder,
    };
  }

  Pet copyWith({
    int? id,
    String? name,
    bool? isCat,
    String? memo,
    String? color,
    String? catVariantId,
    String? dogVariantId,
    String? imagePath,
    Set<PetSnackChoice>? favoriteSnacks,
    Set<PetSnackChoice>? dislikedSnacks,
    Set<PetSnackChoice>? triedSnacks,
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
      favoriteSnacks: favoriteSnacks ?? this.favoriteSnacks,
      dislikedSnacks: dislikedSnacks ?? this.dislikedSnacks,
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

  String get displayName {
    final ko = (nameKo ?? '').trim();
    if (ko.isNotEmpty) return ko;
    return name;
  }
}
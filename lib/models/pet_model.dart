class Pet {
  final int? id;
  final String color;
  final String eyeType;
  String name;
  String breed;
  String? imagePath;
  Set<String> triedSnacks;
  String favoriteSnack;
  bool isCat;
  int? sortOrder;

  Pet({
    this.id,
    required this.name,
    required this.breed,
    required this.isCat,
    this.imagePath,
    Set<String>? triedSnacks,
    this.favoriteSnack = "",
    this.sortOrder,
    this.color = '전체',
    this.eyeType = '전체',
  }) : triedSnacks = triedSnacks ?? {};
}

class FishItem {
  final String id;
  final String name;
  final String? nameKo;
  final String image;
  FishItem({required this.id, required this.name, this.nameKo, required this.image});
  factory FishItem.fromJson(Map<String, dynamic> json) {
    return FishItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameKo: (json['name_ko'] ?? json['nameKo'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
    );
  }
}
class ResourceModel {
  final int id;
  final String resourceName;
  final String category;
  final String? description;
  final double x;
  final double y;
  final int voteCount;
  final bool isVerified;
  final bool isFixed;

  ResourceModel({
    required this.id,
    required this.resourceName,
    required this.category,
    this.description,
    required this.x,
    required this.y,
    required this.voteCount,
    required this.isVerified,
    required this.isFixed,
  });

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    const double mapSize = 1024.0;
    double lngVal = (json['lng'] as num).toDouble();
    double xRatio = lngVal / mapSize;

    double latVal = (json['lat'] as num).toDouble();
    double yRatio = 1.0 - ((mapSize + latVal) / mapSize);

    return ResourceModel(
      id: json['id'],
      resourceName: json['resourceName'] ?? json['resource_name'] ?? '',
      category: json['category'] ?? '',
      description: json['description'],
      x: xRatio,
      y: yRatio,
      voteCount: json['voteCount'] ?? json['vote_count'] ?? 0,
      isVerified: json['isVerified'] ?? json['is_verified'] ?? json['verified'] ?? false,
      isFixed: json['isFixed'] ?? json['is_fixed'] ?? json['fixed'] ?? false,
    );
  }

  // 객체 복사 메서드 (copyWith)
  ResourceModel copyWith({
    int? voteCount,
    bool? isVerified,
  }) {
    return ResourceModel(
      id: id,
      resourceName: resourceName,
      category: category,
      description: description,
      x: x,
      y: y,
      voteCount: voteCount ?? this.voteCount,
      isVerified: isVerified ?? this.isVerified,
      isFixed: isFixed,
    );
  }

  // ★ 한글 이름 변환 (자원, 장소, NPC, 동물 포함)
  String get koName {
    switch (resourceName) {
    // 1. 자원류
      case 'gold_bubble': return '골드 버블';
      case 'roaming_oak': return '그 자리 참나무';
      case 'flawless_fluorite': return '완벽한 형광석';
      case 'apple': return '사과';
      case 'blueberry': return '블루베리';
      case 'stone': return '돌';
      case 'orange': return '오렌지';
      case 'raspberry': return '라즈베리';
      case 'big-tree': return '거대 나무';
      case 'black-truffle': return '검은 트러플';
      case 'mousseron': return '양송이버섯';
      case 'oyster-mushroom': return '느타리버섯';
      case 'porcini': return '그물버섯';
      case 'shiitake': return '표고버섯';

    // 2. 장소류 (Locations)
      case 'central-square': return '중앙 광장';
      case 'lighthouse': return '등대';
      case 'ruins': return '유적지';
      case 'onsen': return '온천';
      case 'whale-mountain': return '고래산';

    // 3. NPC류
      case 'bob': return '밥';
      case 'atara': return '아타라';
      case 'collector': return '수집가';
      case 'dorothee': return '도로시';
      case 'massimo': return '마시모';
      case 'mrs-joan': return '조안 여사';
      case 'bailey-j': return '베일리';
      case 'albert-jr': return '알버트 2세';
      case 'ka-ching': return '카칭';
      case 'naniwa': return '나니와';
      case 'andrew': return '앤드류';
      case 'eric': return '에릭';
      case 'vanya': return '반야';
      case 'will': return '윌';
      case 'patti': return '패티';
      case 'vernie': return '버니';
      case 'blanc': return '블랑코';
      case 'annie': return '애니';
      case 'bill': return '빌';
      case 'doris': return '도리스';

    // 4. 동물류 (Animals)
      case 'panda': return '판다';
      case 'capybara': return '카피바라';
      case 'rabbit': return '토끼';
      case 'fox': return '여우';
      case 'otter': return '수달';
      case 'mink': return '페럿(밍크)';
      case 'deer': return '꽃사슴';
      case 'llama': return '알파카';

      default:
        return resourceName.replaceAll('-', ' ');
    }
  }

  // ★ 아이콘 경로 (카테고리별 폴더 분기)
  String get iconPath {
    // 1. NPC인 경우 (assets/images/npcs/)
    if (category == 'npc') {
      return 'assets/images/npcs/$resourceName.png';
    }

    // 2. 동물인 경우 (assets/images/animals/)
    if (category == 'animal') {
      return 'assets/images/animals/$resourceName.png';
    }

    // 3. 주요 장소(Location)인 경우 공통 핀 아이콘 사용
    if (category == 'location') {
      return 'assets/images/resources/location_pin.png';
    }

    // 4. 나머지 자원류 처리
    switch (resourceName) {
      case 'gold_bubble': return 'assets/images/resources/gold_bubbles.png';
      case 'roaming_oak': return 'assets/images/resources/oak.png';
      case 'flawless_fluorite': return 'assets/images/resources/fluorite.png';
      default:
        return 'assets/images/resources/$resourceName.png';
    }
  }
}
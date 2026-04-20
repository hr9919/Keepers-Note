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
  final bool isActive;
  final bool alreadyVoted;

  // 추가
  final bool alreadyVotedSameType;
  final bool votedByMe;

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
    required this.isActive,
    required this.alreadyVoted,
    required this.alreadyVotedSameType,
    required this.votedByMe,
  });

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    const double mapSize = 1024.0;

    final double lngVal = (json['lng'] as num).toDouble();
    final double xRatio = lngVal / mapSize;

    final double latVal = (json['lat'] as num).toDouble();
    final double yRatio = 1.0 - ((mapSize + latVal) / mapSize);

    final bool alreadyVotedSameType =
        json['alreadyVotedSameType'] ??
            json['already_voted_same_type'] ??
            json['alreadyVoted'] ??
            json['already_voted'] ??
            false;

    return ResourceModel(
      id: json['id'],
      resourceName: json['resourceName'] ?? json['resource_name'] ?? '',
      category: json['category'] ?? '',
      description: json['description'],
      x: xRatio,
      y: yRatio,
      voteCount: json['voteCount'] ?? json['vote_count'] ?? 0,
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      isFixed: json['isFixed'] ?? json['is_fixed'] ?? false,
      isActive: json['isActive'] ?? json['is_active'] ?? true,

      // 🔥 핵심 수정
      alreadyVoted: json['alreadyVoted'] ?? false,

      alreadyVotedSameType: alreadyVotedSameType,
      votedByMe: json['votedByMe'] ?? json['voted_by_me'] ?? false,
    );
  }

  ResourceModel copyWith({
    int? voteCount,
    bool? isVerified,
    bool? isFixed,
    bool? isActive,
    bool? alreadyVoted,
    bool? alreadyVotedSameType,
    bool? votedByMe,
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
      isFixed: isFixed ?? this.isFixed,
      isActive: isActive ?? this.isActive,
      alreadyVoted: alreadyVoted ?? this.alreadyVoted,
      alreadyVotedSameType: alreadyVotedSameType ?? this.alreadyVotedSameType,
      votedByMe: votedByMe ?? this.votedByMe,
    );
  }

  String get koName {
    switch (resourceName) {
      case 'gold_bubble':
        return '골드 버블';
      case 'roaming_oak':
        return '그 자리 참나무';
      case 'fluorite':
      case 'flawless_fluorite':
        return '완벽한 형광석';
      case 'apple':
        return '사과';
      case 'blueberry':
        return '블루베리';
      case 'stone':
        return '돌';
      case 'orange':
        return '오렌지';
      case 'raspberry':
        return '라즈베리';
      case 'big-tree':
        return '거대 나무';
      case 'black_truffle':
      case 'black-truffle':
        return '검은 트러플';
      case 'mousseron':
        return '양송이버섯';
      case 'oyster-mushroom':
        return '느타리버섯';
      case 'porcini':
        return '그물버섯';
      case 'shiitake':
        return '표고버섯';

      case 'central-square':
        return '중앙 광장';
      case 'lighthouse':
        return '등대';
      case 'ruins':
        return '유적지';
      case 'onsen':
        return '온천';
      case 'whale-mountain':
        return '고래산';

      case 'bob':
        return '밥';
      case 'atara':
        return '아타라';
      case 'collector':
        return '수집가';
      case 'dorothee':
        return '도로시';
      case 'massimo':
        return '마시모';
      case 'mrs-joan':
        return '조안 여사';
      case 'bailey-j':
        return '베일리';
      case 'albert-jr':
        return '알버트 2세';
      case 'ka-ching':
        return '카칭';
      case 'naniwa':
        return '나니와';
      case 'andrew':
        return '앤드류';
      case 'eric':
        return '에릭';
      case 'vanya':
        return '반야';
      case 'will':
        return '윌';
      case 'patti':
        return '패티';
      case 'vernie':
        return '버니';
      case 'blanc':
        return '블랑코';
      case 'annie':
        return '애니';
      case 'bill':
        return '빌';
      case 'doris':
        return '도리스';

      case 'panda':
        return '판다';
      case 'capybara':
        return '카피바라';
      case 'rabbit':
        return '토끼';
      case 'fox':
        return '여우';
      case 'otter':
        return '수달';
      case 'mink':
        return '페럿(밍크)';
      case 'deer':
        return '꽃사슴';
      case 'llama':
        return '알파카';

      default:
        return resourceName.replaceAll('-', ' ').replaceAll('_', ' ');
    }
  }

  String get iconPath {
    if (category == 'npc') {
      return 'assets/images/npcs/$resourceName.png';
    }

    if (category == 'animal') {
      return 'assets/images/animals/$resourceName.png';
    }

    if (category == 'location') {
      return 'assets/images/resources/location_pin.png';
    }

    switch (resourceName) {
      case 'gold_bubble':
        return 'assets/images/resources/gold_bubbles.png';
      case 'roaming_oak':
        return 'assets/images/resources/roaming-oak.png.png';
      case 'fluorite':
      case 'flawless_fluorite':
        return 'assets/images/resources/fluorite.png';
      case 'black_truffle':
      case 'black-truffle':
        return 'assets/images/resources/black-truffle.png';
      default:
        return 'assets/images/resources/$resourceName.png';
    }
  }
}

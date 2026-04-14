class SpawnResourceModel {
  final int id;
  final String resourceName;
  final String? displayInfo;
  final int voteCount;
  final bool isVerified;
  final bool isFixed;
  final bool isActive;
  final bool alreadyVoted;
  final bool alreadyVotedSameType;
  final bool votedByMe;

  const SpawnResourceModel({
    required this.id,
    required this.resourceName,
    this.displayInfo,
    required this.voteCount,
    required this.isVerified,
    required this.isFixed,
    required this.isActive,
    required this.alreadyVoted,
    required this.alreadyVotedSameType,
    required this.votedByMe,
  });

  factory SpawnResourceModel.fromJson(Map<String, dynamic> json) {
    return SpawnResourceModel(
      id: (json['id'] as num).toInt(),
      resourceName: (json['resourceName'] ?? json['resource_name'] ?? '')
          .toString(),
      displayInfo: json['displayInfo']?.toString(),
      voteCount: ((json['voteCount'] ?? json['vote_count'] ?? 0) as num).toInt(),
      isVerified: (json['isVerified'] ?? json['is_verified'] ?? false) == true,
      isFixed: (json['isFixed'] ?? json['is_fixed'] ?? false) == true,
      isActive: (json['isActive'] ?? json['is_active'] ?? true) == true,
      alreadyVoted:
      (json['alreadyVoted'] ?? json['already_voted'] ?? false) == true,
      alreadyVotedSameType: (json['alreadyVotedSameType'] ??
          json['already_voted_same_type'] ??
          false) ==
          true,
      votedByMe: (json['votedByMe'] ?? json['voted_by_me'] ?? false) == true,
    );
  }

  String get koName {
    switch (resourceName) {
      case 'roaming_oak':
        return '그 자리 참나무';
      case 'fluorite':
      case 'flawless_fluorite':
        return '완벽한 형광석';
      default:
        return resourceName.replaceAll('_', ' ').replaceAll('-', ' ');
    }
  }

  String get iconPath {
    switch (resourceName) {
      case 'roaming_oak':
        return 'assets/images/resources/roaming-oak.png';
      case 'fluorite':
      case 'flawless_fluorite':
        return 'assets/images/resources/fluorite.png';
      default:
        return 'assets/images/resources/$resourceName.png';
    }
  }

  bool get isVoteCompleted => voteCount >= 5 || isFixed || isVerified;
}
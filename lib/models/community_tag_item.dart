class CommunityTagItem {
  final int? id;
  final String tagKey;
  final String tagName;
  final String postType;
  final int sortOrder;

  const CommunityTagItem({
    required this.id,
    required this.tagKey,
    required this.tagName,
    required this.postType,
    required this.sortOrder,
  });

  factory CommunityTagItem.fromJson(Map<String, dynamic> json) {
    return CommunityTagItem(
      id: (json['id'] as num?)?.toInt(),
      tagKey: (json['tagKey'] ?? '').toString(),
      tagName: (json['tagName'] ?? '').toString(),
      postType: (json['postType'] ?? '').toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 9999,
    );
  }
}
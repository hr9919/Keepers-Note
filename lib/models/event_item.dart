class EventItem {
  final int id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String linkUrl;
  final DateTime startAt;
  final DateTime endAt;
  final bool isActive;
  final int sortOrder;

  EventItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.linkUrl,
    required this.startAt,
    required this.endAt,
    required this.isActive,
    required this.sortOrder,
  });

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: json['id'],
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      linkUrl: (json['linkUrl'] ?? '').toString(),
      startAt: DateTime.parse(json['startAt']),
      endAt: DateTime.parse(json['endAt']),
      isActive: json['isActive'] == true,
      sortOrder: json['sortOrder'] ?? 0,
    );
  }
}

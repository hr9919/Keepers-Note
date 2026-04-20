import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/community_tag_item.dart';

class CommunityTagApiService {
  static const String _baseUrl = 'https://api.keepers-note.o-r.kr';

  static Future<List<CommunityTagItem>> fetchActiveTags() async {
    final uri = Uri.parse('$_baseUrl/api/community/tags');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('태그 조회 실패 (${response.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw Exception('태그 응답 형식이 올바르지 않아요.');
    }

    final items = decoded
        .whereType<Map>()
        .map((e) => CommunityTagItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.tagName.trim().isNotEmpty)
        .toList();

    final hasAll = items.any((e) => e.tagName == '전체');
    if (!hasAll) {
      return <CommunityTagItem>[
        const CommunityTagItem(
          id: null,
          tagKey: 'all',
          tagName: '전체',
          postType: 'GENERAL',
          sortOrder: -1,
        ),
        ...items,
      ];
    }

    return items;
  }
}

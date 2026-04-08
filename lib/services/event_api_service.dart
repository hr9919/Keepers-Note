import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/event_item.dart';

class EventApiService {
  static const String _baseUrl = 'http://161.33.30.40:8080/api';

  static Future<List<EventItem>> fetchActiveEvents() async {
    final response = await http.get(Uri.parse('$_baseUrl/events/active'));

    if (response.statusCode != 200) {
      throw Exception('진행 중 이벤트 불러오기 실패: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((e) => EventItem.fromJson(e)).toList();
  }

  static Future<List<EventItem>> fetchAllEvents() async {
    final response = await http.get(Uri.parse('$_baseUrl/events'));

    if (response.statusCode != 200) {
      throw Exception('전체 이벤트 불러오기 실패: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((e) => EventItem.fromJson(e)).toList();
  }

  static Future<void> createEvent({
    required int kakaoId,
    required String title,
    required String subtitle,
    required String imageUrl,
    required String linkUrl,
    required DateTime startAt,
    required DateTime endAt,
    required bool isActive,
    required int sortOrder,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/events'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'kakaoId': kakaoId,
        'title': title.trim(),
        'subtitle': subtitle.trim().isEmpty ? null : subtitle.trim(),
        'imageUrl': imageUrl.trim().isEmpty ? null : imageUrl.trim(),
        'linkUrl': linkUrl.trim().isEmpty ? null : linkUrl.trim(),
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'isActive': isActive,
        'sortOrder': sortOrder,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('이벤트 생성 실패: ${response.statusCode} ${response.body}');
    }
  }

  static Future<void> updateEvent({
    required int eventId,
    required int kakaoId,
    required String title,
    required String subtitle,
    required String imageUrl,
    required String linkUrl,
    required DateTime startAt,
    required DateTime endAt,
    required bool isActive,
    required int sortOrder,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/events/$eventId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'kakaoId': kakaoId,
        'title': title.trim(),
        'subtitle': subtitle.trim().isEmpty ? null : subtitle.trim(),
        'imageUrl': imageUrl.trim().isEmpty ? null : imageUrl.trim(),
        'linkUrl': linkUrl.trim().isEmpty ? null : linkUrl.trim(),
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'isActive': isActive,
        'sortOrder': sortOrder,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('이벤트 수정 실패: ${response.statusCode} ${response.body}');
    }
  }

  static Future<void> deleteEvent({
    required int eventId,
    required int kakaoId,
  }) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/events/$eventId?kakaoId=$kakaoId'),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('이벤트 삭제 실패: ${response.statusCode} ${response.body}');
    }
  }

  static Future<void> toggleEvent({
    required int eventId,
    required int kakaoId,
  }) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/admin/events/$eventId/toggle?kakaoId=$kakaoId'),
    );

    if (response.statusCode != 200) {
      throw Exception('이벤트 토글 실패: ${response.statusCode} ${response.body}');
    }
  }
}
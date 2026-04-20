import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/map_data_response.dart';

class ApiService {
  static const String baseUrl = 'https://api.keepers-note.o-r.kr';

  static Future<MapDataResponse> getResources({String userId = ''}) async {
    try {
      final Uri uri = userId.isEmpty
          ? Uri.parse('$baseUrl/api/map/resources')
          : Uri.parse('$baseUrl/api/map/resources?userId=$userId');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return MapDataResponse.fromJson(body);
      } else {
        throw Exception('서버 응답 에러: ${response.statusCode}');
      }
    } catch (e) {
      print('자원 로딩 중 에러 발생: $e');
      throw Exception('네트워크 에러: $e');
    }
  }

  static Future<http.Response> voteResource({
    required int id,
    required String userId,
  }) async {
    try {
      final Uri uri = Uri.parse('$baseUrl/api/map/vote/$id?userId=$userId');
      return await http.post(uri);
    } catch (e) {
      print('투표 네트워크 에러: $e');
      rethrow;
    }
  }

  static Future<void> createSpawnPoint({
    required double lng,
    required double lat,
    required String resourceType,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.keepers-note.o-r.kr/api/map/spawn-point'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'lng': lng,
        'lat': lat,
        'resourceType': resourceType,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(response.body);
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/map_data_response.dart';

class ApiService {
  static const String baseUrl = 'http://161.33.30.40:8080';

  static Future<MapDataResponse> getResources({String voterId = ''}) async {
    try {
      final Uri uri = voterId.isEmpty
          ? Uri.parse('$baseUrl/api/map/resources')
          : Uri.parse('$baseUrl/api/map/resources?voterId=$voterId');

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
    required String voterId,
  }) async {
    try {
      final Uri uri = Uri.parse('$baseUrl/api/map/vote/$id?voterId=$voterId');
      return await http.post(uri);
    } catch (e) {
      print('투표 네트워크 에러: $e');
      rethrow;
    }
  }
}
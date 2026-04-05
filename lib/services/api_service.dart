import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/resource_model.dart';

class ApiService {
  static const String baseUrl = 'http://161.33.30.40:8080';

  // 1. 지도 자원 목록 가져오기
  // voterId를 같이 보내서 alreadyVoted 값을 받을 수 있게 함
  static Future<List<ResourceModel>> getResources({String voterId = ''}) async {
    try {
      final Uri uri = voterId.isEmpty
          ? Uri.parse('$baseUrl/api/map/resources')
          : Uri.parse('$baseUrl/api/map/resources?voterId=$voterId');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((json) => ResourceModel.fromJson(json)).toList();
      } else {
        throw Exception('서버 응답 에러: ${response.statusCode}');
      }
    } catch (e) {
      print("자원 로딩 중 에러 발생: $e");
      throw Exception('네트워크 에러: $e');
    }
  }

  // 2. 자원 투표하기
  // 현재 백엔드 구조에 맞게 voterId를 쿼리파라미터로 보냄
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
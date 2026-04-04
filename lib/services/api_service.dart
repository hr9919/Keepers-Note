import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/resource_model.dart';

class ApiService {
  // 오라클 서버 IP 주소
  static const String baseUrl = 'http://161.33.30.40:8080';

  // 1. 지도 자원 목록 가져오기
  static Future<List<ResourceModel>> getResources() async {
    try {
      // 주소를 /api/map/resources로 변경 (백엔드 Controller 설정과 일치)
      final response = await http.get(Uri.parse('$baseUrl/api/map/resources'));

      if (response.statusCode == 200) {
        // 한글 깨짐 방지를 위해 utf8.decode 처리
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((json) => ResourceModel.fromJson(json)).toList();
      } else {
        throw Exception('서버 응답 에러: ${response.statusCode}');
      }
    } catch (e) {
      print("자원 로딩 중 에러 발생: $e");
      throw Exception('네트워크 에러: $e');
    }
  }

  // 2. 자원 투표하기 (제보 확인 기능)
  static Future<bool> voteResource(int id) async {
    try {
      // 백엔드의 @PostMapping("/vote/{id}") 호출
      final response = await http.post(Uri.parse('$baseUrl/api/map/vote/$id'));

      if (response.statusCode == 200) {
        return true;
      } else {
        print('투표 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('투표 네트워크 에러: $e');
      return false;
    }
  }
}
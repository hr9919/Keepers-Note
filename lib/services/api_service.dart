import 'dart:convert'; // jsonDecode, utf8를 쓰기 위해 필요
import 'package:http/http.dart' as http; // http를 쓰기 위해 필요
import '../models/resource_model.dart'; // ResourceModel 파일 경로 (내 프로젝트에 맞게 수정)

class ApiService {
  static const String baseUrl = 'http://161.33.30.40:8080';

  static Future<List<ResourceModel>> getResources() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/resources'));

      if (response.statusCode == 200) {
        // utf8와 jsonDecode 에러 해결!
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((json) => ResourceModel.fromJson(json)).toList();
      } else {
        throw Exception('서버 응답 에러: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('네트워크 에러: $e');
    }
  }
}
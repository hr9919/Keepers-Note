import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/redeem_code_item.dart';

class RedeemCodeApiService {
  static const String _baseUrl = 'https://api.keepers-note.o-r.kr/api';

  static Future<List<RedeemCodeItem>> fetchRedeemCodes() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/redeem-codes'),
    );

    if (response.statusCode != 200) {
      throw Exception('리딤코드 목록 불러오기 실패: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data
        .map((e) => RedeemCodeItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<RedeemCodeItem> createRedeemCode({
    required String userId,
    required String code,
    required String reward,
    required DateTime expiresAt,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/redeem-codes'),
      headers: {
        'Content-Type': 'application/json',
        'X-USER-ID': userId,
      },
      body: jsonEncode({
        'code': code,
        'reward': reward,
        'expiresAt': expiresAt.toIso8601String(),
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('리딤코드 등록 실패: ${response.statusCode}');
    }

    return RedeemCodeItem.fromJson(
      Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes))),
    );
  }
}
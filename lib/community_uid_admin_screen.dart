import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CommunityUidAdminScreen extends StatefulWidget {
  final String kakaoId;

  const CommunityUidAdminScreen({
    super.key,
    required this.kakaoId,
  });

  @override
  State<CommunityUidAdminScreen> createState() => _CommunityUidAdminScreenState();
}

class _CommunityUidAdminScreenState extends State<CommunityUidAdminScreen> {
  static const String _baseUrl = 'http://161.33.30.40:8080';

  bool _isLoading = true;
  List<Map<String, dynamic>> _uidItems = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _reportItems = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    setState(() => _isLoading = true);

    try {
      final uidUri = Uri.parse(
          '$_baseUrl/api/community/uid-verification/requests')
          .replace(queryParameters: {
        'kakaoId': widget.kakaoId,
      });

      final reportUri = Uri.parse('$_baseUrl/api/community/reports')
          .replace(queryParameters: {
        'kakaoId': widget.kakaoId,
      });

      final uidResponse = await http.get(uidUri);
      final reportResponse = await http.get(reportUri);

      if (uidResponse.statusCode < 200 || uidResponse.statusCode >= 300) {
        throw Exception('UID 검증 요청 조회 실패');
      }
      if (reportResponse.statusCode < 200 || reportResponse.statusCode >= 300) {
        throw Exception('신고 목록 조회 실패');
      }

      final uidDecoded = jsonDecode(utf8.decode(uidResponse.bodyBytes)) as List<dynamic>;
      final reportDecoded = jsonDecode(utf8.decode(reportResponse.bodyBytes)) as List<dynamic>;

      setState(() {
        _uidItems = uidDecoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _reportItems = reportDecoded.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reviewReport(
      int reportId,
      String action, {
        int suspendDays = 7,
      }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/community/reports/$reportId/action',
    );

    final Map<String, dynamic> body = <String, dynamic>{
      'kakaoId': int.tryParse(widget.kakaoId) ?? 0,
      'action': action,
    };

    if (action == 'SUSPEND_USER') {
      body['suspendDays'] = suspendDays;
    }

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('신고 처리 실패: ${response.body}');
    }

    await _fetchAdminData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UID 검증 관리'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'UID 검증 요청',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (_uidItems.isEmpty)
            _buildEmptyCard('대기 중인 UID 검증 요청이 없어요.')
          else
            ..._uidItems.map((item) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildUidCard(item),
                )),

          const SizedBox(height: 20),

          const Text(
            '신고 관리',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (_reportItems.isEmpty)
            _buildEmptyCard('접수된 신고가 없어요.')
          else
            ..._reportItems.map((item) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildReportCard(item),
                )),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E3DD)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8A94A6),
        ),
      ),
    );
  }

  Widget _buildUidCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E3DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['nickname']?.toString() ?? '사용자',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text('제출 UID: ${item['submittedUid'] ?? '-'}'),
          Text('현재 UID: ${item['gameUid'] ?? '-'}'),
          const SizedBox(height: 10),
          if ((item['screenshotUrl'] ?? '').toString().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                item['screenshotUrl'],
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(
                      height: 180,
                      color: const Color(0xFFF7F1EE),
                      alignment: Alignment.center,
                      child: const Text('이미지 로드 실패'),
                    ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _review(item['requestId'] as int, false), // ❗ 반려
                  child: const Text('반려'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _review(item['requestId'] as int, true), // ❗ 승인
                  child: const Text('승인'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _review(int requestId, bool approve) async {
    final action = approve ? 'approve' : 'reject';  // approve 또는 reject 액션 선택

    final uri = Uri.parse(
      '$_baseUrl/api/community/uid-verification/requests/$requestId/$action',
    ).replace(
      queryParameters: {'kakaoId': widget.kakaoId},
    );

    final response = await http.post(uri);  // 서버에 요청 보내기
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('처리 실패');  // 처리 실패 시 예외 발생
    }

    _fetchAdminData();  // 처리 후 데이터를 다시 불러옵니다.
  }

  Widget _buildReportCard(Map<String, dynamic> item) {
    final TextEditingController suspendController = TextEditingController(
      text: '7',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E3DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['reporterNickname']?.toString() ?? '신고자',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text('게시글 ID: ${item['postId'] ?? '-'}'),
          Text('사유: ${item['reasonCode'] ?? '-'}'),
          if ((item['detailText'] ?? '').toString().trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('상세: ${item['detailText']}'),
            ),
          const SizedBox(height: 6),
          Text('상태: ${item['status'] ?? '-'}'),
          Text('접수일: ${item['createdAt'] ?? '-'}'),
          const SizedBox(height: 12),

          TextField(
            controller: suspendController,
            decoration: InputDecoration(
              labelText: '정지 기간(일)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reviewReport(
                    item['reportId'] as int,
                    'REJECT', // 백엔드에서 INVALIDATE로 만들었으면 여기만 바꾸기
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7B8794),
                    side: const BorderSide(color: Color(0xFFD9E2EC)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('신고 무효'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final suspendDays =
                        int.tryParse(suspendController.text.trim()) ?? 7;
                    _reviewReport(
                      item['reportId'] as int,
                      'SUSPEND_USER',
                      suspendDays: suspendDays,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF8E7C),
                    side: const BorderSide(color: Color(0xFFFFD2C8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('정지'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _reviewReport(
                    item['reportId'] as int,
                    'APPROVE',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8E7C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('승인'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
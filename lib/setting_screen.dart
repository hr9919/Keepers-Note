import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isPushEnabled = true;
  bool _isLoading = true;

  String _displayUid = "UID를 입력해보세요";
  String _nickname = "로그인 중...";

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // --- 사용자 정보 로드 ---
  Future<void> _loadUserInfo() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      User user = await UserApi.instance.me();
      String kakaoNickname = user.kakaoAccount?.profile?.nickname ?? "사용자";

      if (mounted) setState(() => _nickname = kakaoNickname);

      final response = await http.post(
        Uri.parse('http://161.33.30.40:8080/api/user/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"kakaoId": user.id, "nickname": kakaoNickname}),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        String body = response.body;
        if (body != "SUCCESS") {
          final data = jsonDecode(body);
          if (mounted) {
            setState(() {
              _nickname = data['nickname']?.toString() ?? kakaoNickname;
              if (data['gameUid'] != null && data['gameUid'].toString().isNotEmpty) {
                _displayUid = data['gameUid'].toString();
              }
            });
          }
        }
      }
    } catch (e) {
      print("데이터 로드 에러: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- 메일 발송 전용 함수 (버그 리포트용) ---
  Future<void> _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'mintblue1078@gmail.com',
      query: _encodeQueryParameters(<String, String>{
        'subject': '[키퍼노트 버그 리포트] 제보합니다',
        'body': '앱 버전: 1.0.0\n닉네임: $_nickname\nUID: $_displayUid\n내용: \n\n위 내용을 작성해주시면 빠른 확인에 도움이 됩니다! 😊'
      }),
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        // 실제 기기가 아닌 에뮬레이터 등에서 실행 시 예외 처리
        await launchUrl(emailLaunchUri);
      }
    } catch (e) {
      _showSnackBar("메일 앱을 실행할 수 없습니다.");
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
    '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showSnackBar("링크를 열 수 없습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF8E7C),
        ),
      )
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('내 정보'),
              _buildInfoCard(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 15, bottom: 10),
                      child: Row(
                        children: [
                          Text('이름: $_nickname', style: const TextStyle(color: Color(0xFF636363), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'SF Pro')),
                          const Spacer(),
                          GestureDetector(onTap: _showEditNicknameDialog, child: _buildActionIcon('assets/icons/ic_edit.png')),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFEEEEEE), indent: 20, endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 6),
                      child: Row(
                        children: [
                          Text('UID: $_displayUid', style: const TextStyle(color: Color(0xFF636363), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'SF Pro')),
                          const Spacer(),
                          GestureDetector(onTap: () => _copyToClipboard(_displayUid), child: _buildActionIcon('assets/icons/ic_copy.png')),
                          const SizedBox(width: 8),
                          GestureDetector(onTap: _showEditUidDialog, child: _buildActionIcon('assets/icons/ic_edit.png')),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFEEEEEE), indent: 20, endIndent: 20),
                    _buildRowItem(label: '푸시 알림 받기', trailing: _buildCustomSwitch(_isPushEnabled)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('공식 커뮤니티 링크'),
              _buildInfoCard(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _launchURL('https://cafe.naver.com/heartopia'),
                      child: _buildLinkItem('두근두근 타운 네이버 공식 카페', 'assets/icons/ic_naver_cafe.png'),
                    ),
                    const Divider(height: 1, color: Color(0xFFEEEEEE), indent: 20, endIndent: 20),
                    GestureDetector(
                      onTap: () => _launchURL('https://www.youtube.com/@Heartopia-KR'),
                      child: _buildLinkItem('두근두근 타운 한국 공식 유튜브', 'assets/icons/ic_youtube.png'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('이용 안내'),
              _buildInfoCard(
                child: Column(
                  children: [
                    _buildRowItem(label: '앱 버전', trailingText: '1.0.0'),
                    const Divider(height: 1, color: Color(0xFFEEEEEE), indent: 20, endIndent: 20),
                    _buildBugReportRow(),
                    const Divider(height: 1, color: Color(0xFFEEEEEE), indent: 20, endIndent: 20),
                    _buildRowItem(label: '저작권 안내', isTitleOnly: true),
                    _buildCopyrightText(), // ★ 저작권 문구가 들어가는 부분
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --- 위젯 빌더 함수들 ---

  Widget _buildBugReportRow() => GestureDetector(
    onTap: _sendEmail,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const Text('버그 리포트', style: TextStyle(color: Color(0xFF636363), fontSize: 16, fontWeight: FontWeight.w500)),
          const Spacer(),
          Image.asset('assets/icons/ic_mail_send.png', width: 18, height: 18),
          const SizedBox(width: 6),
          const Text('mintblue1078@gmail.com', style: TextStyle(color: Color(0xFFA4A4A4), fontSize: 12)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFA4A4A4))
        ],
      ),
    ),
  );

  Widget _buildCopyrightText() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text(
      '''키퍼노트는 XD와 공식적인 관계가 없는
팬 메이드 비영리 가이드 앱이며, 게임사의 지적 재산권을 존중합니다.

본 앱에 사용된 모든 게임 이미지, 데이터 등의 저작권은
모두 XD Interactive Entertainment Co., Ltd.에 있습니다.

사용된 이미지 및 데이터는 오직 유저 가이드 목적으로만 사용되며,
상업적으로 이용되지 않습니다.''',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFF8C8C8C),
        fontSize: 10,
        fontFamily: 'SF Pro',
        fontWeight: FontWeight.w400,
        height: 1.60,
      ),
    ),
  );

  void _copyToClipboard(String text) {
    if (text == "UID를 입력해보세요" || text.isEmpty) {
      _showSnackBar("먼저 UID를 등록해주세요.");
      return;
    }
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      _showSnackBar("UID가 클립보드에 복사되었습니다.");
    });
  }

  Future<void> _updateNicknameOnServer(String newNickname) async {
    String oldNickname = _nickname;
    if (mounted) setState(() => _nickname = newNickname);
    try {
      User user = await UserApi.instance.me();
      final response = await http.put(
        Uri.parse('http://161.33.30.40:8080/api/user/update-nickname'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"kakaoId": user.id, "nickname": newNickname}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (mounted) {
          try {
            final data = jsonDecode(response.body);
            setState(() => _nickname = data['nickname']?.toString() ?? newNickname);
          } catch (e) {
            setState(() => _nickname = newNickname);
          }
          _showSnackBar("닉네임이 성공적으로 변경되었습니다.");
        }
      } else {
        if (mounted) {
          setState(() => _nickname = oldNickname);
          _showSnackBar("변경 실패: 서버 응답 에러");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _nickname = oldNickname);
        _showSnackBar("네트워크 에러가 발생했습니다.");
      }
    }
  }

  Future<void> _updateUidOnServer(String newUid) async {
    String oldUid = _displayUid;
    if (mounted) setState(() => _displayUid = newUid);
    try {
      User user = await UserApi.instance.me();
      final response = await http.put(
        Uri.parse('http://161.33.30.40:8080/api/user/update-uid'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"kakaoId": user.id, "gameUid": newUid}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (mounted) {
          try {
            final data = jsonDecode(response.body);
            setState(() => _displayUid = data['gameUid']?.toString() ?? newUid);
          } catch (e) {
            setState(() => _displayUid = newUid);
          }
          _showSnackBar("UID가 성공적으로 수정되었습니다.");
        }
      } else {
        if (mounted) {
          setState(() => _displayUid = oldUid);
          _showSnackBar("수정 실패: ${response.body}");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _displayUid = oldUid);
        _showSnackBar("네트워크 연결 확인이 필요합니다.");
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  void _showEditNicknameDialog() {
    final TextEditingController nameController = TextEditingController(text: _nickname);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text("닉네임 수정", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333), fontSize: 18)),
        content: TextField(
          controller: nameController,
          maxLength: 10,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            hintText: "새로운 닉네임 입력",
            counterText: "",
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF8E7C), width: 1.5)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                _updateNicknameOnServer(nameController.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8E7C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text("변경하기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditUidDialog() {
    final TextEditingController uidController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text("UID 등록", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333), fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("소문자와 숫자 조합 7자리", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: uidController,
              maxLength: 7,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                hintText: "예: abc1234",
                counterText: "",
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF8E7C), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final regExp = RegExp(r'^[a-z0-9]{7}$');
              if (regExp.hasMatch(uidController.text)) {
                _updateUidOnServer(uidController.text);
                Navigator.pop(context);
              } else {
                _showSnackBar("7자리 소문자와 숫자를 입력해주세요.");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8E7C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: const Text("저장", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 12), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black)));
  Widget _buildInfoCard({required Widget child}) => Container(width: double.infinity, decoration: ShapeDecoration(color: Colors.white.withOpacity(0.8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), shadows: const [BoxShadow(color: Color(0x0C000000), blurRadius: 4, offset: Offset(4, 4))]), child: child);
  Widget _buildActionIcon(String iconPath) => SizedBox(width: 50, height: 50, child: Image.asset(iconPath, fit: BoxFit.contain));
  Widget _buildRowItem({required String label, String? trailingText, Widget? trailing, bool isTitleOnly = false}) => Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), child: Row(children: [Text(label, style: const TextStyle(color: Color(0xFF636363), fontSize: 16, fontWeight: FontWeight.w500)), const Spacer(), if (!isTitleOnly && trailingText != null) Text(trailingText, style: const TextStyle(color: Color(0xFFA4A4A4), fontSize: 16)), if (!isTitleOnly && trailing != null) trailing]));
  Widget _buildLinkItem(String title, String imagePath) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [SizedBox(width: 50, height: 40, child: Image.asset(imagePath, fit: BoxFit.contain)), const SizedBox(width: 12), Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF636363), fontSize: 16, fontWeight: FontWeight.w500))), const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFA4A4A4))]));
  Widget _buildCustomSwitch(bool isActive) => GestureDetector(onTap: () => setState(() => _isPushEnabled = !_isPushEnabled), child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 53, height: 30, decoration: BoxDecoration(color: isActive ? const Color(0xFFFF8E7C).withOpacity(0.56) : const Color(0xFFD9D9D9), borderRadius: BorderRadius.circular(99)), child: AnimatedAlign(duration: const Duration(milliseconds: 200), alignment: isActive ? Alignment.centerRight : Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2.5), child: Container(width: 25, height: 25, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))))));
  PreferredSizeWidget _buildAppBar(BuildContext context) => AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20), onPressed: () => Navigator.pop(context)), title: const Text('설정', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)), centerTitle: true, bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Divider(height: 1, color: Colors.black.withOpacity(0.16))));
}
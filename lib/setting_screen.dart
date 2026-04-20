import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'main.dart';
import 'package:path_provider/path_provider.dart';
import 'image_adjust_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 테마 설정
  final Color snackAccent = const Color(0xFFFF8E7C);
  final Color snackBg = const Color(0xFFFFF9F8);
  final Color snackCard = Colors.white;

  String _serverUserId = "";

  bool _uidLocked = false;

  bool _isPushEnabled = true;
  bool _isLoading = false;      // 이미지 업로드 등 액션 시 로딩
  bool _isDataStable = false;   // 데이터 준비 완료 여부 (애니메이션 트리거)
  bool _didUserInfoChange = false;

  String _displayUid = "UID를 입력해보세요";
  String _nickname = "";
  String? _profileImageUrl;
  String? _headerImageUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _recoverLostData();
  }

  Future<void> _recoverLostData() async {
    try {
      if (!mounted) return;

      // iOS에서 미구현 예외가 나는 경우가 있어 우선 무시
      final response = await _picker.retrieveLostData();

      if (response.isEmpty) return;

      final XFile? file = response.file;
      if (file == null) return;

      debugPrint('복구된 이미지: ${file.path}');
    } catch (e) {
      debugPrint('lostData 복구 스킵: $e');
    }
  }

  // 1. 데이터 로딩 로직 (깜빡임 방지 핵심)
  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null || userId.isEmpty) {
        throw Exception('userId 없음');
      }

      final response = await http.get(
        Uri.parse('https://api.keepers-note.o-r.kr/api/user/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        setState(() {
          _serverUserId = userId;
          _nickname = data['nickname'] ?? '';
          _displayUid = data['gameUid'] ?? "UID를 입력해보세요";
          _profileImageUrl = data['profileImageUrl'];
          _headerImageUrl = data['headerImageUrl'];
          _isDataStable = true;
        });
      }
    } catch (e) {
      debugPrint("User load error: $e");
      setState(() => _isDataStable = true);
    }
  }

  // 2. 이미지 업로드 로직
  Future<void> _pickAndUploadImage(bool isProfile) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
    );
    if (image == null) return;

    final ImageAdjustResult? adjusted = await Navigator.push<ImageAdjustResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageAdjustScreen(
          imagePath: image.path,
          title: isProfile ? '프로필 사진 조정' : '배경 사진 조정',
          shape: isProfile
              ? ImageAdjustShape.circle
              : ImageAdjustShape.roundedRect,
          viewportAspectRatio: isProfile ? 1.0 : (16 / 9),
        ),
      ),
    );

    if (adjusted == null) return;

    try {
      setState(() => _isLoading = true);

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/${isProfile ? 'profile' : 'header'}_${DateTime.now().millisecondsSinceEpoch}.${adjusted.extension}';
      final file = File(filePath);
      await file.writeAsBytes(adjusted.bytes);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.keepers-note.o-r.kr/api/user/upload-image'),
      );

      request.fields['userId'] = _serverUserId;
      request.fields['type'] = isProfile ? "PROFILE" : "HEADER";
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType('image', adjusted.extension == 'png' ? 'png' : 'jpeg'),
        ),
      );

      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          final newUrl =
              "https://api.keepers-note.o-r.kr${data['url']}?t=${DateTime.now().millisecondsSinceEpoch}";
          if (isProfile) {
            _profileImageUrl = newUrl;
          } else {
            _headerImageUrl = newUrl;
          }
          _didUserInfoChange = true;
        });
        _showSnackBar("이미지가 변경되었습니다! ✨");
      }
    } catch (e) {
      _showSnackBar("업로드 중 오류 발생");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  // --- UI 빌더 파트 ---

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _didUserInfoChange);
      },
      child: Scaffold(
        backgroundColor: snackBg,
        appBar: _buildSnackAppBar(context),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadUserInfo, // ⭐ 핵심
              color: snackAccent,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  children: [
                    _buildModernHeader(),
                    Transform.translate(
                      offset: const Offset(0, -45),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 600),
                          opacity: _isDataStable ? 1.0 : 0.0,
                          curve: Curves.easeIn,
                          child: Column(
                            children: [
                              _buildProfileMainCard(),
                              const SizedBox(height: 24),
                              _buildSnackSection('공식 커뮤니티', [
                                _buildSnackLinkItem('네이버 공식 카페', 'assets/icons/ic_naver_cafe.png', 'https://cafe.naver.com/heartopia'),
                                _buildSnackLinkItem('한국 공식 유튜브', 'assets/icons/ic_youtube.png', 'https://www.youtube.com/@Heartopia-KR'),
                              ]),
                              const SizedBox(height: 20),
                              _buildSnackSection('이용 안내', [
                                _buildSnackRowItem('앱 버전', trailingText: '1.0.0'),
                                _buildSnackRowItem('버그 리포트 보내기', isLink: true, onTap: _sendEmail),
                                _buildSnackRowItem('저작권 및 법적 고지', isLink: true, onTap: _showCopyrightDialog),
                              ]),
                              const SizedBox(height: 24),
                              _buildWithdrawLink(),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  // 상단 헤더 (배경 사진)
  Widget _buildModernHeader() {
    return GestureDetector(
      onTap: () => _pickAndUploadImage(false),
      child: Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          image: DecorationImage(
            image: _headerImageUrl != null
                ? NetworkImage(_headerImageUrl!)
                : const AssetImage('assets/images/profile_header.png') as ImageProvider,
            fit: BoxFit.cover,
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.15), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }

  // 메인 프로필 카드
  Widget _buildProfileMainCard() {
    return Container(
      decoration: BoxDecoration(
        color: snackCard,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: snackAccent.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
            child: Column(
              children: [
                Text(
                  _nickname,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),
                _buildUidCapsule(),
                const SizedBox(height: 12),
                Text(
                  _uidLocked
                      ? '커뮤니티 인증이 완료되어 UID가 잠겨 있어요'
                      : _displayUid != "UID를 입력해보세요"
                      ? '멋진 타운키퍼가 되고 계신가요?'
                      : '프로필 사진과 UID를 등록해보세요.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9AA4B2),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(
                  color: Color(0xFFF1F2F6),
                  thickness: 1.2,
                ),
                _buildSnackRowItem(
                  '푸시 알림 설정',
                  trailing: _buildCustomSwitch(_isPushEnabled),
                ),
              ],
            ),
          ),

          Positioned(
            top: -50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _pickAndUploadImage(true),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    image: DecorationImage(
                      image: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : const AssetImage('assets/images/profile_image.png')
                      as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 14,
            right: 14,
            child: IconButton(
              onPressed: _showIntegratedEditDialog,
              icon: Icon(
                Icons.edit_note_rounded,
                color: snackAccent,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUidCapsule() {
    final bool hasUid =
        _displayUid.isNotEmpty && _displayUid != "UID를 입력해보세요";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: hasUid ? () => _copyToClipboard(_displayUid) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: hasUid
                ? snackAccent.withOpacity(0.10)
                : const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: hasUid
                  ? snackAccent.withOpacity(0.22)
                  : const Color(0xFFE9EDF2),
            ),
            boxShadow: hasUid
                ? [
              BoxShadow(
                color: snackAccent.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasUid ? Icons.badge_rounded : Icons.schedule_rounded,
                size: 15,
                color: hasUid ? snackAccent : const Color(0xFFB8C0CC),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  hasUid ? _displayUid : "UID를 입력해보세요",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hasUid ? snackAccent : const Color(0xFF9AA4B2),
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (hasUid) ...[
                const SizedBox(width: 8),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: snackAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.content_copy_rounded,
                    size: 12,
                    color: snackAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 섹션 빌더
  Widget _buildSnackSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 10),
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF636E72))),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  // 공통 로우 아이템
  Widget _buildSnackRowItem(String label, {String? trailingText, Widget? trailing, bool isLink = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
            const Spacer(),
            if (trailingText != null) Text(trailingText, style: const TextStyle(fontSize: 15, color: Color(0xFFB2BEC3), fontWeight: FontWeight.w500)),
            if (trailing != null) trailing,
            if (isLink) const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFD1D1D6)),
          ],
        ),
      ),
    );
  }

  Widget _buildSnackLinkItem(String title, String iconPath, String url) {
    return InkWell(
      onTap: () => _launchURL(url),
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Image.asset(iconPath, width: 32, height: 32),
            const SizedBox(width: 14),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFD1D1D6)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSnackAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D3436), size: 20),
        onPressed: () => Navigator.pop(context, _didUserInfoChange),
      ),
      title: const Text('설정', style: TextStyle(color: Color(0xFF2D3436), fontSize: 18, fontWeight: FontWeight.w900)),
      centerTitle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
    );
  }

  Widget _buildCustomSwitch(bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _isPushEnabled = !_isPushEnabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 54,
        height: 30,
        decoration: BoxDecoration(
          color: isActive ? snackAccent.withOpacity(0.6) : const Color(0xFFDFE6E9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.12),
      child: Center(child: CircularProgressIndicator(color: snackAccent)),
    );
  }

  // --- 유틸리티 및 다이얼로그 ---
  void _showIntegratedEditDialog() {
    final nameController = TextEditingController(text: _nickname);
    final uidController = TextEditingController(
      text: _displayUid == "UID를 입력해보세요" ? "" : _displayUid,
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: snackAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: snackAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '프로필 정보 수정',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D3436),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '닉네임과 UID를 한 번에 수정할 수 있어요',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9AA4B2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(dialogContext),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              _buildDialogField(
                '닉네임',
                nameController,
                10,
                '인게임 닉네임 입력',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 14),
              _buildDialogField(
                'UID',
                uidController,
                10,
                _uidLocked ? '승인된 UID는 변경할 수 없어요' : '소문자와 숫자 조합',
                icon: Icons.badge_rounded,
                helperText: _uidLocked
                    ? '커뮤니티 인증이 완료되어 UID 변경이 잠겨 있어요.'
                    : '예: abc123456',
                enabled: !_uidLocked,
              ),

              const SizedBox(height: 22),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: snackAccent.withOpacity(0.14),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: snackAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _uidLocked
                            ? '커뮤니티 인증이 완료된 UID라서 지금은 변경할 수 없어요.'
                            : 'UID는 비워두면 변경하지 않고, 입력하면 기존 UID를 새 값으로 바꿔요.',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7C8796),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        foregroundColor: const Color(0xFF636E72),
                        backgroundColor: const Color(0xFFF8FAFC),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        final uid = uidController.text.trim();

                        if (!_uidLocked &&
                            uid.isNotEmpty &&
                            !RegExp(r'^[a-z0-9]{1,10}$').hasMatch(uid)) {
                          _showSnackBar("UID 형식을 확인해주세요.");
                          return;
                        }

                        Navigator.pop(dialogContext);
                        _updateUserInfoOnServer(name, _uidLocked ? '' : uid);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: snackAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '저장',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogField(
      String label,
      TextEditingController controller,
      int max,
      String hint, {
        IconData? icon,
        String? helperText,
        bool enabled = true,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: snackAccent,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF636E72),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: snackBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFF0E6E3),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLength: max,
            enabled: enabled,
            cursorColor: snackAccent,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? const Color(0xFF2D3436)
                  : const Color(0xFF9AA4B2),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFFB5BDC8),
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: Colors.transparent,
              counterText: "",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: snackAccent.withOpacity(0.35),
                  width: 1.4,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9AA4B2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _updateUserInfoOnServer(String name, String uid) async {
    try {
      setState(() => _isLoading = true);

      if (name.isNotEmpty) {
        await http.put(
          Uri.parse('https://api.keepers-note.o-r.kr/api/user/update-nickname'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "id": int.tryParse(_serverUserId),
            "nickname": name,
          }),
        );
      }

      if (uid.isNotEmpty && !_uidLocked) {
        await http.put(
          Uri.parse('https://api.keepers-note.o-r.kr/api/user/update-uid'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "id": int.tryParse(_serverUserId),
            "gameUid": uid,
          }),
        );
      }

      await _loadUserInfo();
      _didUserInfoChange = true;
      _showSnackBar("성공적으로 수정되었습니다! ✨");
    } catch (e) {
      _showSnackBar("수정 실패");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCopyrightDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '저작권 안내',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2D3436)),
              ),
              const SizedBox(height: 16),
              // 긴 텍스트를 스크롤 가능하게 하고 줄바꿈을 자연스럽게 유도
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    '키퍼노트는 XD와 공식적인 관계가 없는 팬 메이드 비영리 가이드 앱이며, 게임사의 지적 재산권을 존중합니다.\n\n'
                        '본 앱에 사용된 모든 게임 이미지, 데이터 등의 저작권은 모두 XD Interactive Entertainment Co., Ltd.에 있습니다.\n\n'
                        '사용된 이미지 및 데이터는 오직 유저 가이드 목적으로만 사용되며, 상업적으로 절대 이용되지 않습니다.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: const Color(0xFF636E72), // 눈이 편안한 다크 그레이
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: snackAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'mintblue1078@gmail.com',
      query: 'subject=[키퍼노트 버그 리포트]&body=닉네임: $_nickname\nUID: $_displayUid\n내용:',
    );
    if (await canLaunchUrl(emailLaunchUri)) await launchUrl(emailLaunchUri);
  }

  Future<void> _launchURL(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) _showSnackBar("링크 열기 실패");
  }

  Widget _buildWithdrawLink() {
    return Center(
      child: GestureDetector(
        onTap: _showWithdrawDialog,
        child: const Text(
          '회원탈퇴',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFFB0B8C1),
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Future<void> _showWithdrawDialog() async {
    final String nicknameText =
    _nickname.trim().isNotEmpty ? _nickname.trim() : '이 계정';

    final String uidText =
    (_displayUid.trim().isNotEmpty && _displayUid != 'UID를 입력해보세요')
        ? _displayUid.trim()
        : '미설정';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_remove_alt_1_rounded,
                  color: Color(0xFFE88778),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '회원탈퇴',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D3436),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '현재 로그인된 계정을 탈퇴합니다.\n아래 계정 정보를 꼭 확인해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9AA4B2),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBFA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: snackAccent.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  children: [
                    _buildWithdrawAccountInfoRow(
                      label: '닉네임',
                      value: nicknameText,
                    ),
                    const SizedBox(height: 10),
                    _buildWithdrawAccountInfoRow(
                      label: '게임 UID',
                      value: uidText,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: snackAccent.withValues(alpha: 0.14),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WithdrawGuideRow(
                      text: '로그인 연결이 해제되고 현재 로그인 상태가 종료돼요.',
                    ),
                    SizedBox(height: 10),
                    _WithdrawGuideRow(
                      text: '계정 정보와 개인 설정, 반려동물, 할 일 목록이 함께 삭제돼요.',
                    ),
                    SizedBox(height: 10),
                    _WithdrawGuideRow(
                      text: '작성한 게시글, 댓글, 좋아요, 팔로우 등 커뮤니티 활동도 함께 정리돼요.',
                    ),
                    SizedBox(height: 10),
                    _WithdrawGuideRow(
                      text: '탈퇴 후 다시 로그인하면 처음부터 새로 시작하게 돼요.',
                    ),
                    SizedBox(height: 10),
                    _WithdrawGuideRow(
                      text: '삭제된 정보는 복구할 수 없어요.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '위 계정이 맞다면 탈퇴를 진행해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF636E72),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        foregroundColor: const Color(0xFF636E72),
                        backgroundColor: const Color(0xFFF8FAFC),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await _withdrawAccount();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE88778),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '탈퇴하기',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWithdrawAccountInfoRow({
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3F0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE88778),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 13.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3436),
                ),
          ),
        ),
      ],
    );
  }

  Future<void> _withdrawAccount() async {
    try {
      setState(() => _isLoading = true);

      if (_serverUserId.isEmpty) {
        _showSnackBar('사용자 정보를 아직 불러오지 못했어요.');
        return;
      }

      final response = await http.delete(
        Uri.parse('https://api.keepers-note.o-r.kr/api/user/withdraw')
            .replace(queryParameters: {'userId': _serverUserId}),
      );

      if (response.statusCode == 200) {
        // ✅ userId 삭제
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('userId');

        // ✅ 소셜 토큰 정리 (공통)
        try {
          await TokenManagerProvider.instance.manager.clear();
        } catch (_) {}

        if (!mounted) return;

        _showSnackBar('회원탈퇴가 완료되었어요.');

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
              (route) => false,
        );
      } else {
        _showSnackBar('회원탈퇴에 실패했어요.');
      }
    } catch (e) {
      _showSnackBar('회원탈퇴 중 오류가 발생했어요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text) {
    if (text == "UID를 입력해보세요") return;
    Clipboard.setData(ClipboardData(text: text)).then((_) => _showSnackBar("UID가 복사되었습니다."));
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }
}

class _WithdrawGuideRow extends StatelessWidget {
  final String text;

  const _WithdrawGuideRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_rounded,
            size: 15,
            color: Color(0xFFE88778),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.55,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7C8796),
            ),
          ),
        ),
      ],
    );
  }
}

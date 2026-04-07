import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isPushEnabled = true;
  bool _isLoading = true;
  bool _didUserInfoChange = false;

  String _userUid = "";
  String _displayUid = "UID를 입력해보세요";
  String _nickname = "로그인 중...";
  String? _profileImageUrl;
  String? _headerImageUrl;

  final ImagePicker _picker = ImagePicker();

  static const double _infoRowHeight = 60;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      // 1. 서버 통신 전에 로컬(카카오 SDK) 정보를 즉시 가져와서 화면에 먼저 띄웁니다.
      // 여기서 _isLoading을 true로 만들지 않아야 화면이 바로 뜹니다!
      User user = await UserApi.instance.me();
      String kakaoNickname = user.kakaoAccount?.profile?.nickname ?? "사용자";

      if (mounted) {
        setState(() {
          _nickname = kakaoNickname;
          _userUid = user.id.toString();
          // 로딩바를 끄고 로컬 정보를 먼저 보여줍니다. (광속 전환!)
          _isLoading = false;
        });
      }

      // 2. 이제 백그라운드에서 서버 데이터를 요청합니다.
      // 사용자는 이미 화면을 보고 있는 상태입니다.
      final response = await http
          .post(
        Uri.parse('http://161.33.30.40:8080/api/user/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"kakaoId": user.id, "nickname": kakaoNickname}),
      )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            // 서버에서 받아온 상세 정보(진짜 닉네임, UID, 이미지 등)로 슬쩍 업데이트합니다.
            _nickname = data['nickname']?.toString() ?? kakaoNickname;

            if (data['gameUid'] != null && data['gameUid'].toString().isNotEmpty) {
              _displayUid = data['gameUid'].toString();
            }

            if (data['profileImageUrl'] != null) {
              // 캐시 방지를 위해 타임스탬프를 살짝 붙여주는 센스!
              _profileImageUrl = "http://161.33.30.40:8080${data['profileImageUrl']}?t=${DateTime.now().millisecondsSinceEpoch}";
            }

            if (data['headerImageUrl'] != null) {
              _headerImageUrl = "http://161.33.30.40:8080${data['headerImageUrl']}?t=${DateTime.now().millisecondsSinceEpoch}";
            }
          });
        }
      }
    } catch (e) {
      debugPrint("서버 응답 지연 또는 에러(로컬 데이터 유지됨): $e");
    } finally {
      // 혹시 모를 로딩 상태를 확실히 종료합니다.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _goBackToHome() async {
    if (!mounted) return false;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
      return false;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
          (route) => false,
    );
    return false;
  }

  Future<void> _pickAndUploadImage(bool isProfile) async {
    final XFile? image =
    await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2048);

    if (image == null) return;

    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: isProfile ? '프로필 사진 편집' : '배경 사진 편집',
          toolbarColor: const Color(0xFFFF8E7C),
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: const Color(0xFFFF8E7C),
          lockAspectRatio: false,
          hideBottomControls: false,
          initAspectRatio: isProfile
              ? CropAspectRatioPreset.square
              : CropAspectRatioPreset.ratio16x9,
          aspectRatioPresets: isProfile
              ? [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.original,
          ]
              : [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio4x3,
          ],
        ),
        IOSUiSettings(
          title: isProfile ? '프로필 사진 편집' : '배경 사진 편집',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
          rotateButtonsHidden: false,
          rotateClockwiseButtonHidden: false,
          aspectRatioPickerButtonHidden: false,
          aspectRatioPresets: isProfile
              ? [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.original,
          ]
              : [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio4x3,
          ],
        ),
      ],
    );

    if (croppedFile == null) return;

    try {
      if (mounted) setState(() => _isLoading = true);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://161.33.30.40:8080/api/user/upload-image'),
      );

      request.fields['kakaoId'] = _userUid;
      request.fields['type'] = isProfile ? "PROFILE" : "HEADER";
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          croppedFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newUrl =
            "http://161.33.30.40:8080${data['url']}?t=${DateTime.now().millisecondsSinceEpoch}";

        setState(() {
          if (isProfile) {
            _profileImageUrl = newUrl;
          } else {
            _headerImageUrl = newUrl;
          }
          _didUserInfoChange = true;
        });

        _showSnackBar("이미지가 변경되었습니다! ✨");
      } else {
        _showSnackBar("업로드 실패");
      }
    } catch (e) {
      _showSnackBar("업로드 중 오류 발생");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'mintblue1078@gmail.com',
      query: _encodeQueryParameters(<String, String>{
        'subject': '[키퍼노트 버그 리포트] 제보합니다',
        'body':
        '앱 버전: 1.0.0\n닉네임: $_nickname\nUID: $_displayUid\n내용: \n\n위 내용을 작성해주시면 빠른 확인에 도움이 됩니다! 😊'
      }),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      _showSnackBar("메일 앱을 실행할 수 없습니다.");
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
      '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
    )
        .join('&');
  }

  Future<void> _launchURL(String urlString) async {
    if (!await launchUrl(
      Uri.parse(urlString),
      mode: LaunchMode.externalApplication,
    )) {
      _showSnackBar("링크 열기 실패");
    }
  }

  void _copyToClipboard(String text) {
    if (text == "UID를 입력해보세요" || text.isEmpty) {
      _showSnackBar("먼저 UID를 등록해주세요.");
      return;
    }

    Clipboard.setData(ClipboardData(text: text))
        .then((_) => _showSnackBar("UID가 복사되었습니다."));
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  InputDecoration _dialogInputDecoration({
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      counterText: "",
      filled: true,
      fillColor: const Color(0xFFF6F7F9),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFFF8E7C),
          width: 1.4,
        ),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFFB0B0B0),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _didUserInfoChange);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        appBar: _buildAppBar(context),
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    children: [
                      _buildProfileHeaderBackgroundSection(),
                      Transform.translate(
                        offset: const Offset(0, -60),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoCard(
                                child: Stack(
                                  children: [
                                    Column(
                                      children: [
                                        const SizedBox(height: 28),
                                        _buildInfoRow(
                                          label: '이름',
                                          value: _nickname,
                                        ),
                                        const Divider(
                                          height: 1,
                                          color: Color(0xFFEEEEEE),
                                          indent: 20,
                                          endIndent: 20,
                                        ),
                                        _buildUidRow(),
                                        const Divider(
                                          height: 1,
                                          color: Color(0xFFEEEEEE),
                                          indent: 20,
                                          endIndent: 20,
                                        ),
                                        _buildRowItem(
                                          label: '푸시 알림 받기',
                                          trailing: _buildCustomSwitch(_isPushEnabled),
                                        ),
                                      ],
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: _showIntegratedEditDialog,
                                        child: _buildIconButton(
                                          'assets/icons/ic_edit.png',
                                        ),
                                      ),
                                    ),
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
                                      child: _buildLinkItem(
                                        '두근두근 타운 네이버 공식 카페',
                                        'assets/icons/ic_naver_cafe.png',
                                      ),
                                    ),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFEEEEEE),
                                      indent: 20,
                                      endIndent: 20,
                                    ),
                                    GestureDetector(
                                      onTap: () => _launchURL('https://www.youtube.com/@Heartopia-KR'),
                                      child: _buildLinkItem(
                                        '두근두근 타운 한국 공식 유튜브',
                                        'assets/icons/ic_youtube.png',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildSectionTitle('이용 안내'),
                              _buildInfoCard(
                                child: Column(
                                  children: [
                                    _buildRowItem(
                                      label: '앱 버전',
                                      trailingText: '1.0.0',
                                    ),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFEEEEEE),
                                      indent: 20,
                                      endIndent: 20,
                                    ),
                                    _buildBugReportRow(),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFEEEEEE),
                                      indent: 20,
                                      endIndent: 20,
                                    ),
                                    _buildRowItem(
                                      label: '저작권 안내',
                                      isTitleOnly: true,
                                    ),
                                    _buildCopyrightText(),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 50),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 160,
                    left: 32,
                    child: GestureDetector(
                      onTap: () => _pickAndUploadImage(true),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          image: DecorationImage(
                            image: _profileImageUrl != null
                                ? NetworkImage(_profileImageUrl!)
                                : const AssetImage('assets/images/profile.png') as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.white.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF8E7C),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderBackgroundSection() {
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _pickAndUploadImage(false),
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                image: DecorationImage(
                  image: _headerImageUrl != null
                      ? NetworkImage(_headerImageUrl!)
                      : const AssetImage('assets/images/profile_header_bg.png')
                  as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required String label, required String value}) {
    return SizedBox(
      height: _infoRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$label: $value',
              style: const TextStyle(
                color: Color(0xFF636363),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildUidRow() =>
      SizedBox(
        height: _infoRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'UID: $_displayUid',
                style: const TextStyle(
                  color: Color(0xFF636363),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      );

  Widget _buildBugReportRow() =>
      GestureDetector(
        onTap: _sendEmail,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Text(
                '버그 리포트',
                style: TextStyle(
                  color: Color(0xFF636363),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Image.asset(
                'assets/icons/ic_mail_send.png',
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'mintblue1078@gmail.com',
                style: TextStyle(
                  color: Color(0xFFA4A4A4),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xFFA4A4A4),
              ),
            ],
          ),
        ),
      );

  Widget _buildCopyrightText() =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          '''키퍼노트는 XD와 공식적인 관계가 없는
팬 메이드 비영리 가이드 앱이며, 게임사의 지적 재산권을 존중합니다.

본 앱에 사용된 모든 게임 이미지, 데이터 등의 저작권은
모두 XD Interactive Entertainment Co., Ltd.에 있습니다.

사용된 이미지 및 데이터는 오직 유저 가이드 목적으로만 사용되며,
상업적으로 이용되지 않습니다.''',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF8C8C8C),
            fontSize: 10,
            fontFamily: 'SF Pro',
            height: 1.6,
          ),
        ),
      );

  void _showIntegratedEditDialog() {
    final nameController = TextEditingController(text: _nickname);
    final uidController = TextEditingController(
      text: _displayUid == "UID를 입력해보세요" ? "" : _displayUid,
    );

    showDialog(
      context: context,
      builder: (context) =>
          Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '프로필 정보 수정',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '두근두근 타운 닉네임과 UID를 등록해 보세요.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '닉네임',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF444444),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    maxLength: 10,
                    decoration: _dialogInputDecoration(
                      hintText: '새로운 닉네임 입력',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'UID',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF444444),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: uidController,
                    maxLength: 7,
                    decoration: _dialogInputDecoration(
                      hintText: '소문자와 숫자 조합 7자리',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _copyToClipboard(_displayUid),
                      icon: const Icon(
                        Icons.content_copy_rounded,
                        size: 16,
                        color: Color(0xFFFF8E7C),
                      ),
                      label: const Text(
                        '현재 UID 복사',
                        style: TextStyle(
                          color: Color(0xFFFF8E7C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF8E7C),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _goBackToHome(),                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE7E7E7)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final uid = uidController.text.trim();

                            // UID 유효성 검사
                            if (uid.isNotEmpty && !RegExp(r'^[a-z0-9]{7}$').hasMatch(uid)) {
                              _showSnackBar("7자리 소문자와 숫자를 입력해주세요.");
                              return;
                            }

                            if (name.isNotEmpty || uid.isNotEmpty) {
                              // ★ 1. 여기서 다이얼로그를 즉시 닫습니다. (설정창으로 돌아감)
                              Navigator.pop(context);

                              // ★ 2. 설정창 배경에서 서버 저장을 시작합니다.
                              _updateUserInfoOnServer(name, uid);
                            } else {
                              Navigator.pop(context);
                            }
                          },

                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8E7C),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text(
                            '저장',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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

  Future<void> _updateUserInfoOnServer(String name, String uid) async {
    try {
      // 1. 설정창 배경에 로딩 표시 시작
      if (mounted) setState(() => _isLoading = true);

      User user = await UserApi.instance.me();

      // 2. 닉네임 업데이트
      if (name.isNotEmpty) {
        await http.put(
          Uri.parse('http://161.33.30.40:8080/api/user/update-nickname'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"kakaoId": user.id, "nickname": name}),
        );
      }

      // 3. UID 업데이트
      if (uid.isNotEmpty && RegExp(r'^[a-z0-9]{7}$').hasMatch(uid)) {
        await http.put(
          Uri.parse('http://161.33.30.40:8080/api/user/update-uid'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"kakaoId": user.id, "gameUid": uid}),
        );
      }

      // ★ 4번 Navigator.pop(context) 코드를 여기서 완전히 삭제했습니다!
      // 이미 버튼 클릭 시(onPressed) 다이얼로그를 닫았기 때문입니다.

      // 5. 설정창 데이터를 서버에서 다시 불러와 화면 갱신
      await _loadUserInfo();

      _didUserInfoChange = true;

      // 6. 성공 메시지 출력
      _showSnackBar("정보가 수정되었습니다! ✨");

    } catch (e) {
      debugPrint("업데이트 에러: $e");
      _showSnackBar("업데이트 실패");
    } finally {
      // 7. 로딩 종료 (설정창의 인디케이터가 사라짐)
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title) =>
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _buildInfoCard({required Widget child}) =>
      Container(
        width: double.infinity,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 4,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: child,
      );

  Widget _buildIconButton(String iconPath) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: Image.asset(
          iconPath,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildRowItem({
    required String label,
    String? trailingText,
    Widget? trailing,
    bool isTitleOnly = false,
  }) =>
      SizedBox(
        height: _infoRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF636363),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (trailingText != null)
                Text(
                  trailingText,
                  style: const TextStyle(
                    color: Color(0xFFA4A4A4),
                    fontSize: 16,
                  ),
                ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      );

  Widget _buildLinkItem(String title, String imagePath) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Image.asset(imagePath, width: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF636363),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Color(0xFFA4A4A4),
            ),
          ],
        ),
      );

  Widget _buildCustomSwitch(bool isActive) =>
      GestureDetector(
        onTap: () => setState(() => _isPushEnabled = !_isPushEnabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 53,
          height: 30,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFF8E7C).withOpacity(0.56)
                : const Color(0xFFD9D9D9),
            borderRadius: BorderRadius.circular(99),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment:
            isActive ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Container(
                width: 25,
                height: 25,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      );

  PreferredSizeWidget _buildAppBar(BuildContext context) =>
      AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          // ★ Navigator.pop 시 true를 전달하여 메인 화면의 갱신을 유도합니다.
          onPressed: () => Navigator.pop(context, _didUserInfoChange),        ),
        title: const Text(
          '설정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      );
}
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class CommunityUidVerificationScreen extends StatefulWidget {
  final String userId;

  const CommunityUidVerificationScreen({
    super.key,
    required this.userId,
  });

  @override
  State<CommunityUidVerificationScreen> createState() =>
      _CommunityUidVerificationScreenState();
}

class _CommunityUidVerificationScreenState
    extends State<CommunityUidVerificationScreen> {
  static const String _baseUrl = 'https://api.keepers-note.o-r.kr';

  static const Color _bgColor = Color(0xFFFFFCFB);
  static const Color _surfaceColor = Colors.white;
  static const Color _accentColor = Color(0xFFFF8E7C);
  static const Color _accentSoft = Color(0xFFFFF1EC);
  static const Color _lineColor = Color(0xFFF1DFD8);
  static const Color _textMain = Color(0xFF24313A);
  static const Color _textSub = Color(0xFF8A94A6);

  final TextEditingController _uidController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _pickedImage;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;

  BoxShadow get _softShadow => BoxShadow(
    color: Colors.black.withOpacity(0.045),
    blurRadius: 18,
    offset: const Offset(0, 8),
  );

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<String?> _uploadScreenshot(XFile file) async {
    final uri = Uri.parse('$_baseUrl/api/community/images/upload').replace(
      queryParameters: <String, String>{
        'userId': widget.userId,
      },
    );

    final request = http.MultipartRequest('POST', uri);
    final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
    final parts = mimeType.split('/');

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: parts.length == 2 ? MediaType(parts[0], parts[1]) : null,
      ),
    );

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('스크린샷 업로드 실패 (${response.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final imageUrl = decoded['imageUrl']?.toString();

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      throw Exception('업로드 응답 형식이 올바르지 않아요.');
    }

    return imageUrl.trim();
  }

  Future<void> _pickScreenshot() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file == null) return;

      setState(() {
        _pickedImage = file;
      });
    } catch (e) {
      _showMessage('스크린샷 선택 중 문제가 발생했어요.\n$e');
    }
  }

  void _removeScreenshot() {
    setState(() {
      _pickedImage = null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isUploadingImage) return;

    final uid = _uidController.text.trim();

    if (widget.userId.isEmpty) {
      _showMessage('로그인 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
      return;
    }

    if (uid.isEmpty) {
      _showMessage('UID를 입력해주세요.');
      return;
    }

    if (uid.length < 3) {
      _showMessage('UID를 다시 확인해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? screenshotUrl;

      if (_pickedImage != null) {
        setState(() {
          _isUploadingImage = true;
        });
        try {
          screenshotUrl = await _uploadScreenshot(_pickedImage!);
        } finally {
          if (mounted) {
            setState(() {
              _isUploadingImage = false;
            });
          }
        }
      }

      final response = await http
          .post(
        Uri.parse('$_baseUrl/api/community/uid-verification'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': int.tryParse(widget.userId),
          'submittedUid': uid,
          'screenshotUrl': screenshotUrl,
        }),
      )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final bodyText = utf8.decode(response.bodyBytes);
        throw Exception('검증 신청 실패 (${response.statusCode})\n$bodyText');
      }

      if (!mounted) return;
      if (!mounted) return;

      _showMessage('UID 인증 요청이 접수되었어요.\n승인 후에는 UID를 변경할 수 없어요.');

      await Future.delayed(const Duration(milliseconds: 900));

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('검증 신청 중 문제가 발생했어요.\n$e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploadingImage = false;
        });
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF3B3F45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFFB0B7C2),
        fontWeight: FontWeight.w700,
        fontSize: 13.8,
      ),
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFECECEC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFECECEC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFFFFB4A4),
          width: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: const Color(0xFFFFFFFF),
        shadowColor: Colors.transparent,
        foregroundColor: _textMain,
        centerTitle: true,
        title: const Text(
          'UID 인증 신청',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              onPressed: (_isSubmitting || _isUploadingImage) ? null : _submit,
              icon: (_isSubmitting || _isUploadingImage)
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: _accentColor,
                ),
              )
                  : const Icon(
                Icons.send_rounded,
                color: _accentColor,
                size: 22,
              ),
              splashRadius: 22,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildGuideCard(),
            const SizedBox(height: 14),
            _buildScreenshotComposerCard(),
            const SizedBox(height: 14),
            _buildSectionCard(
              title: '게임 UID',
              child: TextField(
                controller: _uidController,
                cursorColor: _accentColor,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _textMain,
                  height: 1.35,
                ),
                decoration: _inputDecoration('게임 UID를 입력해주세요.'),
              ),
            ),
            const SizedBox(height: 14),
            _buildSectionCard(
              title: '안내',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF3E6DF)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GuideLine('커뮤니티 글쓰기를 하려면 UID 인증이 필요해요.'),
                    SizedBox(height: 8),
                    _GuideLine('중복 UID이거나 확인이 필요한 경우 인게임 uid가 포함된 스크린샷을 함께 올려주세요.'),
                    SizedBox(height: 8),
                    _GuideLine('승인 완료 후에는 UID가 잠겨서 변경할 수 없어요.'), // ⭐ 추가
                    SizedBox(height: 8),
                    _GuideLine('승인되면 글쓰기 화면으로 바로 들어갈 수 있어요.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_softShadow],
        border: Border.all(color: _lineColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: _accentColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UID 인증 안내',
                  style: TextStyle(
                    fontSize: 15.2,
                    fontWeight: FontWeight.w900,
                    color: _textMain,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '첫 인증 시에는 UID만 입력하고,\n1회 거절 후 재신청 시에는 스크린샷도 첨부해주세요.',
                  style: TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w700,
                    color: _textSub,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenshotComposerCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [_softShadow],
        border: Border.all(color: _lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _accentSoft,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: _accentColor,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '스크린샷',
                    style: TextStyle(
                      fontSize: 15.2,
                      fontWeight: FontWeight.w900,
                      color: _textMain,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _pickedImage == null ? '선택 안함' : '첨부 완료',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: _accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_pickedImage == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: (_isSubmitting || _isUploadingImage)
                    ? null
                    : _pickScreenshot,
                child: Container(
                  height: 260,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFEFD),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFF0ECE8)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _accentSoft,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: _accentColor,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '스크린샷 선택',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '필요한 경우에만 1장 첨부하면 돼요.',
                        style: TextStyle(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w700,
                          color: _textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: double.infinity,
                      height: 300,
                      child: Image.file(
                        File(_pickedImage!.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: (_isSubmitting || _isUploadingImage)
                          ? null
                          : _removeScreenshot,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.42),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_isSubmitting || _isUploadingImage)
                      ? null
                      : _pickScreenshot,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: Color(0xFFEAE1DC)),
                    backgroundColor: Colors.white,
                    foregroundColor: _textMain,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(
                    Icons.photo_library_outlined,
                    color: _accentColor,
                    size: 20,
                  ),
                  label: const Text(
                    '스크린샷 변경',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_softShadow],
        border: Border.all(color: _lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.8,
                  fontWeight: FontWeight.w900,
                  color: _textMain,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  final String text;

  const _GuideLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(
            Icons.circle,
            size: 6,
            color: Color(0xFFFF8E7C),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.8,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A94A6),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

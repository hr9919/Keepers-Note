import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class CommunityWriteScreen extends StatefulWidget {
  final String kakaoId;
  final List<String> availableTags;

  const CommunityWriteScreen({
    super.key,
    required this.kakaoId,
    required this.availableTags,
  });

  @override
  State<CommunityWriteScreen> createState() => _CommunityWriteScreenState();
}

class _CommunityWriteScreenState extends State<CommunityWriteScreen> {
  static const String _baseUrl = 'http://161.33.30.40:8080';
  static const int _maxImages = 5;
  static const int _maxTags = 2;

  static const Color _bgColor = Color(0xFFFFFCFB);
  static const Color _surfaceColor = Colors.white;
  static const Color _accentColor = Color(0xFFFF8E7C);
  static const Color _accentSoft = Color(0xFFFFF1EC);
  static const Color _lineColor = Color(0xFFF1DFD8);
  static const Color _textMain = Color(0xFF24313A);
  static const Color _textSub = Color(0xFF8A94A6);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSubmitting = false;
  bool _isUploadingImage = false;

  String? _pendingCommunityAction;
  bool _isLaunchingCommunityAction = false;

  final List<String> _selectedTags = <String>[];
  final List<XFile> _pickedImages = <XFile>[];
  final List<String> _uploadedImageUrls = <String>[];

  List<String> get _filteredTags =>
      widget.availableTags.where((e) => e.trim().isNotEmpty && e != '전체').toList();

  BoxShadow get _softShadow => BoxShadow(
    color: Colors.black.withOpacity(0.045),
    blurRadius: 18,
    offset: const Offset(0, 8),
  );

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_pickedImages.length >= _maxImages) {
      _showMessage('사진은 최대 $_maxImages장까지 올릴 수 있어요.');
      return;
    }

    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 88,
      );

      if (images.isEmpty) return;

      final remain = _maxImages - _pickedImages.length;
      final selected = images.take(remain).toList();

      setState(() {
        _pickedImages.addAll(selected);
      });

      if (images.length > remain) {
        _showMessage('최대 $_maxImages장까지만 추가할 수 있어요.');
      }
    } catch (e) {
      _showMessage('사진 선택 중 문제가 발생했어요.\n$e');
    }
  }

  void _removeImage(int index) {
    if (index < 0 || index >= _pickedImages.length) return;
    setState(() {
      _pickedImages.removeAt(index);
    });
  }

  Future<String> _uploadSingleImage(XFile image) async {
    final uri = Uri.parse(
      '$_baseUrl/api/community/images/upload',
    ).replace(
      queryParameters: <String, String>{
        'kakaoId': widget.kakaoId,
      },
    );

    final request = http.MultipartRequest('POST', uri);

    final mimeType = lookupMimeType(image.path) ?? 'image/jpeg';
    final mimeParts = mimeType.split('/');

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        image.path,
        contentType: mimeParts.length == 2
            ? MediaType(mimeParts[0], mimeParts[1])
            : null,
      ),
    );

    final streamed = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final bodyText = utf8.decode(response.bodyBytes);
      debugPrint('❌ 이미지 업로드 실패: ${response.statusCode}');
      debugPrint('❌ 이미지 업로드 응답: $bodyText');
      throw Exception('이미지 업로드 실패 (${response.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is Map<String, dynamic>) {
      final imageUrl = decoded['imageUrl'] ?? decoded['url'] ?? decoded['data'];

      if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
        return imageUrl.toString().trim();
      }
    }

    debugPrint('❌ 이미지 업로드 응답 형식 이상: ${response.body}');
    throw Exception('업로드 응답 형식이 올바르지 않아요.');
  }

  Future<List<String>> _uploadImagesIfNeeded() async {
    if (_pickedImages.isEmpty) {
      throw Exception('사진을 1장 이상 선택해주세요.');
    }

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final List<String> urls = await Future.wait(
        _pickedImages.map((image) => _uploadSingleImage(image)),
      );

      return urls;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isUploadingImage) return;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (widget.kakaoId.isEmpty) {
      _showMessage('로그인 정보가 아직 없어요. 잠시 후 다시 시도해주세요.');
      return;
    }

    if (_pickedImages.isEmpty) {
      _showMessage('사진을 1장 이상 선택해주세요.');
      return;
    }

    if (_selectedTags.isEmpty) {
      _showMessage('태그를 선택해주세요.');
      return;
    }

    if (title.isEmpty) {
      _showMessage('제목을 입력해주세요.');
      return;
    }

    if (title.length > 60) {
      _showMessage('제목은 60자 이내로 입력해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uploadedUrls = await _uploadImagesIfNeeded();

      _uploadedImageUrls
        ..clear()
        ..addAll(uploadedUrls);

      final uri = Uri.parse('$_baseUrl/api/community/posts');

      final requestBody = <String, dynamic>{
        'kakaoId': widget.kakaoId,
        'title': title,
        'content': body,
        'tags': _selectedTags,
        'imageUrls': _uploadedImageUrls,
      };

      debugPrint('🟠 게시글 등록 요청: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
        uri,
        headers: <String, String>{
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final bodyText = utf8.decode(response.bodyBytes);
        debugPrint('❌ 게시글 등록 실패: ${response.statusCode}');
        debugPrint('❌ 게시글 등록 응답: $bodyText');
        throw Exception('게시글 등록 실패 (${response.statusCode})\n$bodyText');
      }

      debugPrint('✅ 게시글 등록 성공: ${response.statusCode}');

      if (!mounted) return;
      Navigator.pop(context, true);
    } on TimeoutException {
      _showMessage('요청 시간이 초과됐어요. 잠시 후 다시 시도해주세요.');
    } catch (e) {
      debugPrint('❌ 글 등록 중 예외: $e');
      _showMessage('글 등록 중 문제가 발생했어요.\n$e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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

  _WriteTagChipStyle _tagChipStyle(String text) {
    switch (text) {
      case '인테리어':
        return const _WriteTagChipStyle(
          selectedBackground: Color(0xFFFFE8DF),
          selectedBorder: Color(0xFFF1BEAA),
          selectedText: Color(0xFFC96547),
        );
      case '익스테리어':
        return const _WriteTagChipStyle(
          selectedBackground: Color(0xFFE5F5EB),
          selectedBorder: Color(0xFFBFE2CB),
          selectedText: Color(0xFF43885B),
        );
      case '코디':
        return const _WriteTagChipStyle(
          selectedBackground: Color(0xFFFFE8F4),
          selectedBorder: Color(0xFFEAB8D6),
          selectedText: Color(0xFFB75689),
        );
      case '반려동물':
        return const _WriteTagChipStyle(
          selectedBackground: Color(0xFFEEE7FF),
          selectedBorder: Color(0xFFD1C2F0),
          selectedText: Color(0xFF775BB8),
        );
      case '도트 도안':
        return const _WriteTagChipStyle(
          selectedBackground: Color(0xFFFFF2D9),
          selectedBorder: Color(0xFFEBCF8D),
          selectedText: Color(0xFFB78718),
        );
      case '꿀팁 영상':
        return const _WriteTagChipStyle(
          selectedBackground: Color(0xFFE1F1FC),
          selectedBorder: Color(0xFFB6DBF2),
          selectedText: Color(0xFF427FA7),
        );
      case '공략':
        return const _WriteTagChipStyle(
          selectedBackground: Color(0xFFE3EDFF),
          selectedBorder: Color(0xFFBFD4FF),
          selectedText: Color(0xFF2F5FBF),
        );
      default:
        return const _WriteTagChipStyle(
          selectedBackground: Color(0xFFFFEDE7),
          selectedBorder: Color(0xFFFFD8CF),
          selectedText: Color(0xFFFF8E7C),
        );
    }
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
      counterStyle: const TextStyle(
        fontSize: 11.5,
        color: _textSub,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = _filteredTags;

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
          '새 게시물',
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
              icon: _isSubmitting || _isUploadingImage
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
            _buildInstagramComposerCard(),
            const SizedBox(height: 14),
            _buildInstagramSectionCard(
              title: '태그',
              trailing: Text(
                '${_selectedTags.length}/$_maxTags',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _textSub,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      final selected = _selectedTags.contains(tag);
                      final style = _tagChipStyle(tag);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedTags.remove(tag);
                            } else {
                              if (_selectedTags.length >= _maxTags) {
                                _showMessage('태그는 최대 $_maxTags개까지 선택할 수 있어요.');
                                return;
                              }
                              _selectedTags.add(tag);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? style.selectedBackground : Colors.white,
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                              color: selected
                                  ? style.selectedBorder
                                  : const Color(0xFFD8DDE5),
                            ),
                            boxShadow: selected
                                ? [
                              BoxShadow(
                                color: style.selectedBorder.withOpacity(0.16),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                                : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.018),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 12.2,
                              fontWeight: FontWeight.w900,
                              color: selected
                                  ? style.selectedText
                                  : const Color(0xFF8E98A7),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildInstagramSectionCard(
              title: '제목',
              child: TextField(
                controller: _titleController,
                maxLength: 60,
                cursorColor: _accentColor,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _textMain,
                  height: 1.35,
                ),
                decoration: _inputDecoration('제목을 입력해주세요.'),
              ),
            ),
            const SizedBox(height: 14),
            _buildInstagramSectionCard(
              title: '내용',
              child: TextField(
                controller: _bodyController,
                maxLines: 10,
                minLines: 8,
                maxLength: 1200,
                cursorColor: _accentColor,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textMain,
                  height: 1.55,
                ),
                decoration: _inputDecoration('내용을 입력해주세요.'),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildInstagramComposerCard() {
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
                    '사진',
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
                    '${_pickedImages.length}/$_maxImages',
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
          if (_pickedImages.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: (_isSubmitting || _isUploadingImage) ? null : _pickImages,
                child: Container(
                  height: 280,
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
                        '사진 선택',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '최대 5장까지 업로드할 수 있어요.',
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
            SizedBox(
              height: 360,
              child: PageView.builder(
                itemCount: _pickedImages.length,
                controller: PageController(viewportFraction: 1),
                itemBuilder: (_, index) {
                  final file = _pickedImages[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: SizedBox.expand(
                            child: Image.file(
                              File(file.path),
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
                                : () => _removeImage(index),
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
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.86),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${index + 1}/${_pickedImages.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFB46C58),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_isSubmitting || _isUploadingImage) ? null : _pickImages,
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
                    Icons.add_photo_alternate_outlined,
                    color: _accentColor,
                    size: 20,
                  ),
                  label: const Text(
                    '사진 추가',
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

  Widget _buildInstagramSectionCard({
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

class _WriteTagChipStyle {
  final Color selectedBackground;
  final Color selectedBorder;
  final Color selectedText;

  const _WriteTagChipStyle({
    required this.selectedBackground,
    required this.selectedBorder,
    required this.selectedText,
  });
}
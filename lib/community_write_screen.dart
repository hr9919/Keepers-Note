import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'image_adjust_screen.dart';

enum _DraftImageSourceType {
  existingUrl,
  localFile,
}

class _DraftImageItem {
  final String id;
  final _DraftImageSourceType type;
  final String value;

  const _DraftImageItem({
    required this.id,
    required this.type,
    required this.value,
  });

  bool get isExisting => type == _DraftImageSourceType.existingUrl;
  bool get isLocal => type == _DraftImageSourceType.localFile;
}

class CommunityWriteScreen extends StatefulWidget {
  final String kakaoId;
  final List<String> availableTags;

  final bool isEditMode;
  final int? editingPostId;
  final String? initialTitle;
  final String? initialBody;
  final List<String>? initialTags;
  final List<String>? initialImageUrls;
  final String? initialVisibility;
  final bool? initialDiary;
  final bool? initialAllowComments;

  const CommunityWriteScreen({
    super.key,
    required this.kakaoId,
    required this.availableTags,
    this.isEditMode = false,
    this.editingPostId,
    this.initialTitle,
    this.initialBody,
    this.initialTags,
    this.initialImageUrls,
    this.initialVisibility,
    this.initialDiary,
    this.initialAllowComments,
  });

  @override
  State<CommunityWriteScreen> createState() => _CommunityWriteScreenState();
}

class _CommunityWriteScreenState extends State<CommunityWriteScreen> {
  static const String _baseUrl = 'https://api.keepers-note.o-r.kr';
  static const int _maxImages = 5;
  static const int _maxTags = 2;

  static const Color _bgColor = Color(0xFFFFFCFB);
  static const Color _surfaceColor = Colors.white;
  static const Color _accentColor = Color(0xFFFF8E7C);
  static const Color _accentSoft = Color(0xFFFFF1EC);
  static const Color _lineColor = Color(0xFFF1DFD8);
  static const Color _textMain = Color(0xFF24313A);
  static const Color _textSub = Color(0xFF8A94A6);

  final List<_DraftImageItem> _draftImages = <_DraftImageItem>[];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _selectedTags = <String>[];

  bool _isSubmitting = false;
  bool _isUploadingImage = false;

  String _visibility = 'PUBLIC';
  bool _isDiary = false;
  bool _allowComments = true;

  List<String> get _filteredTags =>
      widget.availableTags.where((e) => e.trim().isNotEmpty && e != '전체').toList();

  BoxShadow get _softShadow => BoxShadow(
    color: Colors.black.withOpacity(0.045),
    blurRadius: 18,
    offset: const Offset(0, 8),
  );

  @override
  void initState() {
    super.initState();

    _titleController.text = widget.initialTitle ?? '';
    _bodyController.text = widget.initialBody ?? '';

    if ((widget.initialTags ?? const <String>[]).isNotEmpty) {
      _selectedTags
        ..clear()
        ..addAll(widget.initialTags!);
    }

    for (final url in (widget.initialImageUrls ?? const <String>[])) {
      if (url.trim().isEmpty) continue;
      _draftImages.add(
        _DraftImageItem(
          id: 'existing_${url.hashCode}_${_draftImages.length}',
          type: _DraftImageSourceType.existingUrl,
          value: url,
        ),
      );
    }

    _visibility = (widget.initialVisibility ?? 'PUBLIC').trim().isEmpty
        ? 'PUBLIC'
        : (widget.initialVisibility ?? 'PUBLIC').trim().toUpperCase();

    _isDiary = widget.initialDiary ?? false;
    _allowComments = widget.initialAllowComments ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
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
        contentType: mimeParts.length == 2 ? MediaType(mimeParts[0], mimeParts[1]) : null,
      ),
    );

    final streamed = await request.send().timeout(const Duration(seconds: 60));
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

  @override
  void didUpdateWidget(covariant CommunityWriteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialTitle != widget.initialTitle) {
      _titleController.text = widget.initialTitle ?? '';
    }

    if (oldWidget.initialBody != widget.initialBody) {
      _bodyController.text = widget.initialBody ?? '';
    }

    if (oldWidget.initialTags != widget.initialTags) {
      _selectedTags
        ..clear()
        ..addAll(widget.initialTags ?? const <String>[]);
    }

    if (oldWidget.initialVisibility != widget.initialVisibility) {
      _visibility = (widget.initialVisibility ?? 'PUBLIC').trim().isEmpty
          ? 'PUBLIC'
          : (widget.initialVisibility ?? 'PUBLIC').trim().toUpperCase();
    }

    if (oldWidget.initialDiary != widget.initialDiary) {
      _isDiary = widget.initialDiary ?? false;
    }

    if (oldWidget.initialAllowComments != widget.initialAllowComments) {
      _allowComments = widget.initialAllowComments ?? true;
    }
  }

  Future<String> _saveAdjustedBytesToTemp({
    required Uint8List bytes,
    required String extension,
  }) async {
    final dir = Directory.systemTemp;
    final filename = 'community_${DateTime.now().microsecondsSinceEpoch}.${extension.toLowerCase()}';
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String?> _openCommunityAdjustScreen(String imagePath) async {
    final result = await Navigator.push<ImageAdjustResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageAdjustScreen(
          imagePath: imagePath,
          title: '사진 조정',
          shape: ImageAdjustShape.roundedRect,
          viewportAspectRatio: null,
          borderRadius: 24,
        ),
      ),
    );

    if (result == null) return null;

    return _saveAdjustedBytesToTemp(
      bytes: result.bytes,
      extension: result.extension,
    );
  }

  Future<String> _downloadExistingImageToTemp(String imageUrl) async {
    final uri = Uri.parse(imageUrl);
    final response = await http.get(uri).timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('기존 이미지를 불러오지 못했어요. (${response.statusCode})');
    }

    final String extFromPath = p.extension(uri.path).replaceFirst('.', '').trim();
    final String extFromMime =
    (lookupMimeType(uri.path, headerBytes: response.bodyBytes) ?? '').split('/').last.trim();
    final String extension = (extFromPath.isNotEmpty ? extFromPath : extFromMime).isNotEmpty
        ? (extFromPath.isNotEmpty ? extFromPath : extFromMime)
        : 'jpg';

    return _saveAdjustedBytesToTemp(
      bytes: response.bodyBytes,
      extension: extension,
    );
  }

  Future<void> _editDraftImageAt(int index) async {
    if (index < 0 || index >= _draftImages.length) return;

    final item = _draftImages[index];

    try {
      final String sourcePath =
      item.isExisting ? await _downloadExistingImageToTemp(item.value) : item.value;

      final String? adjustedPath = await _openCommunityAdjustScreen(sourcePath);
      if (adjustedPath == null) return;

      if (!mounted) return;
      setState(() {
        _draftImages[index] = _DraftImageItem(
          id: 'local_${DateTime.now().microsecondsSinceEpoch}_$index',
          type: _DraftImageSourceType.localFile,
          value: adjustedPath,
        );
      });
    } catch (e) {
      _showMessage('사진 수정 중 문제가 발생했어요.\n$e');
    }
  }

  Widget _buildDraftImageCard(
      _DraftImageItem item,
      int index, {
        bool showDraggingStyle = false,
      }) {
    return ReorderableDelayedDragStartListener(
      key: ValueKey(item.id),
      index: index,
      enabled: !(_isSubmitting || _isUploadingImage),
      child: Container(
        width: 116,
        margin: const EdgeInsets.only(right: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: showDraggingStyle ? const Color(0xFFFFC7BA) : const Color(0xFFF1DFD8),
              width: showDraggingStyle ? 1.3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(showDraggingStyle ? 0.10 : 0.05),
                blurRadius: showDraggingStyle ? 18 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: (_isSubmitting || _isUploadingImage)
                          ? null
                          : () => _editDraftImageAt(index),
                      child: item.isExisting
                          ? Image.network(
                        item.value,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF4F4F4),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      )
                          : Image.file(
                        File(item.value),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: (_isSubmitting || _isUploadingImage)
                        ? null
                        : () => _removeDraftImageAt(index),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.42),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    if (_draftImages.length >= _maxImages) {
      _showMessage('사진은 최대 $_maxImages장까지 올릴 수 있어요.');
      return;
    }

    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 92);
      if (images.isEmpty) return;

      final remain = _maxImages - _draftImages.length;
      final selected = images.take(remain).toList();

      for (final image in selected) {
        final adjustedPath = await _openCommunityAdjustScreen(image.path);
        if (adjustedPath == null) continue;

        setState(() {
          _draftImages.add(
            _DraftImageItem(
              id: 'local_${DateTime.now().microsecondsSinceEpoch}_${_draftImages.length}',
              type: _DraftImageSourceType.localFile,
              value: adjustedPath,
            ),
          );
        });
      }

      if (images.length > remain) {
        _showMessage('최대 $_maxImages장까지만 추가할 수 있어요.');
      }
    } catch (e) {
      _showMessage('사진 선택 중 문제가 발생했어요.\n$e');
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

    if (_draftImages.isEmpty) {
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
      final finalImageUrls = await _buildFinalImageUrls();

      final requestBody = <String, dynamic>{
        'kakaoId': widget.kakaoId,
        'title': title,
        'content': body,
        'tags': _selectedTags.toList(),
        'imageUrls': finalImageUrls,
        'visibility': _visibility,
        'diary': _isDiary,
        'allowComments': _allowComments,
      };

      final uri = widget.isEditMode
          ? Uri.parse('$_baseUrl/api/community/posts/${widget.editingPostId}')
          : Uri.parse('$_baseUrl/api/community/posts');

      final response = widget.isEditMode
          ? await http
          .put(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 40))
          : await http
          .post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('저장 실패 (${response.statusCode})\n${utf8.decode(response.bodyBytes)}');
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('글 저장 중 문제가 발생했어요.\n$e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _removeDraftImageAt(int index) {
    if (index < 0 || index >= _draftImages.length) return;
    setState(() {
      _draftImages.removeAt(index);
    });
  }

  void _reorderDraftImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _draftImages.removeAt(oldIndex);
      _draftImages.insert(newIndex, item);
    });
  }

  Future<List<String>> _buildFinalImageUrls() async {
    setState(() => _isUploadingImage = true);

    try {
      final List<String> finalUrls = <String>[];

      for (final item in _draftImages) {
        if (item.isExisting) {
          finalUrls.add(item.value);
        } else {
          final uploaded = await _uploadSingleImage(XFile(item.value));
          finalUrls.add(uploaded);
        }
      }

      return finalUrls;
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
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
        title: Text(
          widget.isEditMode ? '게시글 수정' : '새 게시물',
          style: const TextStyle(
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
                              color: selected ? style.selectedBorder : const Color(0xFFD8DDE5),
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
                              color: selected ? style.selectedText : const Color(0xFF8E98A7),
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
            _buildVisibilitySectionCard(),
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

  Widget _buildVisibilitySectionCard() {
    return _buildInstagramSectionCard(
      title: '공개 설정',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildVisibilityChip(
                value: 'PUBLIC',
                label: '전체공개',
                icon: Icons.public_rounded,
              ),
              _buildVisibilityChip(
                value: 'FOLLOWERS',
                label: '팔로워 공개',
                icon: Icons.people_alt_rounded,
              ),
              _buildVisibilityChip(
                value: 'PRIVATE',
                label: '나만보기',
                icon: Icons.lock_rounded,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSettingToggleTile(
            title: '댓글 허용',
            value: _allowComments,
            onChanged: (value) {
              setState(() {
                _allowComments = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityChip({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final bool selected = _visibility == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _visibility = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _accentSoft : Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: selected ? const Color(0xFFFFC7BA) : const Color(0xFFD8DDE5),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: const Color(0xFFFFC7BA).withOpacity(0.18),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? _accentColor : const Color(0xFF8E98A7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w900,
                color: selected ? _accentColor : const Color(0xFF8E98A7),
              ),
            ),
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
                    '${_draftImages.length}/$_maxImages',
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
          if (_draftImages.isEmpty)
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
                      Text(
                        widget.isEditMode ? '사진 추가' : '사진 선택',
                        style: const TextStyle(
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
              height: 150,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final double animValue = Curves.easeOutCubic.transform(animation.value);
                      final double scale = lerpDouble(1, 1.03, animValue)!;
                      final double elevation = lerpDouble(0, 8, animValue)!;

                      return Transform.scale(
                        scale: scale,
                        child: Material(
                          elevation: elevation,
                          color: Colors.transparent,
                          shadowColor: Colors.black.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                          child: child,
                        ),
                      );
                    },
                    child: child,
                  );
                },
                onReorder: _reorderDraftImages,
                itemCount: _draftImages.length,
                itemBuilder: (_, index) {
                  final item = _draftImages[index];
                  return _buildDraftImageCard(item, index);
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Text(
                '사진을 누르면 수정할 수 있고, 꾹 누르면 순서를 바꿀 수 있어요.',
                style: TextStyle(
                  fontSize: 11.8,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFADB5C2),
                  height: 1.35,
                ),
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

  Widget _buildSettingToggleTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final bool isDisabled = _isSubmitting || _isUploadingImage;
    final String displayText = value ? '댓글 허용' : '댓글 비활성화';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : () => onChanged(!value),
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: value
                ? const Color(0xFFFFF2EF)
                : const Color(0xFFFFFBFA),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: value
                  ? const Color(0xFFFFD8CF)
                  : const Color(0xFFF0E3DC),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFF8E7C).withOpacity(
                  value ? 0.10 : 0.04,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                value
                    ? Icons.mode_comment_outlined
                    : Icons.comments_disabled_outlined,
                size: 16,
                color: value
                    ? const Color(0xFFFF8E7C)
                    : const Color(0xFF7B6D64),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: value
                        ? const Color(0xFFFF8E7C)
                        : const Color(0xFF7B6D64),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildMiniToggleSwitch(value: value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniToggleSwitch({required bool value}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 34,
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFFFF8E7C).withOpacity(0.55)
            : const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
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

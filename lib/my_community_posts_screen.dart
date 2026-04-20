import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'community_write_screen.dart';
import 'services/community_tag_api_service.dart';

class MyCommunityPostsScreen extends StatefulWidget {
  final String kakaoId;

  const MyCommunityPostsScreen({
    super.key,
    required this.kakaoId,
  });

  @override
  State<MyCommunityPostsScreen> createState() => _MyCommunityPostsScreenState();
}

class _MyCommunityPostsScreenState extends State<MyCommunityPostsScreen> {
  static const String _baseUrl = 'https://api.keepers-note.o-r.kr';

  bool _isLoading = false;
  bool _isDeleting = false;
  bool _isSelectionMode = false;
  String? _errorMessage;
  List<MyCommunityPostItem> _posts = <MyCommunityPostItem>[];
  final Set<int> _selectedPostIds = <int>{};

  @override
  void initState() {
    super.initState();
    _fetchMyPosts();
  }

  Future<void> _fetchMyPosts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('$_baseUrl/api/community/posts/me').replace(
        queryParameters: <String, String>{
          'kakaoId': widget.kakaoId,
        },
      );

      final response =
      await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('내 게시물 조회 실패 (${response.statusCode})');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      List<dynamic> rawList = <dynamic>[];

      if (decoded is List) {
        rawList = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final candidate = decoded['items'] ??
            decoded['data'] ??
            decoded['posts'] ??
            decoded['content'];
        if (candidate is List) {
          rawList = candidate;
        }
      }

      final posts = rawList
          .whereType<Map>()
          .map((e) => MyCommunityPostItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted) return;
      setState(() {
        _posts = posts;
        _selectedPostIds.removeWhere(
              (id) => !_posts.any((post) => post.id == id),
        );
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage = '서버 응답이 지연되고 있어요.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _allSelected =>
      _posts.isNotEmpty && _selectedPostIds.length == _posts.length;

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPostIds.clear();
      }
    });
  }

  void _togglePostSelection(int postId) {
    setState(() {
      if (_selectedPostIds.contains(postId)) {
        _selectedPostIds.remove(postId);
      } else {
        _selectedPostIds.add(postId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedPostIds.clear();
      } else {
        _selectedPostIds
          ..clear()
          ..addAll(_posts.map((e) => e.id));
      }
    });
  }

  Future<void> _openPostMoreSheet(MyCommunityPostItem post) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFF0E3DC)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9DDD6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '게시글 메뉴',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF3E332F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildActionTile(
                    icon: Icons.ios_share_rounded,
                    iconBg: const Color(0xFFFFF4EE),
                    iconColor: const Color(0xFFFF8E7C),
                    title: '공유하기',
                    subtitle: '게시글 내용을 복사해요',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _sharePost(post);
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.edit_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF4A7BD0),
                    title: '글 수정',
                    subtitle: '기존 내용으로 수정 화면을 열어요',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _openEditPost(post);
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.delete_rounded,
                    iconBg: const Color(0xFFFFF1F1),
                    iconColor: const Color(0xFFE46C6C),
                    title: '글 삭제',
                    subtitle: '이 게시글을 삭제해요',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _confirmDeleteSingle(post);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditPost(MyCommunityPostItem post) async {
    try {
      final tagItems = await CommunityTagApiService.fetchActiveTags();
      final availableTags = tagItems.map((e) => e.tagName).toList();

      if (!mounted) return;

      final bool? updated = await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(
          builder: (_) => CommunityWriteScreen(
            kakaoId: widget.kakaoId,
            availableTags: availableTags,
            isEditMode: true,
            editingPostId: post.id,
            initialTitle: post.title,
            initialBody: post.body,
            initialTags: post.tags,
            initialImageUrls: post.imageUrls,
          ),
        ),
      );

      if (updated == true) {
        await _fetchMyPosts();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정 화면을 여는 중 문제가 발생했어요. $e')),
      );
    }
  }

  Future<void> _sharePost(MyCommunityPostItem post) async {
    final String shareText = [
      if (post.title.trim().isNotEmpty) post.title.trim(),
      if (post.body.trim().isNotEmpty) post.body.trim(),
      '',
      'https://keepersnote.app/community/post/${post.id}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: shareText));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('게시글 내용이 복사되었어요.')),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: iconBg.withOpacity(0.9)),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3F3531),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9E9088),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFC5B7B0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSingle(MyCommunityPostItem post) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '게시글 삭제',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            '이 게시글을 삭제할까요?\n삭제 후에는 되돌릴 수 없어요.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE46C6C),
                foregroundColor: Colors.white,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _deleteSingle(post.id);
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedPostIds.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '선택 게시글 삭제',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '선택한 ${_selectedPostIds.length}개의 게시글을 삭제할까요?\n삭제 후에는 되돌릴 수 없어요.',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE46C6C),
                foregroundColor: Colors.white,
              ),
              child: const Text('일괄 삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _deleteSelected();
  }

  Future<void> _deleteSingle(int postId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/community/posts/$postId').replace(
        queryParameters: <String, String>{
          'kakaoId': widget.kakaoId,
        },
      );

      final response = await http.delete(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('게시글 삭제 실패 (${response.statusCode})');
      }

      if (!mounted) return;
      setState(() {
        _posts.removeWhere((e) => e.id == postId);
        _selectedPostIds.remove(postId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 삭제되었어요.')),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 응답이 지연되고 있어요.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 중 문제가 발생했어요. $e')),
      );
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedPostIds.isEmpty || _isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    final ids = _selectedPostIds.toList();
    int successCount = 0;

    try {
      for (final id in ids) {
        final uri = Uri.parse('$_baseUrl/api/community/posts/$id').replace(
          queryParameters: <String, String>{
            'kakaoId': widget.kakaoId,
          },
        );

        final response =
        await http.delete(uri).timeout(const Duration(seconds: 10));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          successCount++;
        }
      }

      if (!mounted) return;
      setState(() {
        _posts.removeWhere((e) => ids.contains(e.id));
        _selectedPostIds.clear();
        _isSelectionMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$successCount개의 게시글을 삭제했어요.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일괄 삭제 중 문제가 발생했어요. $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Color _chipBg(String text) {
    switch (text) {
      case '인테리어':
        return const Color(0xFFFFE8DF);
      case '익스테리어':
        return const Color(0xFFE5F5EB);
      case '코디':
        return const Color(0xFFFFE8F4);
      case '반려동물':
        return const Color(0xFFEEE7FF);
      case '도트 도안':
        return const Color(0xFFFFF2D9);
      case '꿀팁 영상':
        return const Color(0xFFE1F1FC);
      default:
        return const Color(0xFFF4EEEA);
    }
  }

  Color _chipBorder(String text) {
    switch (text) {
      case '인테리어':
        return const Color(0xFFF1BEAA);
      case '익스테리어':
        return const Color(0xFFBFE2CB);
      case '코디':
        return const Color(0xFFEAB8D6);
      case '반려동물':
        return const Color(0xFFD1C2F0);
      case '도트 도안':
        return const Color(0xFFEBCF8D);
      case '꿀팁 영상':
        return const Color(0xFFB6DBF2);
      default:
        return const Color(0xFFE2D5CC);
    }
  }

  Color _chipText(String text) {
    switch (text) {
      case '인테리어':
        return const Color(0xFFC96547);
      case '익스테리어':
        return const Color(0xFF43885B);
      case '코디':
        return const Color(0xFFB75689);
      case '반려동물':
        return const Color(0xFF775BB8);
      case '도트 도안':
        return const Color(0xFFB78718);
      case '꿀팁 영상':
        return const Color(0xFF427FA7);
      default:
        return const Color(0xFF7B6D64);
    }
  }

  Widget _buildChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _chipBg(tag),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _chipBorder(tag)),
      ),
      child: Text(
        '#$tag',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _chipText(tag),
        ),
      ),
    );
  }

  Widget _buildPostCard(MyCommunityPostItem post) {
    final selected = _selectedPostIds.contains(post.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected
              ? const Color(0xFFFFB8A8)
              : const Color(0xFFF0E3DD),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _isSelectionMode ? () => _togglePostSelection(post.id) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 4),
                child: GestureDetector(
                  onTap: () => _togglePostSelection(post.id),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFF8E7C)
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFFF8E7C)
                            : const Color(0xFFD9C9C3),
                      ),
                    ),
                    child: selected
                        ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                        : null,
                  ),
                ),
              ),

            GestureDetector(
              onTap: () => _openImageViewer(post),
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: post.imageUrls.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    _resolveImagePath(post.imageUrls.first),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Color(0xFFB6BFCB),
                    ),
                  ),
                )
                    : const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFFFF8E7C),
                  size: 34,
                ),
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: SizedBox(
                height: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${post.title.isEmpty ? '제목 없음' : post.title} · ${post.createdLabel}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.8,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF24313A),
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (!_isSelectionMode) ...[
                          const SizedBox(width: 8),
                          _buildMoreButton(
                            onTap: () => _openPostMoreSheet(post),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    Expanded(
                      child: Text(
                        post.body.isEmpty ? '내용 없음' : post.body,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.8,
                          height: 1.5,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: post.tags.take(2).map(_buildChip).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              size: 14,
                              color: Color(0xFFFF8E7C),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${post.likeCount}',
                              style: const TextStyle(
                                fontSize: 11.8,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveImagePath(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return '$_baseUrl$path';
    return '$_baseUrl/$path';
  }

  void _openImageViewer(MyCommunityPostItem post) {
    if (post.imageUrls.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.94),
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.black.withOpacity(0.96),
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: PageView.builder(
                      itemCount: post.imageUrls.length,
                      itemBuilder: (context, index) {
                        return InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Image.network(
                            _resolveImagePath(post.imageUrls[index]),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              size: 42,
                              color: Colors.white54,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Material(
                    color: Colors.black.withOpacity(0.36),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildMoreButton({
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF2E3DE)),
          ),
          child: const Icon(
            Icons.more_vert_rounded,
            size: 18,
            color: Color(0xFFC39B91),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.94),
      foregroundColor: const Color(0xFF2D3436),
      title: Text(
        _isSelectionMode
            ? '선택됨 ${_selectedPostIds.length}개'
            : '내 게시물',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      actions: [
        if (_posts.isNotEmpty && !_isSelectionMode)
          TextButton(
            onPressed: _toggleSelectionMode,
            child: const Text(
              '선택',
              style: TextStyle(
                color: Color(0xFFFF8E7C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        if (_isSelectionMode) ...[
          TextButton(
            onPressed: _toggleSelectAll,
            child: Text(
              _allSelected ? '해제' : '전체',
              style: const TextStyle(
                color: Color(0xFFFF8E7C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: _toggleSelectionMode,
            child: const Text(
              '취소',
              style: TextStyle(
                color: Color(0xFF8E7B74),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E3DD)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFFF8E7C),
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? '문제가 발생했어요.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.2,
              height: 1.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _fetchMyPosts,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFFFF8E7C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              '다시 불러오기',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E3DD)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            color: Color(0xFFFF8E7C),
            size: 36,
          ),
          SizedBox(height: 12),
          Text(
            '아직 올린 게시물이 없어요.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          SizedBox(height: 6),
          Text(
            '새 게시글을 작성하면 여기에 모아서 볼 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.8,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7B8794),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.98),
          border: const Border(
            top: BorderSide(color: Color(0xFFF0E3DD)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedPostIds.isEmpty
                    ? '게시글을 선택해주세요.'
                    : '${_selectedPostIds.length}개 선택됨',
                style: const TextStyle(
                  fontSize: 13.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _selectedPostIds.isEmpty || _isDeleting
                  ? null
                  : _confirmDeleteSelected,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFE46C6C),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFF3D5D5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isDeleting
                  ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.delete_rounded, size: 18),
              label: Text(
                _isDeleting ? '삭제 중' : '일괄 삭제',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F6),
      appBar: _buildAppBar(),
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBottomBar() : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_gradient.png',
              fit: BoxFit.cover,
            ),
          ),
          RefreshIndicator(
            color: const Color(0xFFFF8E7C),
            onRefresh: _fetchMyPosts,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                _isSelectionMode ? 16 : 30,
              ),
              children: [
                if (_isLoading && _posts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 70),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF8E7C),
                      ),
                    ),
                  )
                else if (_errorMessage != null)
                  _buildErrorCard()
                else if (_posts.isEmpty)
                    _buildEmptyCard()
                  else
                    ..._posts.map(_buildPostCard),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MyCommunityPostItem {
  final int id;
  final String title;
  final String body;
  final List<String> imageUrls;
  final List<String> tags;
  final int likeCount;
  final String createdLabel;

  const MyCommunityPostItem({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUrls,
    required this.tags,
    required this.likeCount,
    required this.createdLabel,
  });

  factory MyCommunityPostItem.fromJson(Map<String, dynamic> json) {
    List<String> readList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return <String>[];
    }

    return MyCommunityPostItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      body: (json['content'] ?? json['body'] ?? '').toString(),
      imageUrls: readList(json['imageUrls'] ?? json['images']),
      tags: readList(json['tags'] ?? json['tagNames']),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      createdLabel: (json['createdLabel'] ?? json['createdAt'] ?? '').toString(),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'community_write_screen.dart';
import 'my_community_posts_screen.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart' hide ImageInfo;
import 'services/community_tag_api_service.dart';
import 'models/community_tag_item.dart';

class CommunityScreen extends StatefulWidget {
  final VoidCallback? openDrawer;
  final String? kakaoId;
  final bool isAdmin;
  final int? initialPostId;

  static Future<bool?> openWrite(
      BuildContext context, {
        required String kakaoId,
        required List<String> availableTags,
      }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityWriteScreen(
          kakaoId: kakaoId,
          availableTags: availableTags,
        ),
      ),
    );
  }

  static Future<void> openMyPosts(
      BuildContext context, {
        required String kakaoId,
      }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MyCommunityPostsScreen(kakaoId: kakaoId),
      ),
    );
  }

  const CommunityScreen({
    super.key,
    this.openDrawer,
    this.kakaoId,
    this.isAdmin = false,
    this.initialPostId,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

enum CommunitySortType { latest, popular }

class CommunityPost {
  final int id;
  final String author;
  final String uid;
  final String title;
  final String body;
  final List<String> imageUrls;
  final List<String> tags;
  final int likeCount;
  final String createdLabel;
  final bool isAdminPick;
  final bool hasYoutube;
  final bool hasSourceLink;
  final bool likedByMe;
  final String profileImageUrl;
  final bool mine;
  final int commentCount;
  final String visibility;
  final bool lockedByOwner;
  final bool isFollowingAuthor;

  const CommunityPost({
    required this.id,
    required this.author,
    required this.uid,
    required this.title,
    required this.body,
    required this.imageUrls,
    required this.tags,
    required this.likeCount,
    required this.createdLabel,
    this.isAdminPick = false,
    this.hasYoutube = false,
    this.hasSourceLink = false,
    this.likedByMe = false,
    required this.profileImageUrl,
    this.mine = false,
    this.commentCount = 0,
    this.visibility = 'PUBLIC',
    this.lockedByOwner = false,
    this.isFollowingAuthor = false,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    List<String> readStringList(dynamic value) {
      if (value is List) {
        return value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const <String>[];
    }

    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') {
          return text;
        }
      }
      return fallback;
    }

    bool readBool(List<String> keys, {bool fallback = false}) {
      for (final key in keys) {
        final value = json[key];
        if (value is bool) return value;
        if (value is num) return value != 0;
        if (value is String) {
          final lower = value.toLowerCase();
          if (lower == 'true' || lower == '1' || lower == 'y') return true;
          if (lower == 'false' || lower == '0' || lower == 'n') return false;
        }
      }
      return fallback;
    }

    int readInt(List<String> keys, {int fallback = 0}) {
      for (final key in keys) {
        final value = json[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    return CommunityPost(
      id: readInt(const ['id']),
      author: readString(const ['authorName', 'author', 'nickname'], fallback: '사용자'),
      uid: readString(const ['authorUid', 'uid', 'gameUid'], fallback: 'UID'),
      title: readString(const ['title']),
      body: readString(const ['content', 'body']),
      imageUrls: readStringList(json['imageUrls'] ?? json['images'] ?? json['postImages']),
      tags: readStringList(json['tags'] ?? json['tagNames'] ?? json['postTags']),
      likeCount: readInt(const ['likeCount']),
      createdLabel: readString(const ['createdLabel', 'createdAtLabel', 'createdAt']),
      isAdminPick: readBool(const ['adminPick', 'isAdminPick']),
      hasYoutube: readBool(const ['hasYoutube']),
      hasSourceLink: readBool(const ['hasSourceLink']),
      likedByMe: readBool(const ['likedByMe', 'liked']),
      profileImageUrl: readString(const ['profileImageUrl', 'authorProfileImageUrl', 'userProfileImageUrl']),
      mine: readBool(const ['mine']),
      commentCount: readInt(const ['commentCount']),
      visibility: readString(const ['visibility'], fallback: 'PUBLIC'),
      lockedByOwner: readBool(const ['lockedByOwner']),
      isFollowingAuthor: readBool(const ['isFollowingAuthor']),
    );
  }

  CommunityPost copyWith({
    int? likeCount,
    bool? likedByMe,
    int? commentCount,
  }) {
    return CommunityPost(
      id: id,
      author: author,
      uid: uid,
      title: title,
      body: body,
      imageUrls: imageUrls,
      tags: tags,
      likeCount: likeCount ?? this.likeCount,
      createdLabel: createdLabel,
      isAdminPick: isAdminPick,
      hasYoutube: hasYoutube,
      hasSourceLink: hasSourceLink,
      likedByMe: likedByMe ?? this.likedByMe,
      profileImageUrl: profileImageUrl,
      mine: mine,
      commentCount: commentCount ?? this.commentCount,
      visibility: visibility,
      lockedByOwner: lockedByOwner,
      isFollowingAuthor: isFollowingAuthor,
    );
  }
}

class CommunityComment {
  final int id;
  final int postId;
  final int? authorKakaoId;
  final String authorName;
  final String authorUid;
  final String profileImageUrl;
  final String content;
  final int? parentCommentId;
  final String createdAt;
  final bool mine;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorKakaoId,
    required this.authorName,
    required this.authorUid,
    required this.profileImageUrl,
    required this.content,
    required this.parentCommentId,
    required this.createdAt,
    required this.mine,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    int readInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    String readString(dynamic value, {String fallback = ''}) {
      if (value == null) return fallback;
      final text = value.toString().trim();
      return text.isEmpty ? fallback : text;
    }

    bool readBool(dynamic value, {bool fallback = false}) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
      return fallback;
    }

    return CommunityComment(
      id: readInt(json['id']),
      postId: readInt(json['postId']),
      authorKakaoId: json['authorKakaoId'] == null ? null : readInt(json['authorKakaoId']),
      authorName: readString(json['authorName'], fallback: '사용자'),
      authorUid: readString(json['authorUid'], fallback: 'UID'),
      profileImageUrl: readString(json['profileImageUrl']),
      content: readString(json['content']),
      parentCommentId: json['parentCommentId'] == null ? null : readInt(json['parentCommentId']),
      createdAt: readString(json['createdAt']),
      mine: readBool(json['mine']),
    );
  }
}

class _TagChipStyle {
  final Color background;
  final Color border;
  final Color text;
  final Color selectedBackground;
  final Color selectedBorder;
  final Color selectedText;

  const _TagChipStyle({
    required this.background,
    required this.border,
    required this.text,
    required this.selectedBackground,
    required this.selectedBorder,
    required this.selectedText,
  });
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const String _baseUrl = 'http://161.33.30.40:8080';

  final ScrollController _scrollController = ScrollController();
  late final PageController _feedModePageController;
  static const int _virtualInitialPage = 1000;
  int _currentFeedPage = _virtualInitialPage;

  final TextEditingController _commentController = TextEditingController();
  final Map<int, List<CommunityComment>> _commentsByPostId = <int, List<CommunityComment>>{};

  bool _didOpenInitialPost = false;

  bool _showTopButton = false;
  bool _isGridView = true;
  bool _isFilterPanelOpen = false;
  bool _showLikedOnly = false;
  bool _isLoading = false;
  String? _errorMessage;

  final Set<String> _selectedTags = <String>{'전체'};
  CommunitySortType _sortType = CommunitySortType.latest;
  List<CommunityPost> _posts = <CommunityPost>[];
  List<CommunityTagItem> _tagItems = const <CommunityTagItem>[];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _currentFeedPage = _virtualInitialPage + (_isGridView ? 1 : 0);
    _feedModePageController = PageController(initialPage: _currentFeedPage);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _fetchTags(),
      _fetchPosts(),
    ]);
  }

  Future<void> _fetchTags() async {
    try {
      final tags = await CommunityTagApiService.fetchActiveTags();
      if (!mounted) return;
      setState(() {
        _tagItems = tags;
      });
    } catch (e) {
      debugPrint('태그 불러오기 실패: $e');
    }
  }

  @override
  void didUpdateWidget(covariant CommunityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.kakaoId != oldWidget.kakaoId) {
      _fetchPosts();
    }

    if (widget.initialPostId != oldWidget.initialPostId) {
      _didOpenInitialPost = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryOpenInitialPost();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _feedModePageController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  _TagChipStyle _tagChipStyle(String text) {
    switch (text) {
      case '인테리어':
        return const _TagChipStyle(
          background: Color(0xFFFFF4EF),
          border: Color(0xFFF7D8CC),
          text: Color(0xFFD97A5D),
          selectedBackground: Color(0xFFFFE8DF),
          selectedBorder: Color(0xFFF1BEAA),
          selectedText: Color(0xFFC96547),
        );
      case '익스테리어':
        return const _TagChipStyle(
          background: Color(0xFFF3FAF6),
          border: Color(0xFFD8EEDD),
          text: Color(0xFF5E9D74),
          selectedBackground: Color(0xFFE5F5EB),
          selectedBorder: Color(0xFFBFE2CB),
          selectedText: Color(0xFF43885B),
        );
      case '코디':
        return const _TagChipStyle(
          background: Color(0xFFFFF4FA),
          border: Color(0xFFF1D7E8),
          text: Color(0xFFC56C9D),
          selectedBackground: Color(0xFFFFE8F4),
          selectedBorder: Color(0xFFEAB8D6),
          selectedText: Color(0xFFB75689),
        );
      case '반려동물':
        return const _TagChipStyle(
          background: Color(0xFFF8F3FF),
          border: Color(0xFFE2D8F5),
          text: Color(0xFF8B73C7),
          selectedBackground: Color(0xFFEEE7FF),
          selectedBorder: Color(0xFFD1C2F0),
          selectedText: Color(0xFF775BB8),
        );
      case '도트 도안':
        return const _TagChipStyle(
          background: Color(0xFFFFF9EE),
          border: Color(0xFFF2E4BE),
          text: Color(0xFFC59A34),
          selectedBackground: Color(0xFFFFF2D9),
          selectedBorder: Color(0xFFEBCF8D),
          selectedText: Color(0xFFB78718),
        );
      case '꿀팁 영상':
        return const _TagChipStyle(
          background: Color(0xFFEFF8FF),
          border: Color(0xFFD2E8F8),
          text: Color(0xFF5B95BA),
          selectedBackground: Color(0xFFE1F1FC),
          selectedBorder: Color(0xFFB6DBF2),
          selectedText: Color(0xFF427FA7),
        );
      case '공략':
        return const _TagChipStyle(
          background: Color(0xFFEFF6FF),
          border: Color(0xFFD6E4FF),
          text: Color(0xFF4A7BD0),
          selectedBackground: Color(0xFFE3EDFF),
          selectedBorder: Color(0xFFBFD4FF),
          selectedText: Color(0xFF2F5FBF),
        );
      case '전체':
      default:
        return const _TagChipStyle(
          background: Color(0xFFFBF8F6),
          border: Color(0xFFECE3DD),
          text: Color(0xFF9A8C82),
          selectedBackground: Color(0xFFF4EEEA),
          selectedBorder: Color(0xFFE2D5CC),
          selectedText: Color(0xFF7B6D64),
        );

    }
  }

  List<String> get _availableTagNames =>
      _tagItems.map((e) => e.tagName).where((e) => e.trim().isNotEmpty).toList();


  Color _postBorderColor(CommunityPost post) {
    if (post.mine) return const Color(0xFF8EDBC2);
    if (post.isAdminPick) return const Color(0xFFFFB3A4);
    if (post.isFollowingAuthor) return const Color(0xFFF3D36B);
    return const Color(0xFFCFE59A);
  }

  String _formatMetaCreatedLabel(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    final now = DateTime.now();
    final local = parsed.toLocal();
    final sameDay = now.year == local.year && now.month == local.month && now.day == local.day;
    if (sameDay) {
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}';
  }

  Widget _buildPostMetaLine(CommunityPost post, {double fontSize = 11.3}) {
    final bool showLock = post.mine && post.lockedByOwner;
    final String lockLabel = post.visibility == 'PRIVATE' ? '나만보기' : '팔로워에게만';
    final String timeLabel = _formatMetaCreatedLabel(post.createdLabel);
    return Row(
      children: [
        Flexible(
          child: Text(
            'UID . ${post.uid}${timeLabel.isNotEmpty ? ' · $timeLabel' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF95A0AE),
            ),
          ),
        ),
        if (showLock) ...[
          const SizedBox(width: 6),
          const Icon(Icons.lock_rounded, size: 12, color: Color(0xFFB08A7D)),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              lockLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize - 0.1,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB08A7D),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<List<CommunityComment>> _fetchComments(int postId) async {
    final uri = Uri.parse('$_baseUrl/api/community/posts/$postId/comments').replace(
      queryParameters: <String, String>{
        if ((widget.kakaoId ?? '').isNotEmpty) 'kakaoId': widget.kakaoId!,
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('댓글 조회 실패 (${response.statusCode})');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) return const <CommunityComment>[];
    return decoded
        .whereType<Map>()
        .map((e) => CommunityComment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _sharePostToKakao(CommunityPost post) async {
    final Uri webUrl = Uri.parse(
      'https://keepersnote.app/community/post/${post.id}',
    );

    final FeedTemplate template = FeedTemplate(
      content: Content(
        title: post.title.isNotEmpty ? post.title : '키퍼노트 커뮤니티 글',
        description: '🌈 타운키퍼 모여라! 💖\n지금 키퍼노트에서 이 글을 확인해보세요! 👀💬',
        imageUrl: Uri.parse(
          post.imageUrls.isNotEmpty
              ? _resolveImagePath(post.imageUrls.first).startsWith('http')
              ? _resolveImagePath(post.imageUrls.first)
              : 'https://keepersnote.app/assets/images/share_default.png'
              : 'https://keepersnote.app/assets/images/share_default.png',
        ),
        link: Link(
          webUrl: webUrl,
          mobileWebUrl: webUrl,
          androidExecutionParams: {
            'target': 'community_post',
            'postId': post.id.toString(),
          },
          iosExecutionParams: {
            'target': 'community_post',
            'postId': post.id.toString(),
          },
        ),
      ),
      buttons: [
        Button(
          title: '앱에서 보기',
          link: Link(
            webUrl: webUrl,
            mobileWebUrl: webUrl,
            androidExecutionParams: {
              'target': 'community_post',
              'postId': post.id.toString(),
            },
            iosExecutionParams: {
              'target': 'community_post',
              'postId': post.id.toString(),
            },
          ),
        ),
      ],
    );

    if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
      final Uri uri = await ShareClient.instance.shareDefault(template: template);
      await ShareClient.instance.launchKakaoTalk(uri);
    } else {
      // 카카오톡 미설치 시 브라우저 공유 fallback
      await Share.share(
        '''🌈 타운키퍼 모여라! 💖

📌 ${post.title}

두근두근타운 유저들을 위한 필수 앱  
✨ 키퍼노트 ✨ 에서 이 글을 발견했어요!

지금 바로 확인해보세요! 👀💬

📎 https://keepersnote.app/community/post/${post.id}
''',
      );
    }
  }

  Future<void> _fetchPosts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('$_baseUrl/api/community/posts').replace(
        queryParameters: <String, String>{
          'sort': _sortType == CommunitySortType.popular ? 'POPULAR' : 'LATEST',
          if (!_selectedTags.contains('전체') && _selectedTags.isNotEmpty)
            'tag': _selectedTags.join(','),
          if (_showLikedOnly) 'likedOnly': 'true',
          if ((widget.kakaoId ?? '').isNotEmpty) 'kakaoId': widget.kakaoId!,
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('게시글 조회 실패 (${response.statusCode})');
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
        } else {
          throw Exception('응답 형식이 올바르지 않아요.');
        }
      } else {
        throw Exception('응답 형식이 올바르지 않아요.');
      }

      final List<CommunityPost> posts = rawList
          .whereType<Map>()
          .map((e) => CommunityPost.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted) return;

      setState(() {
        _posts = posts;
      });

      _tryOpenInitialPost();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage = '서버 응답이 지연되고 있어요. 잠시 후 다시 시도해주세요.';
        _posts = <CommunityPost>[];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _posts = <CommunityPost>[];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openShareOptions(CommunityPost post) async {
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
                            '공유하기',
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
                  _buildPostActionTile(
                    icon: Icons.chat_bubble_rounded,
                    iconBg: const Color(0xFFFFF7D8),
                    iconColor: const Color(0xFFE0B100),
                    title: '카카오톡으로 공유',
                    subtitle: '카카오톡으로 이 글을 공유해보세요.',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _sharePostToKakao(post);
                    },
                  ),
                  _buildPostActionTile(
                    icon: Icons.ios_share_rounded,
                    iconBg: const Color(0xFFFFF4EE),
                    iconColor: const Color(0xFFFF8E7C),
                    title: '다른 앱으로 공유',
                    subtitle: '디스코드, 인스타그램 등으로 공유해보세요.',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _sharePostWithDeepLink(post);
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

  Future<CommunityPost?> _fetchPostDetail(int postId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/community/posts/$postId').replace(
        queryParameters: <String, String>{
          if ((widget.kakaoId ?? '').isNotEmpty) 'kakaoId': widget.kakaoId!,
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return CommunityPost.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _tryOpenInitialPost() async {
    final int? postId = widget.initialPostId;

    if (!mounted || _didOpenInitialPost || postId == null) {
      return;
    }

    if (_isLoading) {
      return;
    }

    CommunityPost? targetPost;

    final int index = _posts.indexWhere((e) => e.id == postId);
    if (index >= 0) {
      targetPost = _posts[index];
    } else {
      targetPost = await _fetchPostDetail(postId);
    }

    if (!mounted || targetPost == null) {
      return;
    }

    _didOpenInitialPost = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;

      _openPostDetailSheet(targetPost!);
    });
  }

  Future<void> _onRefresh() => _fetchPosts();

  void _handleScroll() {
    final show = _scrollController.offset > 160;
    if (show != _showTopButton) {
      setState(() {
        _showTopButton = show;
      });
    }
  }

  Future<void> _openPostMoreSheet(CommunityPost post) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.mine ? '내 게시글 관리' : '게시글 메뉴',
                            style: const TextStyle(
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

                  _buildPostActionTile(
                    icon: Icons.ios_share_rounded,
                    iconBg: const Color(0xFFFFF4EE),
                    iconColor: const Color(0xFFFF8E7C),
                    title: '공유하기',
                    subtitle: '카카오톡 또는 다른 앱으로 공유해요',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _openShareOptions(post);
                    },
                  ),

                  if (post.mine) ...[
                    _buildPostActionTile(
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
                    _buildPostActionTile(
                      icon: Icons.delete_rounded,
                      iconBg: const Color(0xFFFFF1F1),
                      iconColor: const Color(0xFFE46C6C),
                      title: '글 삭제',
                      subtitle: '내 게시글을 삭제해요',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _confirmDeletePost(post);
                      },
                    ),
                  ] else
                    _buildPostActionTile(
                      icon: Icons.flag_rounded,
                      iconBg: const Color(0xFFFFF1F1),
                      iconColor: const Color(0xFFE46C6C),
                      title: '신고하기',
                      subtitle: '부적절한 게시글을 신고해요',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _openReportSheet(post);
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

  Future<void> _openEditPost(CommunityPost post) async {
    if ((widget.kakaoId ?? '').isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 필요해요.')),
      );
      return;
    }

    final List<String> availableTags = _availableTagNames.isNotEmpty
        ? _availableTagNames
        : const <String>['전체'];

    final bool? updated = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommunityWriteScreen(
          kakaoId: widget.kakaoId!,
          availableTags: availableTags,
          isEditMode: true,
          editingPostId: post.id,
          initialTitle: post.title,
          initialBody: post.body,
          initialTags: post.tags,
          initialImageUrls: post.imageUrls,
          initialVisibility: post.visibility,
        ),
      ),
    );

    if (updated == true) {
      await _fetchPosts();
    }
  }

  Widget _buildDetailActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1E4DE)),
          ),
          child: Icon(
            icon,
            size: 21,
            color: const Color(0xFF8C7C74),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost(CommunityPost post) async {
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _deletePost(post);
  }

  Future<void> _deletePost(CommunityPost post) async {
    if ((widget.kakaoId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 필요해요.')),
      );
      return;
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/community/posts/${post.id}').replace(
        queryParameters: <String, String>{
          'kakaoId': widget.kakaoId!,
        },
      );

      final response = await http.delete(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('게시글 삭제 실패 (${response.statusCode})');
      }

      if (!mounted) return;
      setState(() {
        _posts.removeWhere((e) => e.id == post.id);
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

  Widget _buildPostActionTile({
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
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
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

  Future<void> _openReportSheet(CommunityPost post) async {
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        const reasons = <String>[
          '스팸 / 광고',
          '욕설 / 혐오 표현',
          '부적절한 이미지',
          '도배 / 반복 게시',
          '기타',
        ];

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFF0E3DC)),
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
                            '신고 사유 선택',
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
                  const SizedBox(height: 8),
                  ...reasons.map(
                        (reason) => Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(sheetContext, reason),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF8E7C),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: const TextStyle(
                                    fontSize: 13.8,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF493D39),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (reason == null || reason.isEmpty) return;
    await _submitReport(post, reason);
  }

  Future<void> _submitReport(CommunityPost post, String reason) async {
    if ((widget.kakaoId ?? '').isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 필요해요.')),
      );
      return;
    }

    try {
      final response = await http
          .post(
        Uri.parse('$_baseUrl/api/community/reports'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'postId': post.id,
          'kakaoId': int.tryParse(widget.kakaoId ?? ''),
          'reasonCode': reason,
          'detailText': null,
        }),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final bodyText = utf8.decode(response.bodyBytes);
        throw Exception('신고 접수 실패 (${response.statusCode})\n$bodyText');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신고가 접수되었어요. ($reason)')),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 응답이 지연되고 있어요. 잠시 후 다시 시도해주세요.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신고 접수 중 문제가 발생했어요. $e')),
      );
    }
  }

  Widget _buildMoreButton({
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF2E3DE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
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

  Future<void> _toggleLike(int postId) async {
    final index = _posts.indexWhere((e) => e.id == postId);
    if (index < 0) return;

    final current = _posts[index];
    final nextLiked = !current.likedByMe;
    final nextCount = current.likeCount + (nextLiked ? 1 : -1);

    setState(() {
      _posts[index] = current.copyWith(
        likedByMe: nextLiked,
        likeCount: nextCount < 0 ? 0 : nextCount,
      );
    });

    try {
      final uri = Uri.parse('$_baseUrl/api/community/posts/$postId/like').replace(
        queryParameters: <String, String>{
          if ((widget.kakaoId ?? '').isNotEmpty) 'kakaoId': widget.kakaoId!,
        },
      );
      final response = await http.post(uri);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('좋아요 처리 실패');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final liked = decoded is Map<String, dynamic>
          ? (decoded['liked'] == true || decoded['liked'] == 1)
          : nextLiked;
      final likeCount = decoded is Map<String, dynamic>
          ? ((decoded['likeCount'] as num?)?.toInt() ?? nextCount)
          : nextCount;

      if (!mounted) return;
      setState(() {
        _posts[index] = current.copyWith(
          likedByMe: liked,
          likeCount: likeCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts[index] = current;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('좋아요 처리 중 문제가 발생했어요.')),
      );
    }
  }

  void _toggleTagSelection(String tag) {
    setState(() {
      if (tag == '전체') {
        _selectedTags
          ..clear()
          ..add('전체');
        return;
      }

      _selectedTags.remove('전체');

      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }

      if (_selectedTags.isEmpty) {
        _selectedTags.add('전체');
      }
    });

    _fetchPosts();
  }

  void _toggleViewMode() {
    final nextIsGrid = !_isGridView;
    setState(() {
      _isGridView = nextIsGrid;
    });
    _moveToFeedMode(nextIsGrid);
  }

  void _toggleFilterPanel() {
    setState(() {
      _isFilterPanelOpen = !_isFilterPanelOpen;
    });
  }

  void _closeFilterPanel() {
    if (_isFilterPanelOpen) {
      setState(() {
        _isFilterPanelOpen = false;
      });
    }
  }

  int _pageToMode(int page) => page.isEven ? 0 : 1; // 0=list, 1=grid

  void _moveToFeedMode(bool grid) {
    final int currentMode = _pageToMode(_currentFeedPage);
    final int targetMode = grid ? 1 : 0;

    if (currentMode == targetMode) return;

    final int nextPage = _currentFeedPage + 1;

    _feedModePageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _openImageViewer(CommunityPost post, {int initialIndex = 0}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.94),
        pageBuilder: (_, __, ___) => _CommunityImageViewerScreen(
          post: post,
          initialIndex: initialIndex,
          resolveImagePath: _resolveImagePath,
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

  void _openProfileImageViewer(CommunityPost post) {
    final resolved = _resolveProfileImagePath(post.profileImageUrl);
    if (resolved.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.94),
        pageBuilder: (_, __, ___) => _ProfileImageViewerScreen(
          imageUrl: resolved,
          author: post.author,
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

  Widget _buildFilterChip(
      String text,
      bool selected,
      VoidCallback onTap, {
        bool isHashTag = false,
      }) {
    final label = isHashTag && text != '전체' ? '#$text' : text;
    final style = _tagChipStyle(text);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? style.selectedBackground.withOpacity(1.0)
                : style.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? style.selectedText.withOpacity(0.55)
                  : style.border,
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.6,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
              color: selected ? style.selectedText : style.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentTagChip(
      String text, {
        bool compact = false,
        bool pill = false,
        bool tiny = false,
      }) {
    final style = _tagChipStyle(text);

    final double horizontal = tiny
        ? 8
        : (compact ? 10 : 12);
    final double vertical = tiny
        ? 5
        : (compact ? 6 : 7);
    final double fontSize = tiny
        ? 10.4
        : (compact ? 11.2 : 12.2);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: vertical,
      ),
      decoration: BoxDecoration(
        color: style.selectedBackground,
        borderRadius: BorderRadius.circular(
          pill ? 999 : (compact || tiny ? 999 : 12),
        ),
        border: Border.all(color: style.selectedBorder),
      ),
      child: Text(
        '#$text',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: style.selectedText,
          height: 1.0,
        ),
      ),
    );
  }

  List<CommunityPost> _filteredPosts() => List<CommunityPost>.from(_posts);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topPadding = media.padding.top;
    const appBarContentHeight = 34.0;
    const appBarBottomPadding = 14.0;
    final appBarTotalHeight =
        topPadding + 10 + appBarContentHeight + appBarBottomPadding;
    final posts = _filteredPosts();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F6),
      body: SafeArea(
        top: false,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Image.asset(
                'assets/images/bg_gradient.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              top: appBarTotalHeight,
              child: PageView.builder(
                controller: _feedModePageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentFeedPage = index;
                    _isGridView = _pageToMode(index) == 1;
                  });
                },
                itemBuilder: (_, index) {
                  final bool showGrid = _pageToMode(index) == 1;
                  return showGrid
                      ? RefreshIndicator(
                    color: const Color(0xFFFF8E7C),
                    backgroundColor: Colors.white,
                    edgeOffset: 6,
                    displacement: 24,
                    onRefresh: _onRefresh,
                    child: _buildPinterestFeed(posts),
                  )
                      : RefreshIndicator(
                    color: const Color(0xFFFF8E7C),
                    backgroundColor: Colors.white,
                    edgeOffset: 6,
                    displacement: 24,
                    onRefresh: _onRefresh,
                    child: _buildListFeed(posts),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildCustomAppBar(context, topPadding),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isFilterPanelOpen,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  opacity: _isFilterPanelOpen ? 1 : 0,
                  child: GestureDetector(
                    onTap: _closeFilterPanel,
                    child: Container(color: Colors.black.withOpacity(0.18)),
                  ),
                ),
              ),
            ),
            _buildFilterSidePanel(topPadding),
            if (_isLoading && _posts.isEmpty)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66FFF8F5),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF8E7C),
                    ),
                  ),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              right: 20,
              bottom: _showTopButton ? 104 : 78,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showTopButton ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_showTopButton,
                  child: _buildScrollToTopButton(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSidePanel(double topPadding) {
    final List<String> filterTags =
    _availableTagNames.where((tag) => tag != '전체').toList();

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: _isFilterPanelOpen ? Curves.easeOutQuad : Curves.easeInCubic,
      top: topPadding + 118,
      right: _isFilterPanelOpen ? 12 : -340,
      child: IgnorePointer(
        ignoring: !_isFilterPanelOpen,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          opacity: _isFilterPanelOpen ? 1 : 0.85,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 272,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.992),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF0E3DC)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            '정렬 및 필터',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF443834),
                            ),
                          ),
                        ),
                        _buildPanelIconButton(
                          icon: Icons.close_rounded,
                          onTap: _closeFilterPanel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '정렬',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6E625D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _buildSortChip(
                          '최신순',
                          _sortType == CommunitySortType.latest,
                              () {
                            setState(() => _sortType = CommunitySortType.latest);
                            _fetchPosts();
                          },
                        ),
                        _buildSortChip(
                          '인기순',
                          _sortType == CommunitySortType.popular,
                              () {
                            setState(() => _sortType = CommunitySortType.popular);
                            _fetchPosts();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '필터',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6E625D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _buildFilterChip(
                          '전체',
                          _selectedTags.contains('전체'),
                              () => _toggleTagSelection('전체'),
                          isHashTag: true,
                        ),
                        _buildLikedFilterChip(),
                        ...filterTags.map(
                              (tag) => _buildFilterChip(
                            tag,
                            _selectedTags.contains(tag),
                                () => _toggleTagSelection(tag),
                            isHashTag: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _sortType = CommunitySortType.latest;
                                _selectedTags
                                  ..clear()
                                  ..add('전체');
                                _showLikedOnly = false;
                              });
                              _fetchPosts();
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE7DBD3)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              foregroundColor: const Color(0xFF8A7B71),
                            ),
                            child: const Text(
                              '초기화',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _closeFilterPanel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8E7C),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              '적용',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
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
          ),
        ),
      ),
    );
  }

  Widget _buildLikedFilterChip() {
    final selected = _showLikedOnly;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _showLikedOnly = !_showLikedOnly);
          _fetchPosts();
        },
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFEEF1)
                : const Color(0xFFFFF7F8),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE25476).withOpacity(0.55)
                  : const Color(0xFFF3D8DE),
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                selected
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 13,
                color: selected
                    ? const Color(0xFFE25476)
                    : const Color(0xFFD98A9D),
              ),
              const SizedBox(width: 5),
              Text(
                '좋아요',
                style: TextStyle(
                  fontSize: 11.6,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                  color: selected
                      ? const Color(0xFFE25476)
                      : const Color(0xFFBF7A8E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String text, bool selected, VoidCallback onTap) {
    final bg = selected ? const Color(0xFFFFF1CC) : const Color(0xFFFFFBF2);
    final border = selected ? const Color(0xFFF2D48B) : const Color(0xFFF1E4BF);
    final textColor = selected ? const Color(0xFF9C6B00) : const Color(0xFFB08A3C);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.6,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFFFF8F5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF2E3DC)),
          ),
          child: Icon(
            icon,
            size: 16,
            color: const Color(0xFFFF8E7C),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, double topPadding) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF8E7C).withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFF8E7C).withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 14),
                  child: Row(
                    children: <Widget>[
                      _buildIconAppBarButton(
                        icon: _isGridView
                            ? Icons.view_stream_rounded
                            : Icons.grid_view_rounded,
                        onTap: _toggleViewMode,
                        isAccent: true,
                      ),
                      const Spacer(),
                      _buildAppTitle(),
                      const Spacer(),
                      _buildIconAppBarButton(
                        icon: Icons.tune_rounded,
                        onTap: _toggleFilterPanel,
                        isActive: _isFilterPanelOpen,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 18,
                  right: 18,
                  child: IgnorePointer(
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8E7C).withOpacity(0.62),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(3),
                        ),
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

  Widget _buildAppTitle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          "Keeper's Feed",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2D3436),
            letterSpacing: -0.3,
            fontFamily: 'SF Pro',
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFFFF8E7C).withOpacity(0.78),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildIconAppBarButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isAccent = false,
    bool isActive = false,
  }) {
    return Material(
      color: isAccent || isActive
          ? const Color(0xFFFFF3F0)
          : const Color(0xFFFFFBFA),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAccent || isActive
                  ? const Color(0xFFFFE2DB)
                  : const Color(0xFFF2E3DE),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color: const Color(0xFFFF8E7C),
          ),
        ),
      ),
    );
  }

  Widget _buildListFeed(List<CommunityPost> posts) {
    if (_errorMessage != null) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 132),
        children: <Widget>[_buildErrorState()],
      );
    }

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 132),
      children: <Widget>[
        if (posts.isEmpty)
          _buildEmptyState()
        else
          ...posts.map<Widget>((post) => _buildPostCard(post)),
      ],
    );
  }

  Widget _buildPinterestFeed(List<CommunityPost> posts) {
    if (_errorMessage != null) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 132),
        children: <Widget>[_buildErrorState()],
      );
    }

    if (posts.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 132),
        children: <Widget>[_buildEmptyState()],
      );
    }

    final leftColumn = <CommunityPost>[];
    final rightColumn = <CommunityPost>[];
    double leftScore = 0;
    double rightScore = 0;

    for (int i = 0; i < posts.length; i++) {
      final post = posts[i];
      final double score = _gridMasonryScore(post, i);

      final bool forceLeftHeavy = i % 7 == 0 || i % 7 == 1;
      final bool forceRightHeavy = i % 9 == 0;

      if (forceLeftHeavy) {
        leftColumn.add(post);
        leftScore += score;
        continue;
      }

      if (forceRightHeavy) {
        rightColumn.add(post);
        rightScore += score;
        continue;
      }

      final double gap = (leftScore - rightScore).abs();

      if (gap < 0.55) {
        if (i.isEven) {
          leftColumn.add(post);
          leftScore += score;
        } else {
          rightColumn.add(post);
          rightScore += score;
        }
      } else if (leftScore < rightScore) {
        leftColumn.add(post);
        leftScore += score;
      } else {
        rightColumn.add(post);
        rightScore += score;
      }
    }

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 132),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              children: leftColumn
                  .asMap()
                  .entries
                  .map<Widget>((e) => _buildGridCard(e.value, e.key))
                  .toList(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: rightColumn
                  .asMap()
                  .entries
                  .map<Widget>((e) => _buildGridCard(e.value, e.key + 1))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  double _gridMasonryScore(CommunityPost post, int index) {
    double score = 1.0;

    const pattern = <double>[
      0.0,
      0.28,
      0.55,
      0.12,
      0.42,
      0.78,
      0.18,
      0.62,
    ];

    score += pattern[(post.id + index) % pattern.length];
    score += post.imageUrls.length * 0.22;

    if (post.hasYoutube) score += 0.35;
    if (post.title.length > 18) score += 0.14;
    if (post.body.length > 40) score += 0.18;
    if (post.body.length > 90) score += 0.22;

    return score;
  }

  double _gridAspectRatioForIndex(int index, CommunityPost post) {
    const baseRatios = <double>[
      0.62,
      0.74,
      0.88,
      1.02,
      1.18,
      1.34,
      0.70,
      1.26,
    ];

    double seed = baseRatios[(post.id + index) % baseRatios.length];

    if (post.hasYoutube) {
      return 0.68;
    }

    if (post.imageUrls.length >= 3) {
      seed -= 0.12;
    } else if (post.imageUrls.length == 2) {
      seed -= 0.06;
    }

    if (post.body.length > 70) {
      seed -= 0.08;
    }

    return seed.clamp(0.58, 1.38);
  }

  Widget _buildPostCard(CommunityPost post) {
    final bool liked = post.likedByMe;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _postBorderColor(post), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.028),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openPostDetailSheet(post),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 10),
                  child: Row(
                    children: <Widget>[
                      _buildProfileAvatar(post, radius: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    post.author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.2,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2F3941),
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ),
                                if (post.isAdminPick) ...[
                                  const SizedBox(width: 6),
                                  _buildVerifiedBadge(),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            _buildPostMetaLine(post, fontSize: 11.3),
                          ],
                        ),
                      ),
                      _buildMoreButton(onTap: () => _openPostMoreSheet(post)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _PostImageCarousel(
                      post: post,
                      baseUrl: _baseUrl,
                      showLeadingTag: false,
                      useIntrinsicAspectRatio: true,
                      onTapImage: (index) => _openImageViewer(post, initialIndex: index),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              post.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3C444B),
                                letterSpacing: -0.15,
                              ),
                            ),
                          ),
                          if (post.tags.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: post.tags.take(2).map((tag) => _buildContentTagChip(tag, compact: true)).toList(),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildCommentButton(count: post.commentCount),
                          const Spacer(),
                          _buildLikeButton(
                            liked: liked,
                            count: post.likeCount,
                            onTap: () => _toggleLike(post.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolveProfileImagePath(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return '$_baseUrl$path';
    return '$_baseUrl/$path';
  }

  Widget _buildProfileAvatar(
      CommunityPost post, {
        double radius = 18,
        bool enableTap = true,
      }) {
    final resolved = _resolveProfileImagePath(post.profileImageUrl);

    Widget fallback = CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFF2EE),
      child: Text(
        post.author.isEmpty ? '?' : post.author.characters.first,
        style: TextStyle(
          color: const Color(0xFFFF8E7C),
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.9,
        ),
      ),
    );

    Widget avatar;

    if (resolved.isEmpty) {
      avatar = fallback;
    } else {
      avatar = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFF2EE),
          border: Border.all(color: const Color(0xFFFFE1DA)),
        ),
        child: ClipOval(
          child: Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          ),
        ),
      );
    }

    if (!enableTap) return avatar;

    return GestureDetector(
      onTap: () => _openProfileImageViewer(post),
      child: avatar,
    );
  }

  Widget _buildCommentAvatar(CommunityComment comment, {double radius = 16}) {
    final resolved = _resolveProfileImagePath(comment.profileImageUrl);
    if (resolved.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFFFF2EE),
        child: Text(
          comment.authorName.isEmpty ? '?' : comment.authorName.characters.first,
          style: TextStyle(
            color: const Color(0xFFFF8E7C),
            fontWeight: FontWeight.w800,
            fontSize: radius * 0.85,
          ),
        ),
      );
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFF2EE),
        border: Border.all(color: const Color(0xFFFFE1DA)),
      ),
      child: ClipOval(
        child: Image.network(
          resolved,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFFFF2EE),
            child: Text(
              comment.authorName.isEmpty ? '?' : comment.authorName.characters.first,
              style: TextStyle(
                color: const Color(0xFFFF8E7C),
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.85,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resolveImagePath(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return '$_baseUrl$path';
    if (path.startsWith('assets/')) return path;
    return path;
  }

  Widget _buildPostImage(String path) {
    final resolved = _resolveImagePath(path);

    if (resolved.isEmpty) {
      return _buildImageFallback();
    }

    if (resolved.startsWith('http')) {
      return Image.network(
        resolved,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFFFF6F2),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Color(0xFFFF8E7C),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _buildImageFallback(),
      );
    }

    return Image.asset(
      resolved,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildImageFallback(),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: const Color(0xFFFFF6F2),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 30,
        color: Color(0xFFE1B3A8),
      ),
    );
  }

  Widget _buildGridCard(CommunityPost post, int index) {
    final bool liked = post.likedByMe;
    final double aspectRatio = _gridAspectRatioForIndex(index, post);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1E4DE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.028),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openPostDetailSheet(post),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: <Widget>[
                        _PostImageCarousel(
                          post: post,
                          baseUrl: _baseUrl,
                          fixedAspectRatio: aspectRatio,
                          showLeadingTag: false,
                          useIntrinsicAspectRatio: false,
                          onTapImage: (imageIndex) {
                            _openImageViewer(post, initialIndex: imageIndex);
                          },
                        ),
                        Positioned(
                          top: 7,
                          left: 8,
                          child: _buildGridMoreButton(
                            onTap: () => _openPostMoreSheet(post),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: _buildGridLikeButton(
                            liked: liked,
                            onTap: () => _toggleLike(post.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: post.tags.isNotEmpty
                              ? _buildContentTagChip(
                            post.tags.first,
                            tiny: true,
                          )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      if (post.isAdminPick) _buildVerifiedBadge(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPostDetailSheet(CommunityPost post) async {
    _commentController.clear();
    Future<List<CommunityComment>> commentsFuture = _fetchComments(post.id);
    bool localSubmitting = false;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'post_detail',
      barrierColor: Colors.black.withOpacity(0.16),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        final media = MediaQuery.of(context);
        final maxCardHeight = media.size.height * 0.82;

        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 540, maxHeight: maxCardHeight),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.98),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _postBorderColor(post), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: StatefulBuilder(
                      builder: (context, setSheetState) {
                        Future<void> refreshComments() async {
                          setSheetState(() {
                            commentsFuture = _fetchComments(post.id);
                          });
                          final comments = await commentsFuture;
                          _commentsByPostId[post.id] = comments;
                          final index = _posts.indexWhere((e) => e.id == post.id);
                          if (index >= 0 && mounted) {
                            setState(() {
                              _posts[index] = _posts[index].copyWith(commentCount: comments.length);
                            });
                          }
                        }

                        Future<void> submitLocalComment() async {
                          final text = _commentController.text.trim();
                          if (text.isEmpty) {
                            _showSnackBar('댓글 내용을 입력해주세요.');
                            return;
                          }
                          if ((widget.kakaoId ?? '').isEmpty) {
                            _showSnackBar('로그인 정보가 필요해요.');
                            return;
                          }

                          setSheetState(() {
                            localSubmitting = true;
                          });
                          try {
                            final response = await http.post(
                              Uri.parse('$_baseUrl/api/community/posts/${post.id}/comments'),
                              headers: const {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'kakaoId': int.tryParse(widget.kakaoId ?? ''),
                                'content': text,
                                'parentCommentId': null,
                              }),
                            ).timeout(const Duration(seconds: 10));

                            if (response.statusCode < 200 || response.statusCode >= 300) {
                              throw Exception('댓글 등록 실패 (${response.statusCode})');
                            }
                            _commentController.clear();
                            await refreshComments();
                          } catch (e) {
                            _showSnackBar('댓글 등록 중 문제가 발생했어요. $e');
                          } finally {
                            if (context.mounted) {
                              setSheetState(() {
                                localSubmitting = false;
                              });
                            }
                          }
                        }

                        return FutureBuilder<List<CommunityComment>>(
                          future: commentsFuture,
                          builder: (context, snapshot) {
                            final bool loading = snapshot.connectionState == ConnectionState.waiting;
                            final List<CommunityComment> localComments = snapshot.data ?? _commentsByPostId[post.id] ?? const <CommunityComment>[];

                            return Column(
                              children: [
                                const SizedBox(height: 10),
                                Container(
                                  width: 44,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE9DDD6),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  _buildProfileAvatar(post, radius: 18, enableTap: false),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Flexible(
                                                              child: Text(
                                                                post.author,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(
                                                                  fontSize: 13.6,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: Color(0xFF2F3941),
                                                                ),
                                                              ),
                                                            ),
                                                            if (post.isAdminPick) ...[
                                                              const SizedBox(width: 6),
                                                              _buildVerifiedBadge(),
                                                            ],
                                                          ],
                                                        ),
                                                        const SizedBox(height: 2),
                                                        _buildPostMetaLine(post, fontSize: 11.4),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            _buildDetailActionButton(
                                              icon: Icons.ios_share_rounded,
                                              onTap: () async => _openShareOptions(post),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildDetailActionButton(
                                              icon: Icons.more_vert_rounded,
                                              onTap: () async => _openPostMoreSheet(post),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: _PostImageCarousel(
                                            post: post,
                                            baseUrl: _baseUrl,
                                            showLeadingTag: false,
                                            useIntrinsicAspectRatio: true,
                                            onTapImage: (index) => _openImageViewer(post, initialIndex: index),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                post.title,
                                                style: const TextStyle(
                                                  fontSize: 16.2,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF34414A),
                                                  height: 1.3,
                                                ),
                                              ),
                                            ),
                                            if (post.tags.isNotEmpty) ...[
                                              const SizedBox(width: 10),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: post.tags.take(2).map((tag) => _buildContentTagChip(tag, compact: true)).toList(),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (post.body.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            post.body,
                                            style: const TextStyle(
                                              fontSize: 13.7,
                                              height: 1.58,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF69747F),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            _buildCommentButton(count: localComments.length),
                                            const Spacer(),
                                            _buildLikeButton(
                                              liked: post.likedByMe,
                                              count: post.likeCount,
                                              onTap: () => _toggleLike(post.id),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        const Divider(height: 1, color: Color(0xFFF1E4DE)),
                                        const SizedBox(height: 14),
                                        if (loading)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 16),
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                color: Color(0xFFFF8E7C),
                                              ),
                                            ),
                                          )
                                        else if (localComments.isEmpty)
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(vertical: 20),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBFA),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: const Color(0xFFF1E4DE)),
                                            ),
                                            child: const Text(
                                              '아직 댓글이 없어요.',
                                              style: TextStyle(
                                                fontSize: 12.8,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF98A2AE),
                                              ),
                                            ),
                                          )
                                        else
                                          Column(
                                            children: localComments.map((comment) {
                                              final String commentTime = _formatMetaCreatedLabel(comment.createdAt);
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 14),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    _buildCommentAvatar(comment, radius: 16),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  comment.authorName,
                                                                  style: const TextStyle(
                                                                    fontSize: 12.8,
                                                                    fontWeight: FontWeight.w800,
                                                                    color: Color(0xFF33414B),
                                                                  ),
                                                                ),
                                                              ),
                                                              if (commentTime.isNotEmpty)
                                                                Text(
                                                                  commentTime,
                                                                  style: const TextStyle(
                                                                    fontSize: 10.8,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: Color(0xFF9CA6B2),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            'UID . ${comment.authorUid}',
                                                            style: const TextStyle(
                                                              fontSize: 11.1,
                                                              fontWeight: FontWeight.w700,
                                                              color: Color(0xFF9CA6B2),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 7),
                                                          Container(
                                                            width: double.infinity,
                                                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFFFFBFA),
                                                              borderRadius: BorderRadius.circular(16),
                                                              border: Border.all(color: const Color(0xFFF1E4DE)),
                                                            ),
                                                            child: Text(
                                                              comment.content,
                                                              style: const TextStyle(
                                                                fontSize: 13.2,
                                                                height: 1.45,
                                                                fontWeight: FontWeight.w600,
                                                                color: Color(0xFF5E6975),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      top: BorderSide(color: const Color(0xFFF1E4DE).withOpacity(0.95)),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _commentController,
                                          minLines: 1,
                                          maxLines: 3,
                                          decoration: InputDecoration(
                                            hintText: '댓글을 입력해주세요.',
                                            hintStyle: const TextStyle(
                                              color: Color(0xFFADB5C2),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                            filled: true,
                                            fillColor: const Color(0xFFFFFBFA),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: const BorderSide(color: Color(0xFFF1E4DE)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: const BorderSide(color: Color(0xFFF1E4DE)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: const BorderSide(color: Color(0xFFFFB4A4), width: 1.3),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: localSubmitting ? null : submitLocalComment,
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF8E7C),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: localSubmitting
                                              ? const Padding(
                                            padding: EdgeInsets.all(11),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                              : const Icon(
                                            Icons.send_rounded,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  bool _isTextOverflowingOneLine({
    required String text,
    required TextStyle style,
    required double maxWidth,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);

    return textPainter.didExceedMaxLines;
  }

  Future<void> _sharePostWithDeepLink(CommunityPost post) async {
    final String link = 'https://keepersnote.app/community/post/${post.id}';

    final String text = '''
🌈 타운키퍼 모여라! 💖

📌 ${post.title}

두근두근타운 유저들을 위한 필수 앱  
✨ 키퍼노트 ✨ 에서 이 글을 발견했어요!

지금 바로 확인해보세요! 👀💬

📎 $link
''';

    await Share.share(text);
  }

  Widget _buildGridMoreButton({
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                '⋯',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLikeButton({
    required bool liked,
    required int count,
    required VoidCallback onTap,
  }) {
    return _AnimatedCommunityLikeButton(
      liked: liked,
      onTap: onTap,
      count: count,
      size: 42,
      iconSize: 19,
      backgroundColor: liked
          ? const Color(0xFFFFF2EF)
          : Colors.white.withOpacity(0.94),
      borderColor: liked
          ? const Color(0xFFFFD7CF)
          : const Color(0xFFF2E3DE),
      likedColor: const Color(0xFFFF8E7C),
      idleColor: const Color(0xFFD0A49A),
      countTextColor: liked
          ? const Color(0xFFFF8E7C)
          : const Color(0xFFC19C92),
      circular: false,
      iconTopOffset: 0.0,
      horizontalPadding: 11,
    );
  }

  Widget _buildCommentButton({
    required int count,
  }) {
    return _AnimatedCommunityLikeButton(
      liked: false,
      onTap: () {},
      count: count,
      size: 42,
      iconSize: 19,
      backgroundColor: Colors.white.withOpacity(0.94),
      borderColor: const Color(0xFFF2E3DE),
      likedColor: const Color(0xFF97A3B1),
      idleColor: const Color(0xFFD0A49A),
      countTextColor: const Color(0xFFC19C92),
      circular: false,
      iconTopOffset: 0.0,
      horizontalPadding: 11,
      iconOverride: Icons.chat_bubble_outline_rounded,
      enableTapAnimation: false,
    );
  }

  Widget _buildGridLikeButton({
    required bool liked,
    required VoidCallback onTap,
  }) {
    return _AnimatedCommunityLikeButton(
      liked: liked,
      onTap: onTap,
      size: 30,
      iconSize: 18,
      backgroundColor: Colors.white.withOpacity(0.94),
      borderColor: const Color(0xFFFFE5DE),
      likedColor: const Color(0xFFFF8E7C),
      idleColor: const Color(0xFFD0A49A),
      iconTopOffset: 0.0,
      circular: true,
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: const Color(0xFFFF9F8E),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.92),
          width: 1,
        ),
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 11,
        color: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E2DD)),
      ),
      child: const Column(
        children: <Widget>[
          Icon(
            Icons.forum_outlined,
            size: 34,
            color: Color(0xFFFF8E7C),
          ),
          SizedBox(height: 12),
          Text(
            '조건에 맞는 게시글이 없어요.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3436),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E2DD)),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.cloud_off_rounded,
            size: 34,
            color: Color(0xFFFF8E7C),
          ),
          const SizedBox(height: 12),
          const Text(
            '커뮤니티 글을 불러오지 못했어요.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Color(0xFFC19C92),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _fetchPosts,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        },
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0E1DB)),
          ),
          child: const Icon(
            Icons.keyboard_arrow_up_rounded,
            size: 28,
            color: Color(0xFFFF8E7C),
          ),
        ),
      ),
    );
  }
}

class _PostImageCarousel extends StatefulWidget {
  final CommunityPost post;
  final String baseUrl;
  final double? fixedAspectRatio;
  final bool showLeadingTag;
  final bool useIntrinsicAspectRatio;
  final ValueChanged<int>? onTapImage;

  const _PostImageCarousel({
    required this.post,
    required this.baseUrl,
    this.fixedAspectRatio,
    this.showLeadingTag = false,
    this.useIntrinsicAspectRatio = false,
    this.onTapImage,
  });

  @override
  State<_PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<_PostImageCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;
  final Map<int, double> _aspectRatioCache = <int, double>{};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _precacheAspectRatios();
  }

  @override
  void didUpdateWidget(covariant _PostImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.imageUrls != widget.post.imageUrls) {
      _currentIndex = 0;
      _aspectRatioCache.clear();
      _precacheAspectRatios();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _resolve(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return '${widget.baseUrl}$path';
    return path;
  }

  ImageProvider? _imageProviderFor(String path) {
    final resolved = _resolve(path);
    if (resolved.isEmpty) return null;
    if (resolved.startsWith('http')) {
      return NetworkImage(resolved);
    }
    return AssetImage(resolved);
  }

  Future<void> _readAspectRatio(int index, String path) async {
    final provider = _imageProviderFor(path);
    if (provider == null) return;

    final ImageStream stream = provider.resolve(const ImageConfiguration());
    final Completer<void> completer = Completer<void>();

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
          (ImageInfo image, bool synchronousCall) {
        final width = image.image.width.toDouble();
        final height = image.image.height.toDouble();
        final ratio = height == 0 ? 1.0 : width / height;

        if (mounted) {
          setState(() {
            _aspectRatioCache[index] = ratio.clamp(0.45, 2.4);
          });
        }
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
      onError: (dynamic error, StackTrace? stackTrace) {
        if (mounted) {
          setState(() {
            _aspectRatioCache[index] = 1.0;
          });
        }
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
    );

    stream.addListener(listener);
    await completer.future;
  }

  void _precacheAspectRatios() {
    if (!widget.useIntrinsicAspectRatio) return;
    for (int i = 0; i < widget.post.imageUrls.length; i++) {
      _readAspectRatio(i, widget.post.imageUrls[i]);
    }
  }

  Widget _buildImage(String path) {
    final resolved = _resolve(path);
    final bool useCover = !widget.useIntrinsicAspectRatio;

    Widget fallback = Container(
      color: const Color(0xFFFFF6F2),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 32,
        color: Color(0xFFE1B3A8),
      ),
    );

    if (resolved.isEmpty) {
      return fallback;
    }

    if (resolved.startsWith('http')) {
      if (useCover) {
        return SizedBox.expand(
          child: Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: const Color(0xFFFFFBF9),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFFFF8E7C),
                  ),
                ),
              );
            },
          ),
        );
      }

      return Container(
        color: const Color(0xFFFFFBF9),
        alignment: Alignment.center,
        child: Image.network(
          resolved,
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (_, __, ___) => fallback,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: const Color(0xFFFFFBF9),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Color(0xFFFF8E7C),
                ),
              ),
            );
          },
        ),
      );
    }

    if (useCover) {
      return SizedBox.expand(
        child: Image.asset(
          resolved,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }

    return Container(
      color: const Color(0xFFFFFBF9),
      alignment: Alignment.center,
      child: Image.asset(
        resolved,
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.post.imageUrls;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery
            .of(context)
            .size
            .width;

        double ratio;
        if (widget.useIntrinsicAspectRatio) {
          ratio = _aspectRatioCache[_currentIndex] ?? 1.0;
        } else {
          ratio = widget.fixedAspectRatio ?? 1.0;
        }

        double minHeight;
        double maxHeight;

        if (widget.useIntrinsicAspectRatio) {
          // 리스트뷰: 원본 비율 기반
          minHeight = 110;
          maxHeight = 460;
        } else {
          // 그리드뷰: 최소 높이 보장 + cover 크롭
          minHeight = 150;
          maxHeight = 430;
        }

        final double rawHeight = width / ratio;
        final double height = rawHeight.clamp(minHeight, maxHeight);

        return SizedBox(
          width: double.infinity,
          height: height,
          child: Stack(
            children: <Widget>[
              PageView.builder(
                controller: _pageController,
                itemCount: images.isEmpty ? 1 : images.length,
                onPageChanged: (int index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  if (widget.useIntrinsicAspectRatio &&
                      !_aspectRatioCache.containsKey(index) &&
                      images.isNotEmpty) {
                    _readAspectRatio(index, images[index]);
                  }
                },
                itemBuilder: (_, int index) {
                  return GestureDetector(
                    onTap: () => widget.onTapImage?.call(index),
                    child: _buildImage(images.isEmpty ? '' : images[index]),
                  );
                },
              ),

              if (widget.showLeadingTag && widget.post.tags.isNotEmpty)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFFE2DA)),
                    ),
                    child: Text(
                      widget.post.tags.first,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB18579),
                      ),
                    ),
                  ),
                ),

              if (images.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(
                          images.length, (int index) {
                        final bool selected = index == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: selected ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFF8E7C)
                                : Colors.white.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CommunityImageViewerScreen extends StatefulWidget {
  final CommunityPost post;
  final int initialIndex;
  final String Function(String path) resolveImagePath;

  const _CommunityImageViewerScreen({
    required this.post,
    required this.initialIndex,
    required this.resolveImagePath,
  });

  @override
  State<_CommunityImageViewerScreen> createState() =>
      _CommunityImageViewerScreenState();
}

class _CommunityImageViewerScreenState
    extends State<_CommunityImageViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final TransformationController _transformationController;
  late final AnimationController _zoomAnimationController;

  Animation<Matrix4>? _zoomAnimation;

  late int _currentIndex;
  TapDownDetails? _doubleTapDetails;

  static const double _doubleTapScale = 2.2;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformationController = TransformationController();

    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
      final animation = _zoomAnimation;
      if (animation != null) {
        _transformationController.value = animation.value;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    _zoomAnimationController.dispose();
    super.dispose();
  }

  void _animateZoom(Matrix4 targetMatrix) {
    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(
        parent: _zoomAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _zoomAnimationController
      ..stop()
      ..reset()
      ..forward();
  }

  void _resetZoom() {
    _animateZoom(Matrix4.identity());
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    if (details == null) return;

    final Matrix4 currentMatrix = _transformationController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();

    if (currentScale > 1.01) {
      _resetZoom();
      return;
    }

    final Offset position = details.localPosition;

    final Matrix4 zoomed = Matrix4.identity()
      ..translate(
        -position.dx * (_doubleTapScale - 1),
        -position.dy * (_doubleTapScale - 1),
      )
      ..scale(_doubleTapScale);

    _animateZoom(zoomed);
  }

  Widget _buildImage(String path) {
    final resolved = widget.resolveImagePath(path);

    if (resolved.isEmpty) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 42,
          color: Colors.white54,
        ),
      );
    }

    Widget imageWidget;
    if (resolved.startsWith('http')) {
      imageWidget = Image.network(
        resolved,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            size: 42,
            color: Colors.white54,
          ),
        ),
      );
    } else {
      imageWidget = Image.asset(
        resolved,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            size: 42,
            color: Colors.white54,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (details) {
              _doubleTapDetails = details;
            },
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 4.0,
              panEnabled: true,
              scaleEnabled: true,
              constrained: true,
              clipBehavior: Clip.hardEdge,
              boundaryMargin: EdgeInsets.zero,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Center(child: imageWidget),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.post.imageUrls;

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.96),
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: images.isEmpty ? 1 : images.length,
              onPageChanged: (index) {
                _transformationController.value = Matrix4.identity();
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (_, index) {
                return Center(
                  child: _buildImage(images.isEmpty ? '' : images[index]),
                );
              },
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Material(
                color: Colors.black.withOpacity(0.36),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    _transformationController.value = Matrix4.identity();
                    Navigator.pop(context);
                  },
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
            if (images.length > 1)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCommunityLikeButton extends StatefulWidget {
  final bool liked;
  final VoidCallback onTap;
  final int? count;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color borderColor;
  final Color likedColor;
  final Color idleColor;
  final Color? countTextColor;
  final bool circular;
  final double iconTopOffset;
  final double horizontalPadding;
  final IconData? iconOverride;
  final bool enableTapAnimation;

  const _AnimatedCommunityLikeButton({
    super.key,
    required this.liked,
    required this.onTap,
    this.count,
    required this.size,
    required this.iconSize,
    required this.backgroundColor,
    required this.borderColor,
    required this.likedColor,
    required this.idleColor,
    this.countTextColor,
    required this.circular,
    this.iconTopOffset = 0,
    this.horizontalPadding = 10,
    this.iconOverride,
    this.enableTapAnimation = true,
  });

  @override
  State<_AnimatedCommunityLikeButton> createState() => _AnimatedCommunityLikeButtonState();
}

class _AnimatedCommunityLikeButtonState extends State<_AnimatedCommunityLikeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.circular ? BorderRadius.circular(999) : BorderRadius.circular(19);
    final iconData = widget.iconOverride ?? (widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded);
    final iconColor = widget.liked ? widget.likedColor : widget.idleColor;

    void handleTap() {
      widget.onTap();
    }

    return GestureDetector(
      onTapDown: widget.enableTapAnimation ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.enableTapAnimation ? () => setState(() => _pressed = false) : null,
      onTapUp: widget.enableTapAnimation ? (_) {
        setState(() => _pressed = false);
        handleTap();
      } : null,
      onTap: widget.enableTapAnimation ? null : handleTap,
      child: AnimatedScale(
        scale: widget.enableTapAnimation && _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: widget.circular ? widget.size : null,
          height: widget.size,
          padding: EdgeInsets.symmetric(horizontal: widget.circular ? 0 : widget.horizontalPadding),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            shape: widget.circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.circular ? null : borderRadius,
            border: Border.all(color: widget.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: widget.circular
              ? Center(
            child: Transform.translate(
              offset: Offset(0, widget.iconTopOffset),
              child: Icon(iconData, size: widget.iconSize, color: iconColor),
            ),
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(0, widget.iconTopOffset),
                child: Icon(iconData, size: widget.iconSize, color: iconColor),
              ),
              if (widget.count != null) ...[
                const SizedBox(width: 5),
                Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: widget.countTextColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String author;

  const _ProfileImageViewerScreen({
    required this.imageUrl,
    required this.author,
  });

  @override
  State<_ProfileImageViewerScreen> createState() =>
      _ProfileImageViewerScreenState();
}

class _ProfileImageViewerScreenState extends State<_ProfileImageViewerScreen>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;

  static const double _doubleTapScale = 2.2;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
      final animation = _zoomAnimation;
      if (animation != null) {
        _transformationController.value = animation.value;
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _zoomAnimationController.dispose();
    super.dispose();
  }

  void _animateZoom(Matrix4 targetMatrix) {
    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(
        parent: _zoomAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _zoomAnimationController
      ..stop()
      ..reset()
      ..forward();
  }

  void _resetZoom() {
    _animateZoom(Matrix4.identity());
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    if (details == null) return;

    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    if (currentScale > 1.01) {
      _resetZoom();
      return;
    }

    final position = details.localPosition;
    final Matrix4 zoomed = Matrix4.identity()
      ..translate(
        -position.dx * (_doubleTapScale - 1),
        -position.dy * (_doubleTapScale - 1),
      )
      ..scale(_doubleTapScale);

    _animateZoom(zoomed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.96),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return ClipRect(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTapDown: (details) {
                      _doubleTapDetails = details;
                    },
                    onDoubleTap: _handleDoubleTap,
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 1.0,
                      maxScale: 4.0,
                      panEnabled: true,
                      scaleEnabled: true,
                      constrained: true,
                      clipBehavior: Clip.hardEdge,
                      boundaryMargin: EdgeInsets.zero,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Center(
                          child: Image.network(
                            widget.imageUrl,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              size: 42,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Material(
                color: Colors.black.withOpacity(0.36),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    _transformationController.value = Matrix4.identity();
                    Navigator.pop(context);
                  },
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
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.author,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
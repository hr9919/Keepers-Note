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
import 'community_user_profile_screen.dart';
import 'package:flutter/foundation.dart';
import 'community_uid_verification_screen.dart';

class CommunityScreen extends StatefulWidget {
  final VoidCallback? openDrawer;
  final String? userId;
  final bool isAdmin;
  final int? initialPostId;
  final int refreshSignal;
  final int openMyProfileSignal;

  static Future<bool?> openWrite(
      BuildContext context, {
        required String userId,
        required List<String> availableTags,
      }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityWriteScreen(
          userId: userId,
          availableTags: availableTags,
        ),
      ),
    );
  }

  static Future<void> openMyPosts(
      BuildContext context, {
        required String userId,
      }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MyCommunityPostsScreen(userId: userId),
      ),
    );
  }

  const CommunityScreen({
    super.key,
    this.openDrawer,
    this.userId,
    this.isAdmin = false,
    this.initialPostId,
    this.refreshSignal = 0,
    this.openMyProfileSignal = 0,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

enum CommunitySortType { latest, popular }

class CommunityPost {
  final int id;
  final int? authorUserId;
  final String author;
  final String uid;
  final String title;
  final String body;
  final List<String> imageUrls;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final String createdLabel;
  final bool isAdminPick;
  final bool hasYoutube;
  final bool hasSourceLink;
  final bool likedByMe;
  final String profileImageUrl;
  final bool mine;
  final String visibility;
  final bool lockedByOwner;
  final bool allowComments;
  final bool isFollowingAuthor;

  const CommunityPost({
    required this.id,
    this.authorUserId,
    required this.author,
    required this.uid,
    required this.title,
    required this.body,
    required this.imageUrls,
    required this.tags,
    required this.likeCount,
    this.commentCount = 0,
    required this.createdLabel,
    this.isAdminPick = false,
    this.hasYoutube = false,
    this.hasSourceLink = false,
    this.likedByMe = false,
    required this.profileImageUrl,
    this.mine = false,
    this.visibility = 'PUBLIC',
    this.lockedByOwner = false,
    this.allowComments = true,
    this.isFollowingAuthor = false,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    List<String> readStringList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
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

    int? readNullableInt(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    return CommunityPost(
      id: readInt(const ['id']),
      authorUserId: readNullableInt(const [
        'authorUserId',
        'authorId',
        'userId',
      ]),
      author: readString(const ['authorName', 'author', 'nickname'], fallback: '사용자'),
      uid: readString(const ['authorUid', 'uid', 'gameUid'], fallback: 'UID'),
      title: readString(const ['title']),
      body: readString(const ['content', 'body']),
      imageUrls: readStringList(json['imageUrls'] ?? json['images'] ?? json['postImages']),
      tags: readStringList(json['tags'] ?? json['tagNames'] ?? json['postTags']),
      likeCount: readInt(const ['likeCount']),
      commentCount: readInt(const ['commentCount']),
      createdLabel: readString(const ['createdLabel', 'createdAtLabel', 'createdAt']),
      isAdminPick: readBool(const ['adminPick', 'isAdminPick']),
      hasYoutube: readBool(const ['hasYoutube']),
      hasSourceLink: readBool(const ['hasSourceLink']),
      likedByMe: readBool(const ['likedByMe', 'liked']),
      profileImageUrl: readString(const ['profileImageUrl', 'authorProfileImageUrl', 'userProfileImageUrl']),
      mine: readBool(const ['mine']),
      visibility: readString(const ['visibility'], fallback: 'PUBLIC'),
      lockedByOwner: readBool(const ['lockedByOwner']),
      allowComments: readBool(const ['allowComments'], fallback: true),
      isFollowingAuthor: readBool(const ['isFollowingAuthor', 'followingAuthor']),
    );
  }

  CommunityPost copyWith({
    int? likeCount,
    bool? likedByMe,
    int? commentCount,
  }) {
    return CommunityPost(
      id: id,
      authorUserId: authorUserId,
      author: author,
      uid: uid,
      title: title,
      body: body,
      imageUrls: imageUrls,
      tags: tags,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdLabel: createdLabel,
      isAdminPick: isAdminPick,
      hasYoutube: hasYoutube,
      hasSourceLink: hasSourceLink,
      likedByMe: likedByMe ?? this.likedByMe,
      profileImageUrl: profileImageUrl,
      mine: mine,
      visibility: visibility,
      lockedByOwner: lockedByOwner,
      allowComments: allowComments,
      isFollowingAuthor: isFollowingAuthor,
    );
  }
}

class CommunityComment {
  final int id;
  final int postId;
  final int? authorUserId;
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
    this.authorUserId,
    required this.authorName,
    required this.authorUid,
    required this.profileImageUrl,
    required this.content,
    this.parentCommentId,
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

    int? readNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
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
      authorUserId: readNullableInt(json['authorUserId']),
      authorName: readString(json['authorName'], fallback: '사용자'),
      authorUid: readString(json['authorUid'], fallback: 'UID'),
      profileImageUrl: readString(json['profileImageUrl']),
      content: readString(json['content']),
      parentCommentId: readNullableInt(json['parentCommentId']),
      createdAt: readString(json['createdAt']),
      mine: readBool(json['mine']),
    );
  }
}

class CommunityFollowUserSummary {
  final int? userId;
  final String nickname;
  final String uid;
  final String profileImageUrl;
  final bool followingByMe;

  const CommunityFollowUserSummary({
    this.userId,
    required this.nickname,
    required this.uid,
    required this.profileImageUrl,
    this.followingByMe = false,
  });

  factory CommunityFollowUserSummary.fromJson(Map<String, dynamic> json) {
    int? readNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
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
          if (lower == 'true' || lower == '1') return true;
          if (lower == 'false' || lower == '0') return false;
        }
      }
      return fallback;
    }

    return CommunityFollowUserSummary(
      userId: readNullableInt(json['userId']),
      nickname: readString(const ['nickname', 'authorName'], fallback: '사용자'),
      uid: readString(const ['gameUid', 'uid', 'authorUid'], fallback: 'UID'),
      profileImageUrl: readString(const ['profileImageUrl', 'authorProfileImageUrl']),
      followingByMe: readBool(const ['followingByMe', 'isFollowing']),
    );
  }
}

class _TagChipStyle {
  final Color selectedBackground;
  final Color selectedBorder;
  final Color selectedText;

  const _TagChipStyle({
    required this.selectedBackground,
    required this.selectedBorder,
    required this.selectedText,
  });
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const String _baseUrl = 'https://api.keepers-note.o-r.kr';

  final ScrollController _scrollController = ScrollController();
  late final PageController _feedModePageController;
  static const int _virtualInitialPage = 1000;
  int _currentFeedPage = _virtualInitialPage;

  bool _didOpenInitialPost = false;

  bool _showTopButton = false;
  bool _isGridView = true;
  bool _isFilterPanelOpen = false;
  bool _showLikedOnly = false;
  bool _showFollowingOnly = false;
  bool _isLoading = false;
  String? _errorMessage;

  final Set<String> _selectedTags = <String>{'전체'};
  CommunitySortType _sortType = CommunitySortType.latest;
  List<CommunityPost> _posts = <CommunityPost>[];
  List<CommunityTagItem> _tagItems = const <CommunityTagItem>[];
  final TaggingTextController _commentController = TaggingTextController();
  final Map<int, List<CommunityComment>> _commentsByPostId = <int, List<CommunityComment>>{};

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

    if (widget.userId != oldWidget.userId) {
      _fetchPosts();
    }

    if (widget.initialPostId != oldWidget.initialPostId) {
      _didOpenInitialPost = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryOpenInitialPost();
      });
    }

    if (widget.refreshSignal != oldWidget.refreshSignal) {
      _fetchPosts();
    }

    if (widget.openMyProfileSignal != oldWidget.openMyProfileSignal) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _openMyProfileFromCommunity();
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
          selectedBackground: Color(0xFFFFE8DF),
          selectedBorder: Color(0xFFF1BEAA),
          selectedText: Color(0xFFC96547),
        );
      case '익스테리어':
        return const _TagChipStyle(
          selectedBackground: Color(0xFFE5F5EB),
          selectedBorder: Color(0xFFBFE2CB),
          selectedText: Color(0xFF43885B),
        );
      case '코디':
        return const _TagChipStyle(
          selectedBackground: Color(0xFFFFE8F4),
          selectedBorder: Color(0xFFEAB8D6),
          selectedText: Color(0xFFB75689),
        );
      case '반려동물':
        return const _TagChipStyle(
          selectedBackground: Color(0xFFEEE7FF),
          selectedBorder: Color(0xFFD1C2F0),
          selectedText: Color(0xFF775BB8),
        );
      case '도트 도안':
        return const _TagChipStyle(
          selectedBackground: Color(0xFFFFF2D9),
          selectedBorder: Color(0xFFEBCF8D),
          selectedText: Color(0xFFB78718),
        );
      case '꿀팁 영상':
        return const _TagChipStyle(
          selectedBackground: Color(0xFFE1F1FC),
          selectedBorder: Color(0xFFB6DBF2),
          selectedText: Color(0xFF427FA7),
        );
      case '공략':
        return const _TagChipStyle(
          selectedBackground: Color(0xFFE3EDFF),
          selectedBorder: Color(0xFFBFD4FF),
          selectedText: Color(0xFF2F5FBF),
        );
      case '전체':
      default:
        return const _TagChipStyle(
          selectedBackground: Color(0xFFFFEDE7),
          selectedBorder: Color(0xFFFFD8CF),
          selectedText: Color(0xFFFF8E7C),
        );
    }
  }

  Future<void> _openMyProfileFromCommunity() async {
    final String userIdText = (widget.userId ?? '').trim();
    final int? myUserId = int.tryParse(userIdText);

    if (userIdText.isEmpty || myUserId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 먼저 확인해주세요.')),
      );
      return;
    }

    CommunityPost? myRepresentativePost;
    for (final item in _posts) {
      if (item.authorUserId == myUserId || item.mine) {
        myRepresentativePost = item;
        break;
      }
    }

    String myAuthorName = '사용자';
    String myAuthorUid = '';
    String myProfileImageUrl = '';
    String myHeaderImageUrl = '';

    if (myRepresentativePost != null) {
      myAuthorName = myRepresentativePost.author;
      myAuthorUid = myRepresentativePost.uid;
      myProfileImageUrl =
          _resolveProfileImagePath(myRepresentativePost.profileImageUrl);
    }

    final resolved = await _buildResolvedProfilePayload(
      authorUserId: myUserId,
      fallbackAuthorName: myAuthorName,
      fallbackAuthorUid: myAuthorUid,
      fallbackProfileImageUrl: myProfileImageUrl,
    );

    myAuthorName = resolved['authorName'] ?? myAuthorName;
    myAuthorUid = resolved['authorUid'] ?? myAuthorUid;
    myProfileImageUrl = resolved['profileImageUrl'] ?? myProfileImageUrl;
    myHeaderImageUrl = resolved['headerImageUrl'] ?? '';

    final List<CommunityPost> myPosts = _posts.where((item) {
      return item.authorUserId == myUserId || item.mine;
    }).toList();

    myPosts.sort((a, b) {
      int visibilityOrder(String visibility) {
        switch (visibility) {
          case 'PUBLIC':
            return 0;
          case 'FOLLOWERS':
            return 1;
          case 'PRIVATE':
            return 2;
          default:
            return 3;
        }
      }

      final int orderCompare =
      visibilityOrder(a.visibility).compareTo(visibilityOrder(b.visibility));
      if (orderCompare != 0) return orderCompare;
      return b.id.compareTo(a.id);
    });

    final List<CommunityProfilePostSeed> seeds = myPosts.map((item) {
      return CommunityProfilePostSeed(
        id: item.id,
        title: item.title,
        body: item.body,
        imageUrl: item.imageUrls.isNotEmpty
            ? _resolveImagePath(item.imageUrls.first)
            : '',
        createdLabel: item.createdLabel,
        visibility: item.visibility,
        mine: true,
        lockedByOwner: item.lockedByOwner,
        tags: item.tags,
        likeCount: item.likeCount,
        commentCount: item.commentCount,
        uid: item.uid,
        likedByMe: item.likedByMe,
        isFollowingAuthor: false,
        isAdminPick: item.isAdminPick,
      );
    }).toList();

    final result = await Navigator.of(context).push<CommunityUserProfileResult>(
      MaterialPageRoute(
        builder: (_) => CommunityUserProfileScreen(
          baseUrl: _baseUrl,
          currentUserId: widget.userId,
          authorUserId: myUserId,
          authorName: myAuthorName,
          authorUid: myAuthorUid,
          profileImageUrl: myProfileImageUrl,
          headerImageUrl: myHeaderImageUrl,
          isMine: true,
          isInitiallyFollowing: false,
          recentSeeds: seeds,
          onOpenPost: (postId) async {
            CommunityPost? target;
            for (final item in _posts) {
              if (item.id == postId) {
                target = item;
                break;
              }
            }

            if (target == null) {
              await _fetchPosts();
              if (!mounted) return;
              for (final item in _posts) {
                if (item.id == postId) {
                  target = item;
                  break;
                }
              }
            }

            if (target != null && mounted) {
              await _openPostDetailSheet(target);
            }
          },
        ),
      ),
    );

    await _handleProfileResult(result);
  }

  Future<Map<String, dynamic>?> _fetchCommunityUidStatus() async {
    final userId = (widget.userId ?? '').trim();
    if (userId.isEmpty) return null;

    final uri = Uri.parse(
      '$_baseUrl/api/community/uid-verification/status',
    ).replace(
      queryParameters: {'userId': userId},
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleWriteEntry() async {
    final userId = (widget.userId ?? '').trim();

    if (userId.isEmpty) {
      _showSnackBar('로그인 정보가 필요해요.');
      return;
    }

    try {
      final status = await _fetchCommunityUidStatus();
      if (!mounted) return;

      if (status == null) {
        _showSnackBar('UID 상태를 확인하지 못했어요. 잠시 후 다시 시도해주세요.');
        return;
      }

      final String communityStatus =
          status['communityStatus']?.toString().toUpperCase() ?? 'NONE';
      final bool uidLocked = status['uidLocked'] == true;

      if (communityStatus == 'APPROVED' || uidLocked) {
        final availableTags = await CommunityTagApiService.fetchActiveTags();
        if (!mounted) return;

        final tagNames = availableTags
            .map((e) => e.tagName)
            .where((e) => e.trim().isNotEmpty)
            .toList();

        final bool? created = await CommunityScreen.openWrite(
          context,
          userId: userId,
          availableTags: tagNames.isEmpty ? const <String>['전체'] : tagNames,
        );

        if (!mounted) return;

        if (created == true) {
          await _fetchPosts();
          _showSnackBar('게시글이 등록되었어요.');
        }
        return;
      }

      final bool? requested = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityUidVerificationScreen(
            userId: userId,
          ),
        ),
      );

      if (!mounted) return;

      if (requested == true) {
        _showSnackBar('UID 인증 요청이 접수되었어요. 승인 후 글쓰기를 이용할 수 있어요.');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('글쓰기 화면을 여는 중 문제가 발생했어요. $e');
    }
  }

  List<String> get _availableTagNames =>
      _tagItems.map((e) => e.tagName).where((e) => e.trim().isNotEmpty).toList();

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
          if (_showFollowingOnly) 'followingOnly': 'true',
          if ((widget.userId ?? '').isNotEmpty) 'userId': widget.userId!,
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

      final List<CommunityPost> fetchedPosts = rawList
          .whereType<Map>()
          .map((e) => CommunityPost.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final Map<String, int> authorIdMap = <String, int>{};

      for (final post in fetchedPosts) {
        if (post.authorUserId != null) {
          authorIdMap[_authorKey(post.author, post.uid)] = post.authorUserId!;
        }
      }

      final List<CommunityPost> posts = fetchedPosts.map((post) {
        if (post.authorUserId != null) return post;

        final int? resolved = authorIdMap[_authorKey(post.author, post.uid)];
        if (resolved == null) return post;

        return CommunityPost(
          id: post.id,
          authorUserId: resolved,
          author: post.author,
          uid: post.uid,
          title: post.title,
          body: post.body,
          imageUrls: post.imageUrls,
          tags: post.tags,
          likeCount: post.likeCount,
          commentCount: post.commentCount,
          createdLabel: post.createdLabel,
          isAdminPick: post.isAdminPick,
          hasYoutube: post.hasYoutube,
          hasSourceLink: post.hasSourceLink,
          likedByMe: post.likedByMe,
          profileImageUrl: post.profileImageUrl,
          mine: post.mine,
          visibility: post.visibility,
          lockedByOwner: post.lockedByOwner,
          allowComments: post.allowComments,
          isFollowingAuthor: post.isFollowingAuthor,
        );
      }).toList();

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
          if ((widget.userId ?? '').isNotEmpty) 'userId': widget.userId!,
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

  // 삭제 콜백(onPostDeleted) 파라미터를 추가합니다.
  Future<void> _openPostMoreSheet(CommunityPost post, {VoidCallback? onPostDeleted}) async {
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
                        Navigator.pop(sheetContext); // 바텀 시트 닫기
                        final deleted = await _confirmDeletePost(post); // 삭제 여부 확인
                        if (deleted) {
                          onPostDeleted?.call(); // 삭제 성공 시 전달받은 콜백(팝업 닫기) 실행
                        }
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
    if ((widget.userId ?? '').isEmpty) {
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
          userId: widget.userId!,
          availableTags: availableTags,
          isEditMode: true,
          editingPostId: post.id,
          initialTitle: post.title,
          initialBody: post.body,
          initialTags: post.tags,
          initialImageUrls: post.imageUrls,
          initialVisibility: post.visibility,
          initialAllowComments: post.allowComments,
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

  // void -> bool로 변경합니다.
  Future<bool> _confirmDeletePost(CommunityPost post) async {
    final confirmed = await _showPrettyConfirmDialog(
      title: '게시글을 삭제할까요?',
      message: '삭제한 게시글은 다시 되돌릴 수 없어요.\n정말 삭제하시겠어요?',
      confirmText: '게시글 삭제',
      confirmColor: const Color(0xFFE46C6C),
      icon: Icons.delete_rounded,
    );

    if (!confirmed) return false; // 취소하면 false 반환
    return await _deletePost(post); // 삭제 결과 반환
  }

  // void -> bool로 변경합니다.
  Future<bool> _deletePost(CommunityPost post) async {
    if ((widget.userId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 필요해요.')),
      );
      return false; // 실패 시 false 반환
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/community/posts/${post.id}').replace(
        queryParameters: <String, String>{
          'userId': widget.userId!,
        },
      );

      final response = await http.delete(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('게시글 삭제 실패 (${response.statusCode})');
      }

      if (!mounted) return false;
      setState(() {
        _posts.removeWhere((e) => e.id == post.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 삭제되었어요.')),
      );
      return true; // 성공 시 true 반환
    } on TimeoutException {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 응답이 지연되고 있어요.')),
      );
      return false; // 실패 시 false 반환
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 중 문제가 발생했어요. $e')),
      );
      return false; // 실패 시 false 반환
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
    if ((widget.userId ?? '').isEmpty) {
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
          'userId': int.tryParse(widget.userId ?? ''),
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
          if ((widget.userId ?? '').isNotEmpty) 'userId': widget.userId!,
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
        _showLikedOnly = false;
        _showFollowingOnly = false;
        return;
      }

      _selectedTags.remove('전체');

      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }

      final bool noTagSelected =
          _selectedTags.isEmpty && !_showLikedOnly && !_showFollowingOnly;

      if (noTagSelected) {
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
        pageBuilder: (_, __, ___) => CommunityProfileImageViewerScreen(
          imageUrl: resolved,
          author: post.author,
          heroTag: 'profile_${post.id}',
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 11,
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
          label,
          style: TextStyle(
            fontSize: 12.2,
            fontWeight: FontWeight.w900,
            height: 1.0,
            color: selected
                ? style.selectedText
                : const Color(0xFF8E98A7),
          ),
          strutStyle: const StrutStyle(
            fontSize: 12.2,
            fontWeight: FontWeight.w900,
            height: 1.0,
            forceStrutHeight: true,
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
    const List<String> preferredOrder = <String>[
      '인테리어',
      '익스테리어',
      '코디',
      '반려동물',
      '도트 도안',
      '공략',
      '꿀팁 영상',
    ];

    final Set<String> available = _availableTagNames.toSet();

    final List<String> filterTags = <String>[
      for (final tag in preferredOrder)
        if (available.contains(tag)) tag,
      for (final tag in _availableTagNames)
        if (tag != '전체' && !preferredOrder.contains(tag)) tag,
    ];

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: _isFilterPanelOpen ? Curves.easeOutQuad : Curves.easeInCubic,
      top: topPadding + 118,
      right: _isFilterPanelOpen ? 12 : -420,
      child: IgnorePointer(
        ignoring: !_isFilterPanelOpen,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          opacity: _isFilterPanelOpen ? 1 : 0.85,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 300,
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
                        _buildFollowingFilterChip(),
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
                                _showFollowingOnly = false;
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

    return GestureDetector(
      onTap: () {
        setState(() {
          _showLikedOnly = !_showLikedOnly;

          if (_showLikedOnly) {
            _selectedTags.remove('전체');
          }

          if (_selectedTags.isEmpty && !_showLikedOnly && !_showFollowingOnly) {
            _selectedTags.add('전체');
          }
        });
        _fetchPosts();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF1F4) : Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: selected
                ? const Color(0xFFE6BAC6)
                : const Color(0xFFD8DDE5),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: const Color(0xFFE6BAC6).withOpacity(0.16),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 14,
              color: selected
                  ? const Color(0xFFD97C95)
                  : const Color(0xFF8E98A7),
            ),
            const SizedBox(width: 5),
            Text(
              '좋아요',
              style: TextStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: selected
                    ? const Color(0xFFD97C95)
                    : const Color(0xFF8E98A7),
              ),
              strutStyle: const StrutStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w900,
                height: 1.0,
                forceStrutHeight: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowingFilterChip() {
    final selected = _showFollowingOnly;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showFollowingOnly = !_showFollowingOnly;

          if (_showFollowingOnly) {
            _selectedTags.remove('전체');
          }

          if (_selectedTags.isEmpty && !_showLikedOnly && !_showFollowingOnly) {
            _selectedTags.add('전체');
          }
        });
        _fetchPosts();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF7E8) : Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: selected
                ? const Color(0xFFE8D4A6)
                : const Color(0xFFD8DDE5),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: const Color(0xFFE8D4A6).withOpacity(0.16),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.people_alt_rounded,
              size: 14,
              color: selected
                  ? const Color(0xFFB89A52)
                  : const Color(0xFF8E98A7),
            ),
            const SizedBox(width: 5),
            Text(
              '팔로우',
              style: TextStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: selected
                    ? const Color(0xFFB89A52)
                    : const Color(0xFF8E98A7),
              ),
              strutStyle: const StrutStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w900,
                height: 1.0,
                forceStrutHeight: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF3D9) : Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: selected
                ? const Color(0xFFEBCF8D)
                : const Color(0xFFD8DDE5),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: const Color(0xFFEBCF8D).withOpacity(0.16),
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
          text,
          style: TextStyle(
            fontSize: 12.2,
            fontWeight: FontWeight.w900,
            height: 1.0,
            color: selected
                ? const Color(0xFFB78718)
                : const Color(0xFF8E98A7),
          ),
          strutStyle: const StrutStyle(
            fontSize: 12.2,
            fontWeight: FontWeight.w900,
            height: 1.0,
            forceStrutHeight: true,
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
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF8E7C).withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFF8E7C).withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 12),
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: _buildIconAppBarButton(
                            icon: _isGridView
                                ? Icons.view_stream_rounded
                                : Icons.grid_view_rounded,
                            onTap: _toggleViewMode,
                            isAccent: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: _buildAppTitle(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: _buildIconAppBarButton(
                            icon: Icons.tune_rounded,
                            onTap: _toggleFilterPanel,
                            isActive: _isFilterPanelOpen,
                          ),
                        ),
                      ],
                    ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const Text(
          "Keeper's Feed",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2D3436),
            letterSpacing: -0.3,
            fontFamily: 'SF Pro',
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
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
          _buildEmptyState() // 위에서 만든 height가 지정된 위젯이 들어감
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
    final Color borderColor = _postBorderColor(post);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
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
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openUserProfile(post),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
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
                          ),
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
                      onTapImage: (index) {
                        _openImageViewer(post, initialIndex: index);
                      },
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
                        const SizedBox(height: 7),
                        Text(
                          post.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.1,
                            height: 1.52,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF69747F),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildCommentButton(
                            count: post.commentCount,
                            onTap: () => _openPostDetailSheet(
                              post,
                              focusCommentInput: true,
                            ),
                          ),
                          const Spacer(),
                          _buildLikeButton(
                            liked: liked,
                            count: post.likeCount,
                            onTap: () async {
                              await _toggleLike(post.id);
                            },
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


  Color _postBorderColor(CommunityPost post) {
    if (post.isAdminPick) return const Color(0xFFFFB3A4);
    if (post.mine) return const Color(0xFFF1E4DE);
    if (post.isFollowingAuthor) return const Color(0xFFF3D36B);
    return const Color(0xFFCFE59A);
  }

  String _formatMetaCreatedLabel(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    final local = parsed.toLocal();
    final now = DateTime.now();
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

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'UID · ${post.uid}${timeLabel.isNotEmpty ? ' · $timeLabel' : ''}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF95A0AE),
            height: 1.2,
          ),
        ),
        if (showLock)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_rounded,
                size: 12,
                color: Color(0xFFB08A7D),
              ),
              const SizedBox(width: 3),
              Text(
                lockLabel,
                style: TextStyle(
                  fontSize: fontSize - 0.1,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFB08A7D),
                  height: 1.2,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<List<CommunityComment>> _fetchComments(int postId) async {
    final uri = Uri.parse('$_baseUrl/api/community/posts/$postId/comments').replace(
      queryParameters: <String, String>{
        if ((widget.userId ?? '').isNotEmpty) 'userId': widget.userId!,
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('댓글 조회 실패 (${response.statusCode})');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) return const <CommunityComment>[];
    return decoded.whereType<Map>().map((e) => CommunityComment.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  List<CommunityProfilePostSeed> _recentSeedsForComment(CommunityComment comment) {
    final List<CommunityPost> matched = _posts.where((item) {
      if (comment.authorUserId != null && item.authorUserId != null) {
        return item.authorUserId == comment.authorUserId;
      }
      return item.author == comment.authorName && item.uid == comment.authorUid;
    }).take(18).toList();

    int visibilityOrder(String visibility) {
      switch (visibility) {
        case 'PUBLIC':
          return 0;
        case 'FOLLOWERS':
          return 1;
        case 'PRIVATE':
          return 2;
        default:
          return 3;
      }
    }

    matched.sort((a, b) {
      final int orderCompare =
      visibilityOrder(a.visibility).compareTo(visibilityOrder(b.visibility));
      if (orderCompare != 0) return orderCompare;
      return b.id.compareTo(a.id);
    });

    return matched
        .map(
          (item) => CommunityProfilePostSeed(
        id: item.id,
        title: item.title,
        body: item.body,
        imageUrl: item.imageUrls.isNotEmpty
            ? _resolveImagePath(item.imageUrls.first)
            : '',
        createdLabel: item.createdLabel,
        visibility: item.visibility,
        mine: item.mine,
        lockedByOwner: item.lockedByOwner,
        tags: item.tags,
        likeCount: item.likeCount,
        commentCount: item.commentCount,
        uid: item.uid,
        likedByMe: item.likedByMe,
        isFollowingAuthor: item.isFollowingAuthor,
        isAdminPick: item.isAdminPick,
      ),
    )
        .toList();
  }

  int? _resolveAuthorUserId({
    required int? directUserId,
    required String authorName,
    required String authorUid,
    bool isMine = false,
  }) {
    if (directUserId != null) return directUserId;

    if (isMine && (widget.userId ?? '').isNotEmpty) {
      final mineId = int.tryParse(widget.userId!);
      if (mineId != null) return mineId;
    }

    final String key = _authorKey(authorName, authorUid);

    for (final item in _posts) {
      if (item.authorUserId == null) continue;
      if (_authorKey(item.author, item.uid) == key) {
        return item.authorUserId;
      }
    }

    for (final comments in _commentsByPostId.values) {
      for (final comment in comments) {
        if (comment.authorUserId == null) continue;
        if (_authorKey(comment.authorName, comment.authorUid) == key) {
          return comment.authorUserId;
        }
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> _fetchUserSummaryByUserId(int userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/user/$userId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return null;
  }

  Future<Map<String, String>> _buildResolvedProfilePayload({
    required int? authorUserId,
    required String fallbackAuthorName,
    required String fallbackAuthorUid,
    required String fallbackProfileImageUrl,
  }) async {
    String authorName = fallbackAuthorName;
    String authorUid = fallbackAuthorUid;
    String profileImageUrl = fallbackProfileImageUrl;
    String headerImageUrl = '';

    if (authorUserId != null) {
      final userData = await _fetchUserSummaryByUserId(authorUserId);

      if (userData != null) {
        final String fetchedName =
        (userData['nickname']?.toString().trim() ?? '');
        final String fetchedUid =
        (userData['gameUid']?.toString().trim() ?? '');
        final String fetchedProfile =
        (userData['profileImageUrl']?.toString().trim() ?? '');
        final String fetchedHeader =
        (userData['headerImageUrl']?.toString().trim() ?? '');

        if (fetchedName.isNotEmpty) {
          authorName = fetchedName;
        }
        if (fetchedUid.isNotEmpty) {
          authorUid = fetchedUid;
        }
        if (fetchedProfile.isNotEmpty) {
          profileImageUrl = _resolveProfileImagePath(fetchedProfile);
        }
        if (fetchedHeader.isNotEmpty) {
          headerImageUrl = _resolveProfileImagePath(fetchedHeader);
        }
      }
    }

    return <String, String>{
      'authorName': authorName,
      'authorUid': authorUid,
      'profileImageUrl': profileImageUrl,
      'headerImageUrl': headerImageUrl,
    };
  }

  Future<void> _openUserProfileFromComment(CommunityComment comment) async {
    final int? resolvedAuthorUserId = _resolveAuthorUserId(
      directUserId: comment.authorUserId,
      authorName: comment.authorName,
      authorUid: comment.authorUid,
      isMine: comment.mine,
    );

    final bool isMine = resolvedAuthorUserId != null &&
        widget.userId != null &&
        int.tryParse(widget.userId!) == resolvedAuthorUserId;

    final bool isInitiallyFollowing = !isMine &&
        _posts.any((item) {
          if (resolvedAuthorUserId != null && item.authorUserId != null) {
            return item.authorUserId == resolvedAuthorUserId &&
                item.isFollowingAuthor;
          }
          return _authorKey(item.author, item.uid) ==
              _authorKey(comment.authorName, comment.authorUid) &&
              item.isFollowingAuthor;
        });

    final resolved = await _buildResolvedProfilePayload(
      authorUserId: resolvedAuthorUserId,
      fallbackAuthorName: comment.authorName,
      fallbackAuthorUid: comment.authorUid,
      fallbackProfileImageUrl: _resolveProfileImagePath(comment.profileImageUrl),
    );

    final result = await Navigator.of(context).push<CommunityUserProfileResult>(
      MaterialPageRoute(
        builder: (_) => CommunityUserProfileScreen(
          baseUrl: _baseUrl,
          currentUserId: widget.userId,
          authorUserId: resolvedAuthorUserId,
          authorName: resolved['authorName'] ?? comment.authorName,
          authorUid: resolved['authorUid'] ?? comment.authorUid,
          profileImageUrl: resolved['profileImageUrl'] ??
              _resolveProfileImagePath(comment.profileImageUrl),
          headerImageUrl: resolved['headerImageUrl'] ?? '',
          isMine: isMine,
          isInitiallyFollowing: isInitiallyFollowing,
          recentSeeds: _recentSeedsForComment(comment),
        ),
      ),
    );

    await _handleProfileResult(result);
  }

  Future<void> _handleProfileResult(CommunityUserProfileResult? result) async {
    if (result == null) return;
    if (result.didChangeFollow) {
      await _fetchPosts();
    }
    if (!mounted) return;
    if (result.selectedPostId != null) {
      final CommunityPost? target = _posts.cast<CommunityPost?>().firstWhere(
            (item) => item?.id == result.selectedPostId,
        orElse: () => null,
      );
      if (target != null) {
        await _openPostDetailSheet(target);
      } else {
        await _fetchPosts();
        if (!mounted) return;
        final CommunityPost? refreshed = _posts.cast<CommunityPost?>().firstWhere(
              (item) => item?.id == result.selectedPostId,
          orElse: () => null,
        );
        if (refreshed != null) {
          await _openPostDetailSheet(refreshed);
        }
      }
    }
  }

  String _authorKey(String authorName, String authorUid) {
    final uid = authorUid.trim();
    if (uid.isNotEmpty) return 'uid:$uid';
    return 'name:${authorName.trim()}';
  }

  Future<void> _openUserProfile(CommunityPost post) async {
    final int? resolvedAuthorUserId = _resolveAuthorUserId(
      directUserId: post.authorUserId,
      authorName: post.author,
      authorUid: post.uid,
      isMine: post.mine,
    );

    final bool resolvedIsMine = resolvedAuthorUserId != null &&
        widget.userId != null &&
        int.tryParse(widget.userId!) == resolvedAuthorUserId;

    final bool isInitiallyFollowing = !resolvedIsMine &&
        _posts.any((item) {
          if (resolvedAuthorUserId != null && item.authorUserId != null) {
            return item.authorUserId == resolvedAuthorUserId &&
                item.isFollowingAuthor;
          }
          return _authorKey(item.author, item.uid) ==
              _authorKey(post.author, post.uid) &&
              item.isFollowingAuthor;
        });

    final resolved = await _buildResolvedProfilePayload(
      authorUserId: resolvedAuthorUserId,
      fallbackAuthorName: post.author,
      fallbackAuthorUid: post.uid,
      fallbackProfileImageUrl: _resolveProfileImagePath(post.profileImageUrl),
    );

    final result = await Navigator.of(context).push<CommunityUserProfileResult>(
      MaterialPageRoute(
        builder: (_) => CommunityUserProfileScreen(
          baseUrl: _baseUrl,
          currentUserId: widget.userId,
          authorUserId: resolvedAuthorUserId,
          authorName: resolved['authorName'] ?? post.author,
          authorUid: resolved['authorUid'] ?? post.uid,
          profileImageUrl: resolved['profileImageUrl'] ??
              _resolveProfileImagePath(post.profileImageUrl),
          headerImageUrl: resolved['headerImageUrl'] ?? '',
          isMine: resolvedIsMine || post.mine,
          isInitiallyFollowing: isInitiallyFollowing,
          recentSeeds: _recentSeedsForAuthor(post),
        ),
      ),
    );

    await _handleProfileResult(result);
  }

  List<CommunityProfilePostSeed> _recentSeedsForAuthor(CommunityPost post) {
    final List<CommunityPost> matched = _posts.where((item) {
      if (post.authorUserId != null && item.authorUserId != null) {
        return item.authorUserId == post.authorUserId;
      }
      return item.author == post.author && item.uid == post.uid;
    }).take(18).toList();

    int visibilityOrder(String visibility) {
      switch (visibility) {
        case 'PUBLIC':
          return 0;
        case 'FOLLOWERS':
          return 1;
        case 'PRIVATE':
          return 2;
        default:
          return 3;
      }
    }

    matched.sort((a, b) {
      final int orderCompare =
      visibilityOrder(a.visibility).compareTo(visibilityOrder(b.visibility));
      if (orderCompare != 0) return orderCompare;
      return b.id.compareTo(a.id);
    });

    return matched
        .map(
          (item) => CommunityProfilePostSeed(
        id: item.id,
        title: item.title,
        body: item.body,
        imageUrl: item.imageUrls.isNotEmpty
            ? _resolveImagePath(item.imageUrls.first)
            : '',
        createdLabel: item.createdLabel,
        visibility: item.visibility,
        mine: item.mine,
        lockedByOwner: item.lockedByOwner,
        tags: item.tags,
        likeCount: item.likeCount,
        commentCount: item.commentCount,
        uid: item.uid,
        likedByMe: item.likedByMe,
        isFollowingAuthor: item.isFollowingAuthor,
        isAdminPick: item.isAdminPick,
      ),
    )
        .toList();
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
      onTap: () => _openUserProfile(post),
      child: avatar,
    );
  }

  String _resolveImagePath(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return '$_baseUrl$path';
    if (path.startsWith('assets/')) return path;
    return path;
  }

  Future<bool> _showPrettyConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    IconData icon = Icons.warning_amber_rounded,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFF0E3DC)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: confirmColor.withOpacity(0.10),
                    shape: BoxShape.circle,
                    border: Border.all(color: confirmColor.withOpacity(0.18)),
                  ),
                  child: Icon(icon, color: confirmColor, size: 26),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF3E332F),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.4,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7D716C),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8A7B71),
                          side: const BorderSide(color: Color(0xFFE8DDD7)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text(
                          confirmText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result == true;
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
        border: Border.all(
          color: _postBorderColor(post),
        ),
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
                          left: 10,
                          bottom: 10,
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

  Future<void> _openPostDetailSheet(
      CommunityPost post, {
        bool focusCommentInput = false,
      }) async {
    _commentController.clear();

    CommunityPost detailPost = post;

    final FocusNode commentFocusNode = FocusNode();
    bool didRequestInitialFocus = focusCommentInput;

    Future<List<CommunityComment>> commentsFuture = _fetchComments(post.id);
    CommunityComment? replyTarget;
    bool localSubmitting = false;

    // 초기 댓글 데이터를 받아온 직후 캐시에 저장하기 위한 로직 추가
    commentsFuture.then((comments) {
      _commentsByPostId[detailPost.id] = comments;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.16),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final media = MediaQuery.of(context);
            final maxCardHeight = media.size.height * 0.84;
            final bool keyboardVisible = media.viewInsets.bottom > 0;
            final double bottomSafe = media.padding.bottom;

            Future<void> toggleDetailLike() async {
              if ((widget.userId ?? '').isEmpty) {
                _showSnackBar('로그인 정보가 필요해요.');
                return;
              }

              final bool wasLiked = detailPost.likedByMe;
              final int previousCount = detailPost.likeCount;
              final int optimisticCount = previousCount + (wasLiked ? -1 : 1);

              setSheetState(() {
                detailPost = detailPost.copyWith(
                  likedByMe: !wasLiked,
                  likeCount: optimisticCount < 0 ? 0 : optimisticCount,
                );
              });

              final int index = _posts.indexWhere((e) => e.id == detailPost.id);
              if (index >= 0 && mounted) {
                setState(() {
                  _posts[index] = _posts[index].copyWith(
                    likedByMe: !wasLiked,
                    likeCount: optimisticCount < 0 ? 0 : optimisticCount,
                  );
                });
              }

              try {
                final uri = Uri.parse(
                  '$_baseUrl/api/community/posts/${detailPost.id}/like',
                ).replace(
                  queryParameters: <String, String>{
                    'userId': widget.userId!,
                  },
                );

                final response = await http.post(uri).timeout(
                  const Duration(seconds: 10),
                );

                if (response.statusCode < 200 || response.statusCode >= 300) {
                  throw Exception('좋아요 처리 실패');
                }

                final decoded = jsonDecode(utf8.decode(response.bodyBytes));
                final bool liked = decoded is Map<String, dynamic>
                    ? (decoded['liked'] == true || decoded['liked'] == 1)
                    : !wasLiked;
                final int likeCount = decoded is Map<String, dynamic>
                    ? ((decoded['likeCount'] as num?)?.toInt() ?? optimisticCount)
                    : optimisticCount;

                if (context.mounted) {
                  setSheetState(() {
                    detailPost = detailPost.copyWith(
                      likedByMe: liked,
                      likeCount: likeCount,
                    );
                  });
                }

                if (index >= 0 && mounted) {
                  setState(() {
                    _posts[index] = _posts[index].copyWith(
                      likedByMe: liked,
                      likeCount: likeCount,
                    );
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  setSheetState(() {
                    detailPost = detailPost.copyWith(
                      likedByMe: wasLiked,
                      likeCount: previousCount,
                    );
                  });
                }

                if (index >= 0 && mounted) {
                  setState(() {
                    _posts[index] = _posts[index].copyWith(
                      likedByMe: wasLiked,
                      likeCount: previousCount,
                    );
                  });
                }

                _showSnackBar('좋아요 처리 중 문제가 발생했어요.');
              }
            }

            void requestComposerFocus() {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                if (!commentFocusNode.hasFocus) {
                  FocusScope.of(context).requestFocus(commentFocusNode);
                }
              });
            }

            void activateReplyMode(CommunityComment target) {
              setSheetState(() {
                replyTarget = target;
                _commentController.text = '@${target.authorName} ';
                _commentController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _commentController.text.length),
                );
              });
              requestComposerFocus();
            }

            if (didRequestInitialFocus) {
              didRequestInitialFocus = false;
              requestComposerFocus();
            }

            Future<void> refreshComments() async {
              setSheetState(() {
                commentsFuture = _fetchComments(detailPost.id);
              });

              final comments = await commentsFuture;
              _commentsByPostId[detailPost.id] = comments;

              // 1. 상세 팝업 내부의 UI를 위해 detailPost 업데이트 (댓글 수 최신화)
              if (context.mounted) {
                setSheetState(() {
                  detailPost = detailPost.copyWith(commentCount: comments.length);
                });
              }

              // 2. 메인 화면(리스트)의 데이터도 업데이트
              final index = _posts.indexWhere((e) => e.id == detailPost.id);
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
              if ((widget.userId ?? '').isEmpty) {
                _showSnackBar('로그인 정보가 필요해요.');
                return;
              }
              if (!detailPost.allowComments) {
                _showSnackBar('댓글이 비활성화된 게시글이에요.');
                return;
              }

              setSheetState(() {
                localSubmitting = true;
              });

              try {
                final response = await http
                    .post(
                  Uri.parse(
                    '$_baseUrl/api/community/posts/${detailPost.id}/comments',
                  ),
                  headers: const {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'userId': int.tryParse(widget.userId ?? ''),
                    'content': text,
                    'parentCommentId': replyTarget?.id,
                  }),
                )
                    .timeout(const Duration(seconds: 10));

                if (response.statusCode < 200 || response.statusCode >= 300) {
                  throw Exception('댓글 등록 실패 (${response.statusCode})');
                }

                _commentController.clear();
                if (context.mounted) {
                  setSheetState(() {
                    replyTarget = null;
                  });
                }
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

            Future<void> deleteComment(CommunityComment comment) async {
              if ((widget.userId ?? '').isEmpty) return;

              final response = await http
                  .delete(
                Uri.parse(
                  '$_baseUrl/api/community/posts/${detailPost.id}/comments/${comment.id}',
                ).replace(
                  queryParameters: {'userId': widget.userId!},
                ),
              )
                  .timeout(const Duration(seconds: 10));

              if (response.statusCode < 200 || response.statusCode >= 300) {
                throw Exception('댓글 삭제 실패 (${response.statusCode})');
              }

              await refreshComments();
            }

            Future<void> reportComment(CommunityComment comment) async {
              final String? reason = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (sheetContext) {
                  const reasons = <String>[
                    '스팸 / 광고',
                    '욕설 / 혐오 표현',
                    '부적절한 내용',
                    '도배 / 반복 댓글',
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
                                      '댓글 신고 사유 선택',
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
                                  onTap: () =>
                                      Navigator.pop(sheetContext, reason),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      13,
                                      18,
                                      13,
                                    ),
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

              final response = await http
                  .post(
                Uri.parse('$_baseUrl/api/community/reports'),
                headers: const {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'postId': detailPost.id,
                  'userId': int.tryParse(widget.userId ?? ''),
                  'reasonCode': reason,
                  'detailText': 'comment:${comment.id}:${comment.content}',
                }),
              )
                  .timeout(const Duration(seconds: 10));

              if (response.statusCode < 200 || response.statusCode >= 300) {
                throw Exception('댓글 신고 실패 (${response.statusCode})');
              }

              _showSnackBar('댓글 신고가 접수되었어요.');
            }

            Future<void> openCommentMenu(CommunityComment comment) async {
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
                            if (comment.mine)
                              _buildPostActionTile(
                                icon: Icons.delete_rounded,
                                iconBg: const Color(0xFFFFF1F1),
                                iconColor: const Color(0xFFE46C6C),
                                title: '댓글 삭제',
                                subtitle: '내 댓글을 삭제해요.',
                                onTap: () async {
                                  Navigator.pop(sheetContext);
                                  try {
                                    await deleteComment(comment);
                                  } catch (e) {
                                    _showSnackBar('댓글 삭제 중 문제가 발생했어요. $e');
                                  }
                                },
                              )
                            else
                              _buildPostActionTile(
                                icon: Icons.flag_rounded,
                                iconBg: const Color(0xFFFFF1F1),
                                iconColor: const Color(0xFFE46C6C),
                                title: '댓글 신고',
                                subtitle: '부적절한 댓글을 신고해요.',
                                onTap: () async {
                                  Navigator.pop(sheetContext);
                                  try {
                                    await reportComment(comment);
                                  } catch (e) {
                                    _showSnackBar('댓글 신고 중 문제가 발생했어요. $e');
                                  }
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

            return Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: true, // 키보드 높이를 Scaffold가 관리하게 함
              body: GestureDetector(
                onTap: () {
                  // 다이얼로그 바깥 영역 터치 시 키보드 내리기
                  FocusScope.of(context).unfocus();
                },
                behavior: HitTestBehavior.opaque,
                child: SafeArea(
                  bottom: !keyboardVisible, // 키보드가 올라왔을 때는 하단 SafeArea를 무시하여 딱 붙게 함
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    // 키보드가 올라오면 다이얼로그 카드를 화면 맨 아래(키보드 바로 위)로 정렬
                    alignment: keyboardVisible ? Alignment.bottomCenter : Alignment.center,
                    child: Padding(
                      // 정렬에 따라 다이얼로그 외부 여백 조절
                      padding: EdgeInsets.fromLTRB(10, 14, 10, keyboardVisible ? 0 : 14),
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: 540,
                            maxHeight: maxCardHeight,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.98),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF1E4DE),
                              width: 1.2,
                            ),
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
                            child: Column(
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
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      12,
                                      14,
                                      14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius:
                                                  BorderRadius.circular(14),
                                                  onTap: () =>
                                                      _openUserProfile(detailPost),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        _buildProfileAvatar(
                                                          detailPost,
                                                          radius: 18,
                                                          enableTap: false,
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Flexible(
                                                                      child: Text(
                                                                        detailPost
                                                                            .author,
                                                                        maxLines: 1,
                                                                        overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                        style:
                                                                        const TextStyle(
                                                                          fontSize:
                                                                          13.6,
                                                                          fontWeight:
                                                                          FontWeight
                                                                              .w800,
                                                                          color: Color(
                                                                              0xFF2F3941),
                                                                        ),
                                                                      ),
                                                                  ),
                                                                      if (detailPost.isAdminPick) ...[const SizedBox (width: 6),
                                                                    _buildVerifiedBadge(),
                                                                  ],
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                  height: 2),
                                                              _buildPostMetaLine(
                                                                detailPost,
                                                                fontSize: 11.4,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            _buildDetailActionButton(
                                              icon: Icons.ios_share_rounded,
                                              onTap: () async {
                                                await _openShareOptions(
                                                    detailPost);
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            _buildDetailActionButton(
                                              icon: Icons.more_vert_rounded,
                                              onTap: () async {
                                                await _openPostMoreSheet(
                                                  detailPost,
                                                  onPostDeleted: () {
                                                    // 삭제가 완료되면 상세 팝업(현재 context)을 닫습니다.
                                                    if (context.mounted) {
                                                      Navigator.pop(context);
                                                    }
                                                  },
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),

                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (detailPost.tags.isNotEmpty)
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: detailPost.tags
                                                      .take(3)
                                                      .map(
                                                        (tag) => _buildContentTagChip(
                                                      tag,
                                                      compact: true,
                                                      pill: true,
                                                    ),
                                                  )
                                                      .toList(),
                                                ),

                                              if (detailPost.tags.isNotEmpty &&
                                                  detailPost.title.trim().isNotEmpty)
                                                const SizedBox(height: 10),

                                              if (detailPost.title.trim().isNotEmpty)
                                                Text(
                                                  detailPost.title.trim(),
                                                  style: const TextStyle(
                                                    fontSize: 17.2,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF2F3941),
                                                    height: 1.32,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),

                                              if ((detailPost.tags.isNotEmpty ||
                                                  detailPost.title.trim().isNotEmpty) &&
                                                  detailPost.body.trim().isNotEmpty)
                                                const SizedBox(height: 12),

                                              if (detailPost.body.trim().isNotEmpty)
                                                Text(
                                                  detailPost.body.trim(),
                                                  style: const TextStyle(
                                                    fontSize: 14.4,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF55616D),
                                                    height: 1.68,
                                                    letterSpacing: -0.05,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        if (detailPost.tags.isNotEmpty || detailPost.title.trim().isNotEmpty || detailPost.body.trim().isNotEmpty)
                                          const SizedBox(height: 14),

                                        if (detailPost.imageUrls.isNotEmpty)
                                          ClipRRect(
                                            borderRadius:
                                            BorderRadius.circular(18),
                                            child: _PostImageCarousel(
                                              post: detailPost,
                                              baseUrl: _baseUrl,
                                              showLeadingTag: false,
                                              useIntrinsicAspectRatio: true,
                                              onTapImage: (imageIndex) {
                                                _openImageViewer(
                                                  detailPost,
                                                  initialIndex: imageIndex,
                                                );
                                              },
                                            ),
                                          ),
                                        if (detailPost.imageUrls.isNotEmpty)
                                          const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            // 수정 포인트: 0 대신 detailPost.commentCount를 폴백으로 사용
                                            _buildCommentButton(
                                              count: _commentsByPostId[detailPost.id]?.length ?? detailPost.commentCount,
                                              onTap: requestComposerFocus,
                                            ),
                                            const Spacer(),
                                            _buildLikeButton(
                                              liked: detailPost.likedByMe,
                                              count: detailPost.likeCount,
                                              onTap: toggleDetailLike,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        FutureBuilder<List<CommunityComment>>(
                                          future: commentsFuture,
                                          builder: (context, snapshot) {
                                            final bool loading =
                                                snapshot.connectionState == ConnectionState.waiting;

                                            final List<CommunityComment> localComments =
                                                snapshot.data ??
                                                    _commentsByPostId[detailPost.id] ??
                                                    const <CommunityComment>[];

                                            final List<CommunityComment> rootComments = localComments
                                                .where((c) => c.parentCommentId == null)
                                                .toList();

                                            List<CommunityComment> repliesFor(int parentId) {
                                              return localComments
                                                  .where((c) => c.parentCommentId == parentId)
                                                  .toList();
                                            }

                                            Widget buildCommentTile(
                                                CommunityComment comment, {
                                                  bool isReply = false,
                                                }) {
                                              final String commentTime =
                                              _formatMetaCreatedLabel(comment.createdAt);

                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  left: isReply ? 26 : 0,
                                                  bottom: 14,
                                                ),
                                                child: Column(
                                                  children: [
                                                    if (!isReply)
                                                      const Padding(
                                                        padding: EdgeInsets.only(bottom: 12),
                                                        child: Divider(
                                                          height: 1,
                                                          thickness: 1,
                                                          color: Color(0xFFF3E7E1),
                                                        ),
                                                      ),
                                                    Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        GestureDetector(
                                                          onTap: comment.authorUserId == null
                                                              ? null
                                                              : () => _openUserProfileFromComment(comment),
                                                          child: _buildCommentAvatar(comment, radius: 16),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: GestureDetector(
                                                            onTap: () => activateReplyMode(comment),
                                                            behavior: HitTestBehavior.translucent,
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: Column(
                                                                        crossAxisAlignment:
                                                                        CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            comment.authorName,
                                                                            style: const TextStyle(
                                                                              fontSize: 12.8,
                                                                              fontWeight: FontWeight.w800,
                                                                              color: Color(0xFF33414B),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(height: 2),
                                                                          Text(
                                                                            'UID · ${comment.authorUid}',
                                                                            style: const TextStyle(
                                                                              fontSize: 11.1,
                                                                              fontWeight: FontWeight.w700,
                                                                              color: Color(0xFF9CA6B2),
                                                                            ),
                                                                          ),
                                                                        ],
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
                                                                    const SizedBox(width: 4),
                                                                    InkWell(
                                                                      borderRadius:
                                                                      BorderRadius.circular(999),
                                                                      onTap: () => openCommentMenu(comment),
                                                                      child: const Padding(
                                                                        padding: EdgeInsets.all(4),
                                                                        child: Icon(
                                                                          Icons.more_vert_rounded,
                                                                          size: 16,
                                                                          color: Color(0xFF9CA6B2),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(height: 7),
                                                                Container(
                                                                  width: double.infinity,
                                                                  padding: const EdgeInsets.fromLTRB(
                                                                    12,
                                                                    10,
                                                                    12,
                                                                    10,
                                                                  ),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFFFFFBFA),
                                                                    borderRadius: BorderRadius.circular(16),
                                                                    border: Border.all(
                                                                      color: const Color(0xFFF1E4DE),
                                                                    ),
                                                                  ),
                                                                  child: RichText(
                                                                    text: TextSpan(
                                                                      style: const TextStyle(
                                                                        fontSize: 13.2,
                                                                        height: 1.45,
                                                                        fontWeight: FontWeight.w600,
                                                                        color: Color(0xFF5E6975),
                                                                      ),
                                                                      children: () {
                                                                        final List<InlineSpan> spans = [];
                                                                        comment.content.splitMapJoin(
                                                                          RegExp(r'(@[^\s]+)'),
                                                                          onMatch: (Match match) {
                                                                            spans.add(TextSpan(
                                                                              text: match[0],
                                                                              style: const TextStyle(color: Color(0xFF7D67B8), fontWeight: FontWeight.w700),
                                                                            ));
                                                                            return '';
                                                                          },
                                                                          onNonMatch: (String text) {
                                                                            spans.add(TextSpan(text: text));
                                                                            return '';
                                                                          },
                                                                        );
                                                                        return spans;
                                                                      }(),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }

                                            if (loading) {
                                              return const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 16),
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    color: Color(0xFFFF8E7C),
                                                  ),
                                                ),
                                              );
                                            } else if (rootComments.isEmpty) {
                                              return Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(vertical: 20),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFFBFA),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: const Color(0xFFF1E4DE),
                                                  ),
                                                ),
                                                child: const Text(
                                                  '아직 댓글이 없어요.',
                                                  style: TextStyle(
                                                    fontSize: 12.8,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF98A2AE),
                                                  ),
                                                ),
                                              );
                                            } else {
                                              return Column(
                                                children: rootComments.expand(
                                                      (comment) {
                                                    final children = repliesFor(comment.id);
                                                    return <Widget>[
                                                      buildCommentTile(comment),
                                                      ...children.map(
                                                            (reply) => buildCommentTile(
                                                          reply,
                                                          isReply: true,
                                                        ),
                                                      ),
                                                    ];
                                                  },
                                                ).toList(),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // 하단 입력창 (수동 마진 로직 제거)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      top: BorderSide(
                                        color: const Color(0xFFF1E4DE).withOpacity(0.95),
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      14,
                                      10,
                                      14,
                                      keyboardVisible ? 10 : (bottomSafe > 0 ? bottomSafe + 6 : 14),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (replyTarget != null)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              children: [
                                                Text(
                                                  '${replyTarget!.authorName}님에게 답글 작성중이에요.',
                                                  style: const TextStyle(
                                                    fontSize: 12.2,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFFFF8E7C),
                                                  ),
                                                ),
                                                const Spacer(),
                                                GestureDetector(
                                                  onTap: () {
                                                    setSheetState(() {
                                                      replyTarget = null;
                                                      _commentController.clear();
                                                    });
                                                  },
                                                  child: const Icon(
                                                    Icons.close_rounded,
                                                    size: 18,
                                                    color: Color(0xFFB08A7D),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _commentController,
                                                focusNode: commentFocusNode,
                                                cursorColor: const Color(0xFFFF8E7C),
                                                minLines: 1,
                                                maxLines: 4,
                                                textInputAction: TextInputAction.newline,
                                                decoration: InputDecoration(
                                                  hintText: replyTarget == null
                                                      ? '댓글을 입력해주세요.'
                                                      : '답글을 입력해주세요.',
                                                  hintStyle: const TextStyle(
                                                    color: Color(0xFFADB5C2),
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                  ),
                                                  filled: true,
                                                  fillColor: const Color(0xFFFFFBFA),
                                                  contentPadding: const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                    borderSide: const BorderSide(
                                                      color: Color(0xFFF1E4DE),
                                                    ),
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                    borderSide: const BorderSide(
                                                      color: Color(0xFFF1E4DE),
                                                    ),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                    borderSide: const BorderSide(
                                                      color: Color(0xFFFFB4A4),
                                                      width: 1.3,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            GestureDetector(
                                              onTap: localSubmitting ? null : submitLocalComment,
                                              child: Container(
                                                width: 42,
                                                height: 42,
                                                margin: const EdgeInsets.only(bottom: 3),
                                                decoration: BoxDecoration(
                                                  color: localSubmitting
                                                      ? const Color(0xFFF9F9F9)
                                                  // 기존보다 살짝 더 채도 있는 파스텔 피치
                                                      : const Color(0xFFFFF1EB),
                                                  shape: BoxShape.circle,
                                                  // 가벼운 느낌을 해치지 않는 선에서 형태를 잡아주는 얇은 테두리 추가
                                                  border: Border.all(
                                                    color: localSubmitting
                                                        ? const Color(0xFFF0F0F0)
                                                        : const Color(0xFFFFD1C7),
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: localSubmitting
                                                    ? const Padding(
                                                  padding: EdgeInsets.all(12),
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    color: Color(0xFFFFB4A4),
                                                  ),
                                                )
                                                    : const Padding(
                                                  // 핵심: 쏠림 현상 교정을 위해 아이콘을 오른쪽으로 2.5px 밀어줍니다.
                                                  padding: EdgeInsets.only(left: 2.5),
                                                  child: Icon(
                                                    Icons.send_rounded,
                                                    size: 19, // 살짝 더 키움
                                                    // 아이콘 색상도 조금 더 또렷한 코랄로 강조
                                                    color: Color(0xFFFF7E69),
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // 수정 포인트: 팝업이 닫히고 렌더트리 파괴 등 애니메이션이 완전히 끝난 이후에 포커스를 해제하도록 지연시킵니다.
    // 이를 통해 발생하던 'A FocusNode was used after being disposed' 및 RenderFlex 크래시 오류를 원천 차단합니다.
    Future.delayed(const Duration(milliseconds: 500), () {
      commentFocusNode.dispose();
    });
  }

    Widget _buildCommentButton({
    required int count,
    VoidCallback? onTap,
  }) {
    return _AnimatedCommunityLikeButton(
      liked: false,
      onTap: onTap ?? () {},
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

  Widget _buildCommentAvatar(CommunityComment comment, {double radius = 16}) {
    final resolved = _resolveProfileImagePath(comment.profileImageUrl);
    Widget avatar;
    if (resolved.isEmpty) {
      avatar = CircleAvatar(
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
      // 0.55 -> 0.72로 늘려서 시야를 더 아래(정중앙)로 내렸습니다.
      height: MediaQuery.of(context).size.height * 0.72,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            '아직 조건에 맞는 글이 없어요.',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9EA6B2),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
              onPressed: () async {
                await _handleWriteEntry();
              },
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFFF9F7),
              // 텍스트를 너무 쨍하지 않은 부드러운 코랄/브라운 톤으로 완화했습니다.
              foregroundColor: const Color(0xFFD4978A),
              side: const BorderSide(color: Color(0xFFFFE0DA), width: 1.0),
              elevation: 0,
              // 아이콘 형태 때문에 쏠려보이는 착시를 막기 위해 왼쪽 여백(26)을 더 주어 시각적 가운데 정렬을 맞췄습니다.
              padding: const EdgeInsets.fromLTRB(26, 12, 20, 12),
              shape: const StadiumBorder(),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '작성하러 가기',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 14.2,
                    fontWeight: FontWeight.w700, // 두께 완화 (w800 -> w700)
                  ),
                ),
                SizedBox(width: 2), // 텍스트와 아이콘 사이 간격 축소
                Icon(Icons.chevron_right_rounded, size: 18), // 아이콘 크기 살짝 축소
              ],
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

  Future<void> _sharePostWithDeepLink(CommunityPost post) async {
    final String title = post.title.isNotEmpty ? post.title : '키퍼노트 커뮤니티 글';
    final String body = post.body.isNotEmpty ? post.body : '키퍼노트에서 이 글을 확인해보세요.';
    final String url = 'https://keepersnote.app/community/post/${post.id}';

    await Share.share('$title\n\n$body\n\n$url');
  }

  Widget _buildGridMoreButton({
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 4,
          ),
          color: Colors.transparent,
          child: const Icon(
            Icons.more_horiz_rounded,
            size: 20,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ],
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

    final bool didPostChange = oldWidget.post.id != widget.post.id;
    final bool didImagesChange =
    !listEquals(oldWidget.post.imageUrls, widget.post.imageUrls);

    if (didPostChange || didImagesChange) {
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
    this.size = 42,
    this.iconSize = 19,
    required this.backgroundColor,
    required this.borderColor,
    required this.likedColor,
    required this.idleColor,
    this.countTextColor,
    this.circular = false,
    this.iconTopOffset = 0,
    this.horizontalPadding = 11,
    this.iconOverride,
    this.enableTapAnimation = true,
  });

  @override
  State<_AnimatedCommunityLikeButton> createState() =>
      _AnimatedCommunityLikeButtonState();
}

class _AnimatedCommunityLikeButtonState
    extends State<_AnimatedCommunityLikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.14, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _AnimatedCommunityLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableTapAnimation && widget.liked != oldWidget.liked && widget.liked) {
      _controller
        ..stop()
        ..forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.enableTapAnimation) {
      _controller
        ..stop()
        ..forward(from: 0.0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCount = widget.count != null;
    final double height = widget.size;
    final double width = widget.circular
        ? widget.size
        : (hasCount ? widget.size + widget.horizontalPadding * 2 : widget.size);
    final IconData icon = widget.iconOverride ??
        (widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded);
    final Color iconColor = widget.liked ? widget.likedColor : widget.idleColor;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.enableTapAnimation ? _scaleAnimation.value : 1.0,
            child: child,
          );
        },
        child: Container(
          height: height,
          width: width,
          padding: widget.circular ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.circular ? 999 : 16),
            border: Border.all(color: widget.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: widget.circular ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(0, widget.iconTopOffset),
                child: Icon(icon, size: widget.iconSize, color: iconColor),
              ),
              if (!widget.circular && hasCount) ...[
                const SizedBox(width: 6),
                Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w800,
                    color: widget.countTextColor ?? iconColor,
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
// @태그를 찾아서 보라색으로 하이라이트해주는 커스텀 컨트롤러
class TaggingTextController extends TextEditingController {
  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final List<InlineSpan> children = [];

    // @로 시작하고 공백 전까지의 단어를 찾는 정규식
    text.splitMapJoin(
      RegExp(r'(@[^\s]+)'),
      onMatch: (Match match) {
        children.add(TextSpan(
          text: match[0],
          style: style?.copyWith(color: const Color(0xFF7D67B8), fontWeight: FontWeight.w700),
        ));
        return '';
      },
      onNonMatch: (String text) {
        children.add(TextSpan(text: text, style: style));
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }
}

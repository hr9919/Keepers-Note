import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'image_adjust_screen.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class CommunityProfilePostSeed {
  final int id;
  final String title;
  final String body;
  final String imageUrl;
  final String createdLabel;
  final String visibility;
  final bool mine;
  final bool lockedByOwner;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final String uid;
  final bool likedByMe;
  final bool isFollowingAuthor;
  final bool isAdminPick;

  const CommunityProfilePostSeed({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.createdLabel,
    this.visibility = 'PUBLIC',
    this.mine = false,
    this.lockedByOwner = false,
    this.tags = const <String>[],
    this.likeCount = 0,
    this.commentCount = 0,
    this.uid = '',
    this.likedByMe = false,
    this.isFollowingAuthor = false,
    this.isAdminPick = false,
  });
}

class CommunityUserProfileResult {
  final int? selectedPostId;
  final bool didChangeFollow;

  const CommunityUserProfileResult({
    this.selectedPostId,
    this.didChangeFollow = false,
  });
}

class CommunityFollowUserSummary {
  final int? userId;
  final String nickname;
  final String gameUid;
  final String profileImageUrl;

  const CommunityFollowUserSummary({
    this.userId,
    required this.nickname,
    required this.gameUid,
    required this.profileImageUrl,
  });

  factory CommunityFollowUserSummary.fromJson(Map<String, dynamic> json) {
    int? nullableInt(dynamic value) =>
        value == null ? null : int.tryParse(value.toString());

    String s(dynamic value) => value?.toString().trim() ?? '';

    return CommunityFollowUserSummary(
      userId: nullableInt(json['userId']),
      nickname: s(json['nickname'] ?? json['authorName']),
      gameUid: s(json['gameUid'] ?? json['authorUid']),
      profileImageUrl: s(json['profileImageUrl']),
    );
  }
}

class CommunityUserProfileScreen extends StatefulWidget {
  final String baseUrl;
  final String? currentUserId;
  final int? authorUserId;
  final String authorName;
  final String authorUid;
  final String profileImageUrl;
  final String headerImageUrl;
  final bool isMine;
  final bool isInitiallyFollowing;
  final List<CommunityProfilePostSeed> recentSeeds;
  final Future<void> Function(int postId)? onOpenPost;

  const CommunityUserProfileScreen({
    super.key,
    required this.baseUrl,
    required this.currentUserId,
    required this.authorUserId,
    required this.authorName,
    required this.authorUid,
    required this.profileImageUrl,
    this.headerImageUrl = '',
    required this.isMine,
    required this.isInitiallyFollowing,
    this.recentSeeds = const <CommunityProfilePostSeed>[],
    this.onOpenPost,
  });

  @override
  State<CommunityUserProfileScreen> createState() =>
      _CommunityUserProfileScreenState();
}

class _CommunityUserProfileScreenState extends State<CommunityUserProfileScreen> {
  static const Color _accent = Color(0xFFFF8E7C);
  static const Color _bg = Color(0xFFFFF9F8);
  static const Color _textMain = Color(0xFF2D3436);
  static const Color _textSub = Color(0xFF9AA4B2);

  bool _loading = true;
  bool _followSubmitting = false;
  bool _following = false;

  bool _isLoading = false;
  bool _didUserInfoChange = false;
  bool _uidLocked = false;

  String _nickname = '';
  String _gameUid = '';
  String _resolvedProfileImageUrl = '';
  String _resolvedHeaderImageUrl = '';

  List<CommunityFollowUserSummary> _followers = <CommunityFollowUserSummary>[];
  List<CommunityFollowUserSummary> _followingUsers = <CommunityFollowUserSummary>[];
  List<CommunityProfilePostSeed> _recentPosts = <CommunityProfilePostSeed>[];

  @override
  void initState() {
    super.initState();
    _following = widget.isInitiallyFollowing;
    _nickname = widget.authorName;
    _gameUid = widget.authorUid;
    _resolvedProfileImageUrl = _resolveUrl(widget.profileImageUrl);
    _resolvedHeaderImageUrl = _resolveUrl(widget.headerImageUrl);
    _recentPosts = List<CommunityProfilePostSeed>.from(widget.recentSeeds);
    _load();
  }

  int? get _effectiveAuthorUserId {
    if (widget.authorUserId != null) {
      return widget.authorUserId;
    }

    if (widget.isMine) {
      return int.tryParse((widget.currentUserId ?? '').trim());
    }

    return null;
  }

  bool get _canFollowTarget {
    return !widget.isMine &&
        _effectiveAuthorUserId != null &&
        (widget.currentUserId ?? '').trim().isNotEmpty;
  }

  String _resolveUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return '${widget.baseUrl}$value';
    }
    return value;
  }

  Widget _buildProfileCapsuleAction() {
    if (widget.isMine) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1EC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFFFD9CC)),
        ),
        child: const Text(
          '내 프로필',
          style: TextStyle(
            fontSize: 11.2,
            fontWeight: FontWeight.w800,
            color: _accent,
          ),
        ),
      );
    }

    return AnimatedScale(
      scale: _followSubmitting ? 0.98 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _followSubmitting ? null : _toggleFollow,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _following
                  ? const Color(0xFFFFF1EC)
                  : const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _following
                    ? const Color(0xFFFFD9CC)
                    : const Color(0xFFDDE3EA),
              ),
              boxShadow: [
                BoxShadow(
                  color: (_following
                      ? const Color(0xFFFF8E7C)
                      : const Color(0xFFB0B8C1))
                      .withOpacity(0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _followSubmitting
                ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Color(0xFF5E6A78),
              ),
            )
                : AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Row(
                key: ValueKey(_following),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(0, 0.6),
                    child: Icon(
                      _following
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 13.5,
                      color: _following
                          ? const Color(0xFFFF8E7C)
                          : const Color(0xFF5E6A78),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _following ? '팔로잉' : '팔로우',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      color: _following
                          ? const Color(0xFFFF8E7C)
                          : const Color(0xFF5E6A78),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    try {
      final int? authorUserId = _effectiveAuthorUserId;

      if (authorUserId != null) {
        final responses = await Future.wait([
          http.get(
            Uri.parse('${widget.baseUrl}/api/user/$authorUserId'),
          ),
          http.get(
            Uri.parse('${widget.baseUrl}/api/community/followers').replace(
              queryParameters: {'userId': authorUserId.toString()},
            ),
          ),
          http.get(
            Uri.parse('${widget.baseUrl}/api/community/following').replace(
              queryParameters: {'userId': authorUserId.toString()},
            ),
          ),
          http.get(
            Uri.parse('${widget.baseUrl}/api/community/uid-verification/status')
                .replace(
              queryParameters: {'userId': authorUserId.toString()},
            ),
          ),
        ]);

        final userRes = responses[0];
        final followersRes = responses[1];
        final followingRes = responses[2];
        final uidStatusRes = responses[3];

        if (userRes.statusCode >= 200 && userRes.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(userRes.bodyBytes));

          if (decoded is Map<String, dynamic>) {
            _nickname =
            (decoded['nickname']?.toString().trim().isNotEmpty ?? false)
                ? decoded['nickname'].toString().trim()
                : widget.authorName;

            _gameUid =
            (decoded['gameUid']?.toString().trim().isNotEmpty ?? false)
                ? decoded['gameUid'].toString().trim()
                : widget.authorUid;

            final profileRaw = decoded['profileImageUrl']?.toString() ?? '';
            final headerRaw = decoded['headerImageUrl']?.toString() ?? '';

            if (profileRaw.trim().isNotEmpty) {
              _resolvedProfileImageUrl =
              '${_resolveUrl(profileRaw)}?t=${DateTime.now().millisecondsSinceEpoch}';
            }

            if (headerRaw.trim().isNotEmpty) {
              _resolvedHeaderImageUrl =
              '${_resolveUrl(headerRaw)}?t=${DateTime.now().millisecondsSinceEpoch}';
            }
          }
        }

        if (uidStatusRes.statusCode >= 200 && uidStatusRes.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(uidStatusRes.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            _uidLocked = decoded['uidLocked'] == true;
          }
        }

        if (followersRes.statusCode >= 200 && followersRes.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(followersRes.bodyBytes));
          if (decoded is List) {
            _followers = decoded
                .whereType<Map>()
                .map(
                  (e) => CommunityFollowUserSummary.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
                .toList();
          }
        }

        if (followingRes.statusCode >= 200 && followingRes.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(followingRes.bodyBytes));
          if (decoded is List) {
            _followingUsers = decoded
                .whereType<Map>()
                .map(
                  (e) => CommunityFollowUserSummary.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('프로필 로드 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _closeProfile({int? selectedPostId}) {
    if (!mounted) return;
    Navigator.of(context).pop(
      CommunityUserProfileResult(
        selectedPostId: selectedPostId,
        didChangeFollow: _following != widget.isInitiallyFollowing || _didUserInfoChange,
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
                  color: _accent,
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
            color: const Color(0xFFFFF9F8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFF0E6E3),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLength: max,
            enabled: enabled,
            cursorColor: _accent,
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
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: _accent.withOpacity(0.35),
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
      if (mounted) setState(() => _isLoading = true);

      final currentUserId = widget.currentUserId;
      if ((currentUserId ?? '').isEmpty) {
        _showSnackBar("로그인 정보를 찾을 수 없어요.");
        return;
      }

      if (name.isNotEmpty) {
        await http.put(
          Uri.parse('${widget.baseUrl}/api/user/update-nickname'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "id": int.tryParse(currentUserId!),
            "nickname": name,
          }),
        );
      }

      if (uid.isNotEmpty && !_uidLocked) {
        await http.put(
          Uri.parse('${widget.baseUrl}/api/user/update-uid'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "id": int.tryParse(currentUserId!),
            "gameUid": uid,
          }),
        );
      }

      await _load();
      _didUserInfoChange = true;
      _showSnackBar("정보가 수정되었습니다! ✨");
    } catch (e) {
      debugPrint("업데이트 에러: $e");
      _showSnackBar("업데이트 실패");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final media = MediaQuery.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, media.padding.bottom + 76),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (_followSubmitting) return;

    final int? targetUserId = _effectiveAuthorUserId;
    final String currentUserId = (widget.currentUserId ?? '').trim();

    if (widget.isMine) {
      _showSnackBar('내 프로필은 팔로우할 수 없어요.');
      return;
    }

    if (targetUserId == null) {
      _showSnackBar('상대 사용자 정보를 불러오지 못했어요.');
      return;
    }

    if (currentUserId.isEmpty) {
      _showSnackBar('로그인 정보를 먼저 확인해주세요.');
      return;
    }

    try {
      setState(() => _followSubmitting = true);

      final uri = Uri.parse(
        '${widget.baseUrl}/api/community/follow/$targetUserId',
      ).replace(
        queryParameters: {'userId': currentUserId},
      );

      final response = _following ? await http.delete(uri) : await http.post(uri);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        setState(() {
          _following = !_following;
        });
        await _load();
        return;
      }

      final bodyText = utf8.decode(response.bodyBytes);
      if (!mounted) return;
      _showSnackBar(
        bodyText.isNotEmpty
            ? bodyText
            : (_following ? '언팔로우에 실패했어요.' : '팔로우에 실패했어요.'),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('팔로우 처리 중 문제가 발생했어요. $e');
    } finally {
      if (mounted) {
        setState(() => _followSubmitting = false);
      }
    }
  }

  void _openImageViewer(String imageUrl, String heroTag) {
    if (imageUrl.trim().isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.92),
        pageBuilder: (_, __, ___) => CommunityProfileImageViewerScreen(
          imageUrl: imageUrl,
          author: _nickname.isNotEmpty ? _nickname : widget.authorName,
          heroTag: heroTag,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: _resolvedHeaderImageUrl.isNotEmpty
          ? () => _openImageViewer(_resolvedHeaderImageUrl, 'profile_header')
          : null,
      child: Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          image: DecorationImage(
            image: _resolvedHeaderImageUrl.isNotEmpty
                ? NetworkImage(_resolvedHeaderImageUrl)
                : const AssetImage('assets/images/profile_header.png')
            as ImageProvider,
            fit: BoxFit.cover,
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.16),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final displayUid =
    _gameUid.trim().isNotEmpty ? _gameUid.trim() : widget.authorUid.trim();
    final displayName =
    _nickname.trim().isNotEmpty ? _nickname.trim() : widget.authorName.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 62, 20, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: _textMain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.translate(
                      offset: const Offset(0, 1.4),
                      child: _buildProfileCapsuleAction(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: displayUid.isNotEmpty
                          ? () {
                        Clipboard.setData(ClipboardData(text: displayUid));
                        _showSnackBar('UID가 복사되었어요.');
                      }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: displayUid.isNotEmpty
                              ? const Color(0xFFFFF7F4)
                              : const Color(0xFFFDF7F5),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: displayUid.isNotEmpty
                                ? const Color(0xFFF5D8CF)
                                : const Color(0xFFF2E4DE),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              displayUid.isNotEmpty
                                  ? Icons.badge_rounded
                                  : Icons.schedule_rounded,
                              size: 15,
                              color: displayUid.isNotEmpty
                                  ? const Color(0xFFD88C77)
                                  : const Color(0xFFCDA79C),
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                displayUid.isNotEmpty ? displayUid : 'UID를 입력해보세요',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w700,
                                  color: displayUid.isNotEmpty
                                      ? const Color(0xFFD88C77)
                                      : const Color(0xFFBE9A90),
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (displayUid.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.content_copy_rounded,
                                size: 13,
                                color: const Color(0xFFE2B3A4),
                              ),
                            ],
                          ],
                        ),
                      )
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.isMine
                      ? '내 프로필을 관리해보세요'
                      : _following
                      ? '팔로우 중인 타운키퍼예요.'
                      : '타운키퍼를 팔로우해보세요!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.4,
                    fontWeight: FontWeight.w700,
                    color: _textSub,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStatCard(
                        label: '팔로워',
                        value: _followers.length.toString(),
                        tone: const Color(0xFFFF8E7C),
                        onTap: () => _showFollowUsersSheet(
                          title: '팔로워',
                          users: _followers,
                          accent: const Color(0xFFFF8E7C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStatCard(
                        label: '팔로잉',
                        value: _followingUsers.length.toString(),
                        tone: const Color(0xFF8B73C7),
                        onTap: () => _showFollowUsersSheet(
                          title: '팔로잉',
                          users: _followingUsers,
                          accent: const Color(0xFF8B73C7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: -48,
            left: 0,
            right: 0,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: _resolvedProfileImageUrl.isNotEmpty
                        ? () => _openImageViewer(
                      _resolvedProfileImageUrl,
                      'profile_main',
                    )
                        : null,
                    child: Container(
                      width: 98,
                      height: 98,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        image: _resolvedProfileImageUrl.isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(_resolvedProfileImageUrl),
                          fit: BoxFit.cover,
                        )
                            : null,
                        color: _resolvedProfileImageUrl.isEmpty
                            ? const Color(0xFFFFF1EC)
                            : null,
                      ),
                      child: _resolvedProfileImageUrl.isEmpty
                          ? Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName.characters.first
                              : '?',
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            color: _accent,
                          ),
                        ),
                      )
                          : null,
                    ),
                  ),
                  if (widget.isMine)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _showProfileEditSheet,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFF0E3DC),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: _accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<CommunityProfilePostSeed> _postsByVisibility(String visibility) {
    return _recentPosts.where((e) => e.visibility == visibility).toList();
  }

  String _visibilitySectionTitle(String visibility) {
    switch (visibility) {
      case 'FOLLOWERS':
        return '팔로워 공개 글';
      case 'PRIVATE':
        return '나만보기 글';
      case 'PUBLIC':
      default:
        return '전체공개 글';
    }
  }

  Color _sectionAccent(String visibility) {
    switch (visibility) {
      case 'FOLLOWERS':
        return const Color(0xFFF3D36B);
      case 'PRIVATE':
        return const Color(0xFFC9B7FF);
      case 'PUBLIC':
      default:
        return _accent;
    }
  }

  void _showProfileEditSheet() {
    final nameController = TextEditingController(text: _nickname);
    final uidController = TextEditingController(
      text: _gameUid.trim().isEmpty ? "" : _gameUid,
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
                      color: _accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: _accent,
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

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildImageChangeButton(
                        label: '프로필 사진 변경',
                        icon: Icons.account_circle_rounded,
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          await _pickAndUploadImage(true);
                          if (mounted) _showProfileEditSheet();
                        }
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildImageChangeButton(
                      label: '배경 사진 변경',
                      icon: Icons.image_rounded,
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await _pickAndUploadImage(false);
                        if (mounted) _showProfileEditSheet();
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _accent.withOpacity(0.14),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: _accent,
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
                        _updateUserInfoOnServer(
                          name,
                          _uidLocked ? '' : uid,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
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

  Widget _buildImageChangeButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    const Color accentColor = Color(0xFFFF8E7C);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withOpacity(0.16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF636E72),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final ImagePicker _picker = ImagePicker();

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

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${widget.baseUrl}/api/user/upload-image'),
      );

      request.fields['userId'] = widget.currentUserId!;
      request.fields['type'] = isProfile ? "PROFILE" : "HEADER";

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          adjusted.bytes,
          filename: isProfile ? 'profile.png' : 'header.png',
          contentType: MediaType('image', 'png'),
        ),
      );

      final response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          final newUrl =
              "${widget.baseUrl}${data['url']}?t=${DateTime.now().millisecondsSinceEpoch}";

          if (isProfile) {
            _resolvedProfileImageUrl = newUrl;
          } else {
            _resolvedHeaderImageUrl = newUrl;
          }

          _didUserInfoChange = true;
        });

        _showSnackBar("이미지가 변경되었습니다! ✨");
      }
    } catch (e) {
      _showSnackBar("업로드 실패");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildCompactSectionHeader({
    required String title,
    required int count,
    required Color accent,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 16,
            color: accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14.2,
              fontWeight: FontWeight.w700,
              color: _textMain,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBFA),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withOpacity(0.18)),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11.4,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required String label,
    required String value,
    required Color tone,
    VoidCallback? onTap,
  }) {
    final IconData icon = label == '팔로워'
        ? Icons.people_alt_rounded
        : Icons.favorite_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tone.withOpacity(0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: tone.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tone.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: tone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w800,
                        color: _textSub,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _textMain,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: tone.withOpacity(0.72),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFollowUsersSheet({
    required String title,
    required List<CommunityFollowUserSummary> users,
    required Color accent,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.72,
              ),
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
                            title,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF3E332F),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accent.withOpacity(0.18),
                            ),
                          ),
                          child: Text(
                            '${users.length}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (users.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 28, 20, 34),
                      child: Text(
                        '표시할 사용자가 없어요.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9AA4B2),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF6ECE7),
                        ),
                        itemBuilder: (_, index) {
                          final user = users[index];
                          return _buildFollowUserTile(user, accent: accent);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFollowUserTile(
      CommunityFollowUserSummary user, {
        required Color accent,
      }) {
    final String resolvedImage = _resolveUrl(user.profileImageUrl);
    final bool hasImage = resolvedImage.trim().isNotEmpty;
    final String nickname =
    user.nickname.trim().isNotEmpty ? user.nickname.trim() : '사용자';
    final String uid =
    user.gameUid.trim().isNotEmpty ? user.gameUid.trim() : 'UID 없음';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF4EF),
              border: Border.all(color: const Color(0xFFF1E4DE)),
              image: hasImage
                  ? DecorationImage(
                image: NetworkImage(resolvedImage),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: !hasImage
                ? Center(
              child: Text(
                nickname.characters.first,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  uid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9AA4B2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostSection(String visibility) {
    final posts = _postsByVisibility(visibility);
    if (posts.isEmpty) return const SizedBox.shrink();

    final accent = _sectionAccent(visibility);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompactSectionHeader(
          title: _visibilitySectionTitle(visibility),
          count: posts.length,
          accent: accent,
          icon: visibility == 'PRIVATE'
              ? Icons.lock_rounded
              : visibility == 'FOLLOWERS'
              ? Icons.people_alt_rounded
              : Icons.public_rounded,
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            childAspectRatio: 0.80,
          ),
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildFixedGridCard(post);
          },
        ),
      ],
    );
  }

  Widget _buildFixedGridCard(CommunityProfilePostSeed post) {
    final String coverText =
    post.title.trim().isNotEmpty ? post.title.trim() : post.body.trim();

    final Color borderColor = post.isAdminPick
        ? const Color(0xFFFFB3A4)
        : post.mine
        ? const Color(0xFFF1E4DE)
        : post.isFollowingAuthor
        ? const Color(0xFFF3D36B)
        : const Color(0xFFCFE59A);

    return GestureDetector(
      onTap: () async {
        if (widget.onOpenPost != null) {
          await widget.onOpenPost!(post.id);
          return;
        }
        _closeProfile(selectedPostId: post.id);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.28,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (post.imageUrl.trim().isNotEmpty)
                      Image.network(
                        post.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _postFallback(),
                      )
                    else
                      _postFallback(),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (post.tags.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4EF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFF7D8CC),
                            ),
                          ),
                          child: Text(
                            '#${post.tags.first}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.6,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97A5D),
                              height: 1,
                            ),
                          ),
                        ),
                      if (post.tags.isNotEmpty) const SizedBox(height: 5),
                      Text(
                        coverText.isNotEmpty ? coverText : '제목 없는 글',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2F3941),
                          height: 1.28,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post.createdLabel.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.8,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF95A0AE),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 11,
                            color: const Color(0xFF95A0AE),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${post.commentCount}',
                            style: const TextStyle(
                              fontSize: 9.8,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF95A0AE),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            post.likedByMe
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 11,
                            color: post.likedByMe
                                ? const Color(0xFFFF8E7C)
                                : const Color(0xFF95A0AE),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${post.likeCount}',
                            style: TextStyle(
                              fontSize: 9.8,
                              fontWeight: FontWeight.w800,
                              color: post.likedByMe
                                  ? const Color(0xFFFF8E7C)
                                  : const Color(0xFF95A0AE),
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
    );
  }

  Widget _buildRecentPostSections() {
    if (_recentPosts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF0E3DC)),
        ),
        child: const Center(
          child: Text(
            '표시할 게시물이 없어요.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _textSub,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPostSection('PUBLIC'),
        if (_postsByVisibility('PUBLIC').isNotEmpty &&
            (_postsByVisibility('FOLLOWERS').isNotEmpty ||
                _postsByVisibility('PRIVATE').isNotEmpty))
          const SizedBox(height: 22),
        _buildPostSection('FOLLOWERS'),
        if (_postsByVisibility('FOLLOWERS').isNotEmpty &&
            _postsByVisibility('PRIVATE').isNotEmpty)
          const SizedBox(height: 22),
        _buildPostSection('PRIVATE'),
      ],
    );
  }

  Widget _postFallback() {
    return Container(
      color: const Color(0xFFFFF6F2),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Color(0xFFE1B3A8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: _textMain,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _textMain,
              size: 20,
            ),
            onPressed: _closeProfile,
          ),
          title: const Text(
            '프로필',
            style: TextStyle(
              color: _textMain,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: _accent),
        )
            : RefreshIndicator(
          onRefresh: _load,
          color: _accent,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              children: [
                _buildHeader(),
                Transform.translate(
                  offset: const Offset(0, -45),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 24),
                        _buildRecentPostSections(),
                        const SizedBox(height: 40),
                      ],
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
}

class CommunityProfileImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String author;
  final String heroTag;

  const CommunityProfileImageViewerScreen({
    super.key,
    required this.imageUrl,
    required this.author,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black.withOpacity(0.92)),
            ),
          ),
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.contain)
                  : const SizedBox.shrink(),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 18,
            child: Text(
              author,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

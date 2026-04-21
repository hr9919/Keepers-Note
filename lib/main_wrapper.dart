import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'community_uid_verification_screen.dart';
import 'community_uid_admin_screen.dart';
import 'community_screen.dart';
import 'community_write_screen.dart';
import 'community_user_profile_screen.dart';
import 'home_screen.dart';
import 'weather_admin_screen.dart';
import 'encyclopedia_screen.dart';
import 'cooking_screen.dart';
import 'gathering_screen.dart';
import 'pet_screen.dart';
import 'setting_screen.dart';
import 'pet_admin_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tip_guide_screen.dart';
import 'models/global_search_item.dart';
import 'event_screen.dart';
import 'models/event_item.dart';
import 'services/event_api_service.dart';
import 'services/community_tag_api_service.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';


class MainWrapper extends StatefulWidget {
  final Uri? initialDeepLink;

  const MainWrapper({
    super.key,
    this.initialDeepLink,
  });

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  int _searchResetSignal = 0;
  final TextEditingController _todoController = TextEditingController();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSub;
  StreamSubscription<String?>? _kakaoSchemeSub;

  final GatheringSearchController _gatheringSearchController =
  GatheringSearchController();
  final CookingSearchController _cookingSearchController =
  CookingSearchController();

  String _serverUserId = "";

  int? _initialCommunityPostId;

  int _communityOpenMyProfileSignal = 0;

  bool _isScrimPressed = false;
  bool _isDrawerOpen = false;
  bool _isEndDrawerOpen = false;
  bool _isAdmin = false;
  int _homeRefreshKey = 0;
  bool _isOpeningCommunityRoute = false;

  bool get _isCommunityTab => _selectedIndex == 2;
  bool _isCommunityMenuOpen = false;

  String? _pendingCommunityAction;
  bool _isLaunchingCommunityAction = false;

  int _communityRefreshSignal = 0;

  String _userName = "로그인 중...";
  String _userUid = "";
  String? _profileImageUrl;
  String? _headerImageUrl;

  GlobalSearchItem? _pendingSearchItem;

  List<Map<String, dynamic>> _todoTasks = [
    {"id": 0, "taskName": "가게 판매 품목 확인", "completed": false, "isSystem": true},
    {"id": 0, "taskName": "그자리 참나무 파밍", "completed": false, "isSystem": true},
    {"id": 0, "taskName": "완벽한 형광석 채집", "completed": false, "isSystem": true},
    {"id": 0, "taskName": "작물에 물 주기", "completed": false, "isSystem": true},
  ];

  List<EventItem> _eventList = [];

  static const List<String> _defaultSystemTasks = [
    "가게 판매 품목 확인",
    "그자리 참나무 파밍",
    "완벽한 형광석 채집",
    "작물에 물 주기",
  ];

  static const Duration _kPanelDuration = Duration(milliseconds: 360);
  static const Curve _kPanelCurve = Curves.easeOutCubic;

  String _normalizeTaskName(String name) {
    return name.replaceAll('\n', '').replaceAll('\r', '').trim();
  }

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _loadEvents();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = widget.initialDeepLink;
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    _bindDeepLinks();
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _kakaoSchemeSub?.cancel();
    _todoController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchCommunityUidStatus() async {
    if (_serverUserId.isEmpty) {
      await _fetchUserInfo();
    }

    if (_serverUserId.isEmpty) {
      return null;
    }

    final uri = Uri.parse(
      'https://api.keepers-note.o-r.kr/api/community/uid-verification/status',
    ).replace(
      queryParameters: {'userId': _serverUserId},
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadEvents() async {
    try {
      final events = await EventApiService.fetchActiveEvents();

      if (!mounted) return;
      setState(() {
        _eventList = events;
      });

      debugPrint('MainWrapper events loaded: ${events.length}');
    } catch (e) {
      debugPrint('이벤트 불러오기 실패: $e');
    }
  }

  void _bindDeepLinks() {
    _deepLinkSub?.cancel();
    _kakaoSchemeSub?.cancel();

    _deepLinkSub = _appLinks.uriLinkStream.listen(
          (Uri uri) {
        debugPrint('MainWrapper 실시간 딥링크 수신: $uri');
        _handleDeepLink(uri);
      },
      onError: (Object error) {
        debugPrint('MainWrapper 실시간 딥링크 오류: $error');
      },
    );

    _kakaoSchemeSub = kakaoSchemeStream.listen((String? url) {
      if (url == null || url.isEmpty) return;

      try {
        final Uri uri = Uri.parse(url);
        debugPrint('MainWrapper 카카오 스킴 수신: $uri');

        final String? target = uri.queryParameters['target'];
        final String? postId = uri.queryParameters['postId'];

        if (target == 'community_post' && postId != null) {
          final converted = Uri.parse(
            'https://keepersnote.app/community/post/$postId',
          );
          debugPrint('MainWrapper 카카오 공유 링크 변환: $converted');
          _handleDeepLink(converted);
          return;
        }

        _handleDeepLink(uri);
      } catch (e) {
        debugPrint('MainWrapper 카카오 스킴 처리 실패: $e');
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('딥링크 처리: $uri');

    int? postId;
    String? eventId;

    // 1) 카카오 execution params 우선 처리
    final target = uri.queryParameters['target'];
    final queryPostId = uri.queryParameters['postId'];
    final queryEventId = uri.queryParameters['eventId'];

    if (target == 'community_post' && queryPostId != null) {
      postId = int.tryParse(queryPostId);
    }

    if (target == 'event' && queryEventId != null && queryEventId.isNotEmpty) {
      eventId = queryEventId;
    }

    // 2) 커스텀 스킴: keepersnote://community/post/123
    if (postId == null && uri.scheme == 'keepersnote') {
      final host = uri.host;

      if (host == 'community' &&
          uri.pathSegments.length >= 2 &&
          uri.pathSegments[0] == 'post') {
        postId = int.tryParse(uri.pathSegments[1]);
      }

      if (host == 'event' && uri.pathSegments.isNotEmpty) {
        eventId = uri.pathSegments.first;
      }
    }

    // 3) https: https://keepersnote.app/community/post/123
    if (postId == null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == 'keepersnote.app') {
      final segments = uri.pathSegments;

      if (segments.length >= 3 &&
          segments[0] == 'community' &&
          segments[1] == 'post') {
        postId = int.tryParse(segments[2]);
      }

      if (segments.length >= 2 && segments[0] == 'event') {
        eventId = segments[1];
      }
    }

    if (postId != null) {
      debugPrint('게시글 이동: $postId');

      if (!mounted) return;

      // ⭐ 1. 먼저 null로 초기화
      setState(() {
        _selectedIndex = 2;
        _initialCommunityPostId = null;
      });

      // ⭐ 2. 다음 프레임에서 다시 넣기
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        setState(() {
          _initialCommunityPostId = postId;
        });
      });

      return;
    }
  }

  Future<void> _confirmAndSendMail() async {
    final bool? ok = await showDialog<bool>(
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
                      color: const Color(0xFFFF8E7C).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.mail_outline_rounded,
                      color: Color(0xFFFF8E7C),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '건의 메일 보내기',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D3436),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '메일 앱으로 이동해서 의견을 보낼 수 있어요',
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
                      onTap: () => Navigator.pop(dialogContext, false),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFF8E7C).withOpacity(0.14),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFFFF8E7C),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '불편한 점, 버그, 추가되면 좋은 기능을 알려주세요.',
                        style: TextStyle(
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
                      onPressed: () => Navigator.pop(dialogContext, false),
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
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8E7C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '메일 앱 열기',
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

    if (ok == true) {
      await _sendFeedbackEmail();
    }
  }

  Future<void> _sendFeedbackEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'mintblue1078@gmail.com',
      query: Uri.encodeFull(
        'subject=키퍼노트 건의사항&body=앱 사용 중 느낀 점 및 새로운 기능 건의 내용을 적어주세요 🙏',
      ),
    );

    try {
      await launchUrl(emailUri);
    } catch (e) {
      debugPrint('메일 실행 실패: $e');
    }
  }

  Future<void> _openDrawerSmooth() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isEndDrawerOpen) {
      setState(() => _isEndDrawerOpen = false);
      await Future.delayed(_kPanelDuration);
    }
    if (!mounted) return;
    setState(() => _isDrawerOpen = true);
  }

  Future<void> _openEndDrawerSmooth() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isDrawerOpen) {
      setState(() => _isDrawerOpen = false);
      await Future.delayed(_kPanelDuration);
    }
    if (!mounted) return;
    setState(() => _isEndDrawerOpen = true);
  }

  Future<void> _closeDrawerSmooth() async {
    if (!_isDrawerOpen) return;
    setState(() => _isDrawerOpen = false);
    await Future.delayed(_kPanelDuration);
  }

  Future<void> _closeEndDrawerSmooth() async {
    if (!_isEndDrawerOpen) return;
    setState(() => _isEndDrawerOpen = false);
    await Future.delayed(_kPanelDuration);
  }

  Future<void> _fetchUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final provider = prefs.getString('authProvider');
      final providerUserId = prefs.getString('providerUserId');
      final storedNickname = prefs.getString('nickname') ?? '사용자';
      final storedProfileImageUrl = prefs.getString('profileImageUrl');

      if (provider == null || providerUserId == null) {
        debugPrint('_fetchUserInfo 실패: 저장된 로그인 정보 없음');
        return;
      }

      final response = await http.post(
        Uri.parse('https://api.keepers-note.o-r.kr/api/user/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "provider": provider,
          "providerUserId": providerUserId,
          "nickname": storedNickname,
          "profileImageUrl": storedProfileImageUrl,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final serverUserId = data['id']?.toString() ?? '';

        await prefs.setString('userId', serverUserId);

        setState(() {
          final gameUid = data['gameUid']?.toString().trim() ?? '';
          _serverUserId = serverUserId;
          _userUid = gameUid.isNotEmpty ? gameUid : 'UID를 입력해보세요';
          _userName = data['nickname'] ?? "사용자";
          _isAdmin = data['isAdmin'] ?? false;

          if (data['profileImageUrl'] != null) {
            _profileImageUrl =
            "https://api.keepers-note.o-r.kr${data['profileImageUrl']}?t=${DateTime.now().millisecondsSinceEpoch}";
          } else {
            _profileImageUrl = storedProfileImageUrl;
          }

          if (data['headerImageUrl'] != null) {
            _headerImageUrl =
            "https://api.keepers-note.o-r.kr${data['headerImageUrl']}?t=${DateTime.now().millisecondsSinceEpoch}";
          } else {
            _headerImageUrl = null;
          }
        });

        await _loadTodoFromServer(serverUserId);
      } else {
        if (!mounted) return;
        setState(() {
          _userUid = 'UID를 입력해보세요';
        });
      }
    } catch (e) {
      debugPrint("_fetchUserInfo 실패: $e");
    }
  }

  Future<void> _loadTodoFromServer([String? userId]) async {
    final targetUserId = userId ?? _serverUserId;
    if (targetUserId.isEmpty || targetUserId == "UID를 입력해보세요") return;

    try {
      final response = await http.get(
        Uri.parse('https://api.keepers-note.o-r.kr/api/todo/$targetUserId'),
      );

      if (response.statusCode != 200) return;

      final List<dynamic> decodedData = jsonDecode(utf8.decode(response.bodyBytes));

      List<Map<String, dynamic>> mapped = decodedData.map((task) {
        return {
          "id": task['id'],
          "taskName": task['taskName'],
          "completed": (task['completed'] == true ||
              task['completed'] == 1 ||
              task['completed'].toString().contains('1')) ||
              (task['isCompleted'] == true ||
                  task['isCompleted'] == 1 ||
                  task['isCompleted'].toString().contains('1')),
          "isSystem": (task['isSystem'] == true ||
              task['isSystem'] == 1 ||
              task['isSystem'].toString().contains('1')),
        };
      }).toList();

      if (mapped.isEmpty) {
        for (final taskName in _defaultSystemTasks) {
          await http.post(
            Uri.parse('https://api.keepers-note.o-r.kr/api/todo/add'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "userId": targetUserId,
              "taskName": taskName,
            }),
          );
        }
        await _loadTodoFromServer(targetUserId);
        return;
      }

      final existingNames =
      mapped.map((e) => _normalizeTaskName(e["taskName"] ?? "")).toSet();

      bool addedMissingDefault = false;

      for (final taskName in _defaultSystemTasks) {
        if (!existingNames.contains(_normalizeTaskName(taskName))) {
          addedMissingDefault = true;
          await http.post(
            Uri.parse('https://api.keepers-note.o-r.kr/api/todo/add'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "userId": targetUserId,
              "taskName": taskName,
            }),
          );
        }
      }

      if (addedMissingDefault) {
        await _loadTodoFromServer(targetUserId);
        return;
      }

      if (!mounted) return;
      setState(() {
        _todoTasks = mapped;
      });
    } catch (_) {}
  }

  Future<void> _openTipGuideScreen() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_isDrawerOpen) {
      await _closeDrawerSmooth();
    }

    if (_isEndDrawerOpen) {
      await _closeEndDrawerSmooth();
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TipGuideScreen(),
      ),
    );
  }

  void _handleCenterCommunityButton() {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_isDrawerOpen || _isEndDrawerOpen) return;

    setState(() {
      if (_isCommunityTab) {
        _isCommunityMenuOpen = !_isCommunityMenuOpen;
      } else {
        _selectedIndex = 2;
        _isCommunityMenuOpen = false; // 진입만 하고 메뉴는 닫힌 상태
        _pendingSearchItem = null;
        _searchResetSignal++;
      }
    });
  }

  void _toggleTodo(int index) async {
    final taskId = _todoTasks[index]['id'];
    if (taskId == 0) return;

    final previous = _todoTasks[index]['completed'];

    setState(() {
      _todoTasks[index]['completed'] = !previous;
    });

    try {
      final response = await http.put(
        Uri.parse('https://api.keepers-note.o-r.kr/api/todo/toggle/$taskId'),
      );

      if (response.statusCode != 200 && mounted) {
        setState(() {
          _todoTasks[index]['completed'] = previous;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _todoTasks[index]['completed'] = previous;
        });
      }
      debugPrint("_toggleTodo 실패: $e");
    }
  }

  void _addTodo() async {
    final taskName = _todoController.text
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .trim();

    if (taskName.isEmpty) return;

    if (_serverUserId.isEmpty) {
      await _fetchUserInfo();
    }

    if (_serverUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 불러오는 중이에요. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.keepers-note.o-r.kr/api/todo/add'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": _serverUserId,
          "taskName": taskName,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        FocusManager.instance.primaryFocus?.unfocus();
        _todoController.clear();
        await _loadTodoFromServer(_serverUserId);
      }
    } catch (e) {
      debugPrint("_addTodo 실패: $e");
    }
  }

  void _deleteTodo(int index) async {
    final taskId = _todoTasks[index]['id'];
    if (taskId == 0) return;

    try {
      final response = await http.delete(
        Uri.parse('https://api.keepers-note.o-r.kr/api/todo/$taskId'),
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _todoTasks.removeAt(index);
        });
      }
    } catch (_) {}
  }

  void _handleSixAMReset() async {
    await _loadTodoFromServer();
  }

  Future<void> _onRefreshData() async {
    await _loadTodoFromServer();
  }

  Future<void> _onMenuSelect(int index) async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_isDrawerOpen) {
      await _closeDrawerSmooth();
    }

    if (_isEndDrawerOpen) {
      await _closeEndDrawerSmooth();
    }

    if (!mounted) return;

    setState(() {
      _selectedIndex = index;
      _isCommunityMenuOpen = false;
      _pendingSearchItem = null;
      _searchResetSignal++;
    });
  }

  Future<void> _handleGlobalSearchSelection(GlobalSearchItem item) async {
    FocusManager.instance.primaryFocus?.unfocus();

    int targetIndex = 0;

    switch (item.screen) {
      case SearchTargetScreen.gathering:
        targetIndex = 1;
        break;
      case SearchTargetScreen.cooking:
        targetIndex = 3;
        break;
      case SearchTargetScreen.pet:
        targetIndex = 4;
        break;
      case SearchTargetScreen.encyclopedia:
        targetIndex = 1;
        break;
    }

    if (!mounted) return;

    setState(() {
      _selectedIndex = targetIndex;
      _isCommunityMenuOpen = false;
      _pendingSearchItem = null;
      _searchResetSignal++;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        switch (item.screen) {
          case SearchTargetScreen.gathering:
            _gatheringSearchController.open(item);
            break;

          case SearchTargetScreen.cooking:
            _cookingSearchController.open(item);
            break;

          case SearchTargetScreen.pet:
            setState(() {
              _pendingSearchItem = item;
            });
            break;

          case SearchTargetScreen.encyclopedia:
            _gatheringSearchController.open(item);
            break;
        }
      });
    });
  }

  void _showImageViewer({
    required ImageProvider imageProvider,
    required bool isProfile,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'image_viewer',
      barrierColor: Colors.black.withOpacity(0.9),
      pageBuilder: (context, animation, secondaryAnimation) {
        final size = MediaQuery.of(context).size;

        return SafeArea(
          child: Stack(
            children: [
              // 🔥 배경 (터치 시 닫힘)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: size.width,
                  height: size.height,
                  color: Colors.black.withOpacity(0.9),
                ),
              ),

              // 🔥 이미지 영역 (터치 이벤트 막기)
              Center(
                child: GestureDetector(
                  onTap: () {}, // 👉 이벤트 막기 (닫힘 방지)
                  child: isProfile
                      ? Hero(
                    tag: 'drawer_profile_image',
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          width: size.width * 0.72,
                          height: size.width * 0.72,
                          child: Image(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  )
                      : InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: size.width * 0.92,
                        child: Image(
                          image: imageProvider,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  Future<void> _openEventScreen() async {
    if (_isDrawerOpen) {
      await _closeDrawerSmooth();
    }

    if (_isEndDrawerOpen) {
      await _closeEndDrawerSmooth();
    }

    if (!mounted) return;

    await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventScreen(
            isAdmin: false,
            canManage: _isAdmin,
          ),
        )
    );

    await _loadEvents();
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '앱 종료',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '키퍼노트를 종료하시겠습니까?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFD7DEE7)),
                          minimumSize: const Size.fromHeight(40),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8E7C),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(40),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '종료',
                          style: TextStyle(
                            fontSize: 13,
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
        );
      },
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    final List<Widget> pages = [
      HomeScreen(
        key: ValueKey('home_$_homeRefreshKey'),
        openDrawer: _openDrawerSmooth,
        openEndDrawer: _openEndDrawerSmooth,
        openEventScreen: _openEventScreen,
        todoList: _todoTasks,
        onTodoToggle: (index) => _toggleTodo(index),
        onResetAll: _handleSixAMReset,
        onRefresh: () async {
          await _onRefreshData();
          await _loadEvents();
        },
        onSearchItemSelected: _handleGlobalSearchSelection,
        eventList: _eventList,
        userId: _serverUserId,
        isAdmin: _isAdmin,
        resetSearchSignal: _searchResetSignal,
      ),
      GatheringScreen(
        openDrawer: _openDrawerSmooth,
        searchController: _gatheringSearchController,
        resetSearchSignal: _searchResetSignal,
      ),
      CommunityScreen(
        key: ValueKey('community_${_initialCommunityPostId ?? 'none'}'),
        openDrawer: _openDrawerSmooth,
        userId: _serverUserId,
        isAdmin: _isAdmin,
        initialPostId: _selectedIndex == 2 ? _initialCommunityPostId : null,
        refreshSignal: _communityRefreshSignal,
        openMyProfileSignal: _communityOpenMyProfileSignal,
      ),
      CookingScreen(
        openDrawer: _openDrawerSmooth,
        searchController: _cookingSearchController,
        resetSearchSignal: _searchResetSignal,
        userId: _serverUserId,
        isAdmin: _isAdmin,
      ),
      PetScreen(
        key: const ValueKey('pet_tab'),
        openDrawer: _openDrawerSmooth,
        initialSearchItem: _pendingSearchItem,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        FocusManager.instance.primaryFocus?.unfocus();

        if (_isDrawerOpen) {
          await _closeDrawerSmooth();
          return;
        }

        if (_isEndDrawerOpen) {
          await _closeEndDrawerSmooth();
          return;
        }

        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
            _pendingSearchItem = null;
            _searchResetSignal++;
          });
          return;
        }

        final shouldExit = await _showExitConfirmationDialog(context);
        if (!mounted) return;

        if (shouldExit) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: pages,
            ),

            IgnorePointer(
              ignoring: !_isCommunityMenuOpen || !_isCommunityTab,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                opacity: (_isCommunityMenuOpen && _isCommunityTab) ? 1.0 : 0.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _isCommunityMenuOpen = false;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: _isCommunityMenuOpen && _isCommunityTab ? 3.5 : 0,
                        sigmaY: _isCommunityMenuOpen && _isCommunityTab ? 3.5 : 0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: _isCommunityMenuOpen && _isCommunityTab
                                ? [
                              Colors.black.withOpacity(0.08),
                              Colors.black.withOpacity(0.14),
                              Colors.black.withOpacity(0.18),
                            ]
                                : [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                duration: _kPanelDuration,
                curve: _kPanelCurve,
                offset: (_isDrawerOpen || _isEndDrawerOpen)
                    ? const Offset(0, 1.2)
                    : Offset.zero,
                child: AnimatedOpacity(
                  duration: _kPanelDuration,
                  curve: _kPanelCurve,
                  opacity: (_isDrawerOpen || _isEndDrawerOpen) ? 0.0 : 1.0,
                  child: SizedBox(
                    height: 440,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            ignoring: _isDrawerOpen || _isEndDrawerOpen,
                            child: _buildBottomNavigationBar(bottomPadding),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildCommunityOverlay(bottomPadding),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 바깥 배경
            IgnorePointer(
              ignoring: !(_isDrawerOpen || _isEndDrawerOpen),
              child: AnimatedOpacity(
                duration: _kPanelDuration,
                curve: _kPanelCurve,
                opacity: (_isDrawerOpen || _isEndDrawerOpen) ? 1.0 : 0.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    setState(() {
                      _isScrimPressed = true;
                    });
                  },
                  onTapCancel: () {
                    setState(() {
                      _isScrimPressed = false;
                    });
                  },
                  onTapUp: (_) async {
                    FocusManager.instance.primaryFocus?.unfocus();

                    await Future.delayed(const Duration(milliseconds: 70));
                    if (!mounted) return;

                    setState(() {
                      _isScrimPressed = false;
                    });

                    if (_isDrawerOpen) {
                      await _closeDrawerSmooth();
                    } else if (_isEndDrawerOpen) {
                      await _closeEndDrawerSmooth();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    color: _isScrimPressed
                        ? Colors.black.withOpacity(0.28)
                        : Colors.black.withOpacity(0.22),
                  ),
                ),
              ),
            ),

            _buildCustomLeftPanel(bottomPadding),
            _buildCustomRightPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomLeftPanel(double bottomPadding) {
    final double panelWidth = MediaQuery.of(context).size.width * 0.82;

    return AnimatedPositioned(
      duration: _kPanelDuration,
      curve: _kPanelCurve,
      left: _isDrawerOpen ? 0 : -panelWidth - 24,
      top: 0,
      bottom: 0,
      child: AnimatedScale(
        duration: _kPanelDuration,
        curve: _kPanelCurve,
        scale: _isDrawerOpen ? 1.0 : 0.985,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: panelWidth,
          child: _buildCommonDrawerPanel(bottomPadding),
        ),
      ),
    );
  }

  Widget _buildCustomRightPanel() {
    final double panelWidth = MediaQuery.of(context).size.width * 0.85;

    return AnimatedPositioned(
      duration: _kPanelDuration,
      curve: _kPanelCurve,
      right: _isEndDrawerOpen ? 0 : -panelWidth - 24,
      top: 0,
      bottom: 0,
      child: AnimatedScale(
        duration: _kPanelDuration,
        curve: _kPanelCurve,
        scale: _isEndDrawerOpen ? 1.0 : 0.985,
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: panelWidth,
          child: _buildTodoDrawerPanel(),
        ),
      ),
    );
  }

  Widget _buildTodoDrawerPanel() {
    final int doneCount = _todoTasks.where((t) => t['completed'] == true).length;
    final int totalCount = _todoTasks.length;
    final double progress = totalCount == 0 ? 0 : doneCount / totalCount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBFA),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(34),
                  bottomLeft: Radius.circular(34),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 30,
                    offset: const Offset(-8, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTodoHeader(progress, doneCount, totalCount),
                  const SizedBox(height: 4),
                  Expanded(
                    child: _buildTodoListArea(),
                  ),
                  _buildTodoInputArea(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodoHeader(double progress, int doneCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF8E7C).withOpacity(0.08),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    '📝',
                    style: TextStyle(fontSize: 19),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의 할 일',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '오늘의 할 일을 놓치지 말고 체크하세요!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    await _closeEndDrawerSmooth();
                  },
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: const Color(0xFFFF8E7C),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$doneCount / $totalCount',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF8E7C),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '오전 06:00에 모든 항목이 초기화돼요.',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoListArea() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      physics: const BouncingScrollPhysics(),
      itemCount: _todoTasks.length,
      itemBuilder: (context, index) {
        return _buildTodoTile(_todoTasks[index], index);
      },
    );
  }

  Widget _buildTodoTile(Map<String, dynamic> todo, int index) {
    final bool isDone = todo['completed'] == true;

    final String displayTaskName = (todo['taskName'] ?? '')
        .toString()
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .trim();

    final bool isDefaultTask = const [
      "가게 판매 품목 확인",
      "그자리 참나무 파밍",
      "완벽한 형광석 채집",
      "작물에 물 주기",
    ].contains(displayTaskName);

    const TextStyle todoTextStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.35,
      color: Color(0xFF1E293B),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _toggleTodo(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFFFFF8F6)
                  : Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDone
                    ? const Color(0xFFFFD8D0)
                    : const Color(0xFFF1F5F9),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFFFF8E7C)
                        : const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFFFF8E7C)
                          : const Color(0xFFD9E2EC),
                      width: 1.4,
                    ),
                  ),
                  child: isDone
                      ? const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  )
                      : null,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final textWidth = _measureTodoTextWidth(
                        text: displayTaskName,
                        style: todoTextStyle,
                        maxWidth: constraints.maxWidth,
                      );

                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Text(
                            displayTaskName,
                            softWrap: true,
                            strutStyle: const StrutStyle(
                              forceStrutHeight: true,
                              fontSize: 14.5,
                              height: 1.35,
                            ),
                            style: todoTextStyle.copyWith(
                              color: isDone
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          if (isDone)
                            IgnorePointer(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Transform.translate(
                                  offset: const Offset(0, 0.5),
                                  child: Container(
                                    width: textWidth,
                                    height: 1.0,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF94A3B8).withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: (todo['isSystem'] != true && !isDefaultTask)
                      ? Material(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _deleteTodo(index),
                      child: const Center(
                        child: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _measureTodoTextWidth({
    required String text,
    required TextStyle style,
    required double maxWidth,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    return textPainter.size.width;
  }

  Widget _buildTodoInputArea() {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double systemBottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: keyboardHeight > 0
            ? keyboardHeight + 12
            : (systemBottomPadding > 0 ? 12 : 16),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFFF8E7C).withOpacity(0.08),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFEAEFF5),
                ),
              ),
              child: TextField(
                controller: _todoController,
                onSubmitted: (_) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _addTodo();
                },
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
                decoration: InputDecoration(
                  hintText: "오늘 뭐 할까요?",
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      Icons.edit_note_rounded,
                      size: 20,
                      color: Color(0xFFFF8E7C),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: const Color(0xFFFF8E7C),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                _addTodo();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8E7C).withOpacity(0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonDrawerPanel(double bottomPadding) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 18, 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBFA),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(34),
                bottomRight: Radius.circular(34),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 30,
                  offset: const Offset(8, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildPrettyDrawerHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDrawerItem(
                          icon: Icons.lightbulb_rounded,
                          title: '키퍼노트 가이드',
                          subtitle: '앱 기능 소개',
                          isSelected: false,
                          accentColor: const Color(0xFFFFC457),
                          onTap: () async {
                            await Future.delayed(const Duration(milliseconds: 110));
                            if (!mounted) return;
                            await _openTipGuideScreen();
                          },
                        ),
                        _buildDrawerItem(
                          icon: Icons.collections_bookmark_rounded,
                          title: '업적 및 아이템 도감',
                          subtitle: '도감 화면으로 이동',
                          isSelected: false,
                          accentColor: const Color(0xFFFF9F5A),
                          onTap: () async {
                            await Future.delayed(const Duration(milliseconds: 110));
                            if (!mounted) return;
                            await _closeDrawerSmooth();
                            if (!mounted) return;

                            setState(() {
                              _selectedIndex = 0;
                              _pendingSearchItem = null;
                              _searchResetSignal++;
                            });

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EncyclopediaScreen(
                                  openDrawer: _openDrawerSmooth,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildDrawerItem(
                          icon: Icons.mail_outline_rounded,
                          title: '피드백 보내기',
                          subtitle: '아이디어를 보내주세요',
                          isSelected: false,
                          accentColor: const Color(0xFF78C3FF),
                          onTap: () async {
                            await Future.delayed(const Duration(milliseconds: 110));
                            if (!mounted) return;
                            await _closeDrawerSmooth();
                            if (!mounted) return;
                            await _confirmAndSendMail();
                          },
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(height: 10),
                          _buildDrawerItem(
                            icon: Icons.cloud_rounded,
                            title: '주간 날씨 수정',
                            subtitle: '관리자 전용 메뉴',
                            isSelected: false,
                            accentColor: const Color(0xFFB8BEC8),
                            onTap: () async {
                              FocusManager.instance.primaryFocus?.unfocus();

                              await Future.delayed(const Duration(milliseconds: 110));
                              if (!mounted) return;

                              await _closeDrawerSmooth();
                              if (!mounted) return;

                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WeatherAdminScreen(),
                                ),
                              );

                              if (!mounted) return;

                              if (changed == true) {
                                setState(() {
                                  _homeRefreshKey++;
                                });
                              }
                            },
                          ),
                          _buildDrawerItem(
                            icon: Icons.pets_rounded,
                            title: '펫 등록',
                            subtitle: '관리자 전용 메뉴',
                            isSelected: false,
                            accentColor: const Color(0xFFFFB36B),
                            onTap: () async {
                              FocusManager.instance.primaryFocus?.unfocus();

                              await Future.delayed(const Duration(milliseconds: 110));
                              if (!mounted) return;

                              await _closeDrawerSmooth();
                              if (!mounted) return;

                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PetAdminScreen(
                                    userId: _serverUserId,
                                  ),
                                ),
                              );

                              if (!mounted) return;

                              if (changed == true) {
                                setState(() {
                                  _homeRefreshKey++;
                                });
                              }
                            },
                          ),
                        ],
                        SizedBox(height: bottomPadding > 0 ? bottomPadding : 20),
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

  Future<void> _openCommunityWrite() async {
    if (_isOpeningCommunityRoute) return;

    if (_serverUserId.isEmpty) {
      await _fetchUserInfo();
    }

    if (_serverUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 불러오는 중이에요. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }

    _isOpeningCommunityRoute = true;

    try {
      final status = await _fetchCommunityUidStatus();
      final bool isLocked = status?['uidLocked'] == true;

      if (!mounted) return;

      if (!isLocked) {
        final bool? requested = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityUidVerificationScreen(
              userId: _serverUserId,
            ),
          ),
        );

        if (!mounted) return;

        await _fetchUserInfo();

        if (requested == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('UID 인증 요청이 접수되었어요. 승인 후 글쓰기를 이용할 수 있어요.'),
            ),
          );
        }
        return;
      }

      final availableTags = await CommunityTagApiService.fetchActiveTags();
      final tagNames = availableTags
          .map((e) => e.tagName)
          .where((e) => e.trim().isNotEmpty)
          .toList();

      if (!mounted) return;

      final bool? created = await CommunityScreen.openWrite(
        context,
        userId: _serverUserId,
        availableTags: tagNames.isEmpty ? const <String>['전체'] : tagNames,
      );

      if (!mounted) return;

      if (created == true) {
        setState(() {
          _selectedIndex = 2;
          _isCommunityMenuOpen = false;
          _pendingSearchItem = null;
          _initialCommunityPostId = null;
          _communityRefreshSignal++;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시글이 등록되었어요.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('글쓰기 화면을 여는 중 문제가 발생했어요. $e')),
      );
    } finally {
      _isOpeningCommunityRoute = false;
    }
  }

  Future<void> _openCommunityAdmin() async {
    if (_isOpeningCommunityRoute) return;

    if (_serverUserId.isEmpty) {
      await _fetchUserInfo();
    }

    if (_serverUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 불러오는 중이에요. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }

    if (!_isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자만 접근할 수 있어요.')),
      );
      return;
    }

    _isOpeningCommunityRoute = true;

    try {
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityUidAdminScreen(
            userId: _serverUserId,
          ),
        ),
      );

      if (!mounted) return;

      setState(() {
        _communityRefreshSignal++;
      });
    } finally {
      _isOpeningCommunityRoute = false;
    }
  }

  Widget _buildPrettyDrawerHeader() {
    final ImageProvider headerProvider = _headerImageUrl != null
        ? NetworkImage(_headerImageUrl!)
        : const AssetImage('assets/images/profile_header.png');

    final ImageProvider profileProvider = _profileImageUrl != null
        ? NetworkImage(_profileImageUrl!)
        : const AssetImage('assets/images/profile_image.png');

    final bool hasUid = _userUid.isNotEmpty && _userUid != 'UID를 입력해보세요';
    final String displayUid = hasUid ? _userUid : 'UID를 입력해보세요';

    return GestureDetector(
      onTap: () {
        _showImageViewer(
          imageProvider: headerProvider,
          isProfile: false,
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(34),
          ),
          image: DecorationImage(
            image: headerProvider,
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 18, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.12),
                Colors.black.withOpacity(0.30),
              ],
            ),
          ),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _showImageViewer(
                        imageProvider: profileProvider,
                        isProfile: true,
                      );
                    },
                    child: Hero(
                      tag: 'drawer_profile_image',
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          image: DecorationImage(
                            image: profileProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 42),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_userName 님',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () async {
                                final status = await _fetchCommunityUidStatus();
                                final bool isLocked = status?['uidLocked'] == true;

                                if (!isLocked) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CommunityUidVerificationScreen(
                                        userId: _serverUserId,
                                      ),
                                    ),
                                  );

                                  if (!mounted) return;
                                  await _fetchUserInfo();
                                  return;
                                }

                                await Clipboard.setData(
                                  ClipboardData(text: displayUid),
                                );

                                if (!mounted) return;
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        18,
                                      ),
                                      backgroundColor: const Color(0xFF2B3440),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      duration: const Duration(seconds: 2),
                                      content: Row(
                                        children: const [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'UID가 복사되었어요',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                              },
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(hasUid ? 0.18 : 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(
                                      hasUid ? 0.26 : 0.16,
                                    ),
                                  ),
                                  boxShadow: hasUid
                                      ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
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
                                      hasUid
                                          ? Icons.badge_rounded
                                          : Icons.edit_note_rounded,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.96),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        displayUid,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.8,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withOpacity(0.96),
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                    ),
                                    if (hasUid) ...[
                                      const SizedBox(width: 7),
                                      Icon(
                                        Icons.content_copy_rounded,
                                        size: 13,
                                        color: Colors.white.withOpacity(0.88),
                                      ),
                                    ] else ...[
                                      const SizedBox(width: 7),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 13,
                                        color: Colors.white.withOpacity(0.88),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasUid
                                ? '즐거운 타운생활 되세요!'
                                : '프로필을 설정해보세요!',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () async {
                      FocusManager.instance.primaryFocus?.unfocus();
                      await _closeDrawerSmooth();

                      if (!mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );

                      _fetchUserInfo();
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    Color accentColor = const Color(0xFFFF8E7C),
  }) {
    final Color effectiveAccent =
    isSelected ? const Color(0xFFFF8E7C) : accentColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: effectiveAccent.withOpacity(0.16),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            splashColor: effectiveAccent.withOpacity(0.12),
            highlightColor: effectiveAccent.withOpacity(0.06),
            overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.pressed)) {
                return effectiveAccent.withOpacity(0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return effectiveAccent.withOpacity(0.04);
              }
              return null;
            }),
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 0, 14, 0),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 72,
                    margin: const EdgeInsets.only(
                      left: 0,
                      top: 10,
                      bottom: 10,
                      right: 14,
                    ),
                    decoration: BoxDecoration(
                      color: effectiveAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: effectiveAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: effectiveAccent.withOpacity(0.16),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: effectiveAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2D3436),
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8A94A6),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: effectiveAccent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: effectiveAccent,
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

  Widget _buildBottomNavigationBar(double bottomPadding) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        bottomPadding > 0 ? bottomPadding + 6 : 12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.74),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.58),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 22,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNavItem(
                  index: 0,
                  label: '홈',
                  outlinedIcon: Icons.home_outlined,
                  filledIcon: Icons.home_rounded,
                ),
                _buildNavItem(
                  index: 1,
                  label: '채집',
                  outlinedIcon: Icons.phishing_outlined,
                  filledIcon: Icons.phishing_rounded,
                ),
                const SizedBox(width: 90),
                _buildNavItem(
                  index: 3,
                  label: '요리',
                  outlinedIcon: Icons.soup_kitchen_outlined,
                  filledIcon: Icons.soup_kitchen,
                ),
                _buildNavItem(
                  index: 4,
                  label: '펫',
                  outlinedIcon: Icons.pets_outlined,
                  filledIcon: Icons.pets,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityOverlay(double bottomPadding) {
    final bool isDropUpOpen = _isCommunityTab && _isCommunityMenuOpen;
    final double navBottom = bottomPadding > 0 ? bottomPadding + 6 : 12;

    return IgnorePointer(
      ignoring: _isDrawerOpen || _isEndDrawerOpen,
      child: SizedBox(
        height: 440,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              bottom: navBottom + (isDropUpOpen ? 96 : 84),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: isDropUpOpen ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !isDropUpOpen,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    offset: isDropUpOpen
                        ? Offset.zero
                        : const Offset(0, 0.05),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCommunityMenuBubble(
                          icon: Icons.edit_rounded,
                          label: '글쓰기',
                          onTap: () {
                            _closeCommunityMenuAndRun('write');
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildCommunityMenuBubble(
                          icon: Icons.person_rounded,
                          label: '내 프로필 보기',
                          onTap: () {
                            _closeCommunityMenuAndRun('my_profile');
                          },
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(height: 12),
                          _buildCommunityMenuBubble(
                            icon: Icons.verified_user_rounded,
                            label: '관리 메뉴',
                            onTap: () {
                              _closeCommunityMenuAndRun('uid_admin');
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: navBottom,
              child: _buildCenterCommunityItem(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runQueuedCommunityAction() async {
    if (_isLaunchingCommunityAction) return;

    final action = _pendingCommunityAction;
    if (action == null) return;

    _isLaunchingCommunityAction = true;

    try {
      await Future.delayed(const Duration(milliseconds: 420));
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 80));

      if (!mounted) return;

      _pendingCommunityAction = null;

      if (action == 'write') {
        await _openCommunityWrite();
      } else if (action == 'my_profile') {
        if (!mounted) return;
        setState(() {
          _selectedIndex = 2;
          _isCommunityMenuOpen = false;
          _pendingSearchItem = null;
          _searchResetSignal++;
          _communityOpenMyProfileSignal++;
        });
      } else if (action == 'uid_admin') {
        await _openCommunityAdmin();
      }
    } finally {
      _isLaunchingCommunityAction = false;
    }
  }

  Future<void> _closeCommunityMenuAndRun(String action) async {
    if (_isOpeningCommunityRoute) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _pendingCommunityAction = action;
      _isCommunityMenuOpen = false;
    });

    await Future.delayed(_kPanelDuration);
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    final pending = _pendingCommunityAction;
    _pendingCommunityAction = null;

    if (pending == 'write') {
      await _openCommunityWrite();
    } else if (pending == 'my_profile') {
      setState(() {
        _selectedIndex = 2;
        _pendingSearchItem = null;
        _searchResetSignal++;
        _communityOpenMyProfileSignal++;
      });
    } else if (pending == 'uid_admin') {
      await _openCommunityAdmin();
    }
  }

  Widget _buildCenterCommunityItem() {
    final bool isSelected = _isCommunityTab;
    final bool isDropUpOpen = _isCommunityTab && _isCommunityMenuOpen;

    const Color selectedColor = Color(0xFFFF8E7C);
    const Color selectedDark = Color(0xFFF47F69);
    const Color unselectedColor = Color(0xFF98A2B3);

    final bool useRoundButton = isSelected;

    final double buttonWidth = useRoundButton ? 62 : 74;
    final double buttonHeight = useRoundButton ? 62 : 56;

    final Decoration decoration = BoxDecoration(
      gradient: useRoundButton
          ? const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFAF9B),
          selectedColor,
          selectedDark,
        ],
      )
          : null,
      color: useRoundButton ? null : Colors.transparent,
      borderRadius: BorderRadius.circular(useRoundButton ? 31 : 22),
      border: Border.all(
        color: useRoundButton
            ? Colors.white.withOpacity(0.34)
            : Colors.transparent,
        width: 1.1,
      ),
      boxShadow: useRoundButton
          ? [
        BoxShadow(
          color: selectedColor.withOpacity(0.24),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ]
          : [],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleCenterCommunityButton,
      child: SizedBox(
        width: 92,
        height: 92,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              bottom: useRoundButton ? 18 : 7,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: buttonWidth,
                height: buttonHeight,
                decoration: decoration,
                alignment: Alignment.center,
                child: useRoundButton
                    ? TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(
                    begin: 0,
                    end: isDropUpOpen ? 1 : 0,
                  ),
                  builder: (context, value, child) {
                    return Transform.rotate(
                      angle: value * 3.14,
                      child: Transform.scale(
                        scale: 0.9 + (value * 0.1),
                        child: Icon(
                          isDropUpOpen
                              ? Icons.close_rounded
                              : Icons.favorite_rounded,
                          size: 28,
                          color: Colors.white.withOpacity(0.7 + (value * 0.3)),
                        ),
                      ),
                    );
                  },
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_rounded,
                      size: 21,
                      color: unselectedColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '커뮤니티',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: unselectedColor,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (useRoundButton)
              Positioned(
                bottom: 0,
                child: Container(
                  width: 30,
                  height: 10,
                  decoration: BoxDecoration(
                    color: selectedDark.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityMenuBubble({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFCFB),
                Color(0xFFFFF4F1),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFFFFD7CE),
              width: 1.15,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8E7C).withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFF3EF),
                      Color(0xFFFFE5DE),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFFFD7CE),
                  ),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFFF8E7C),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3E332F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData outlinedIcon,
    required IconData filledIcon,
  }) {
    final bool isSelected = _selectedIndex == index;

    const Color selectedColor = Color(0xFFFF8E7C);
    const Color unselectedColor = Color(0xFF98A2B3);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await _onMenuSelect(index);
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 12 : 0,
              vertical: isSelected ? 8 : 0,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.92)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFFD8D2)
                    : Colors.transparent,
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: const Color(0xFFFF8E7C).withOpacity(0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? filledIcon : outlinedIcon,
                  size: 22,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? selectedColor : unselectedColor,
                    height: 1.0,
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
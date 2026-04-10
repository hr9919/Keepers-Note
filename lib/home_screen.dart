import 'dart:async';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'data/place_labels.dart';
import 'models/place_label.dart';
import 'models/resource_model.dart';
import 'models/spawn_point_model.dart';
import 'models/spawn_resource_model.dart';
import 'services/api_service.dart';
import 'setting_screen.dart';
import 'map_screen.dart';
import 'models/global_search_item.dart';
import 'services/global_search_service.dart';
import 'models/event_item.dart';
import 'dart:ui';
import 'dart:math';

String formatDdayLabel(DateTime endAt) {
  final now = DateTime.now();
  final gameNow = now.hour < 6 ? now.subtract(const Duration(days: 1)) : now;
  final endGameDate =
  endAt.hour < 6 ? endAt.subtract(const Duration(days: 1)) : endAt;

  final nowDateOnly =
  DateTime(gameNow.year, gameNow.month, gameNow.day);
  final endDateOnly =
  DateTime(endGameDate.year, endGameDate.month, endGameDate.day);

  final dday = endDateOnly.difference(nowDateOnly).inDays;

  if (dday < 0) return '종료';
  if (dday == 0) return 'D-Day';
  return 'D-$dday';
}

class HomeScreen extends StatefulWidget {
  final VoidCallback? openDrawer;
  final VoidCallback? openEndDrawer;
  final VoidCallback? openEventScreen;
  final List<Map<String, dynamic>> todoList;
  final Function(int)? onTodoToggle;
  final VoidCallback? onResetAll;
  final Future<void> Function()? onRefresh;
  final List<EventItem> eventList;
  final void Function(GlobalSearchItem item)? onSearchItemSelected;

  const HomeScreen({
    super.key,
    this.openDrawer,
    this.openEndDrawer,
    this.openEventScreen,
    this.todoList = const [],
    this.onTodoToggle,
    this.onResetAll,
    this.onRefresh,
    this.onSearchItemSelected,
    this.eventList = const [],
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  Timer? _sixAMTimer;
  Timer? _eventBannerTimer;
  Timer? _eventResumeTimer;
  bool _isUserInteracting = false;
  int _currentEventIndex = 0;

  Future<void> _handlePreviewSpawnVote(SpawnResourceModel res) async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (_voterId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 불러올 수 없습니다.')),
      );
      return;
    }

    if (res.alreadyVotedSameType) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미 ${res.koName}에 투표했어요.')),
      );
      return;
    }

    try {
      final response = await ApiService.voteResource(
        id: res.id,
        voterId: _voterId,
      );

      await _loadMapPreviewResources();

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${res.koName}에 투표했습니다!')),
        );
        return;
      }

      if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.body.isNotEmpty ? response.body : '이미 이 자원 종류에 투표했어요.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.body.isNotEmpty ? response.body : '투표 실패',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  String _normalizeSpawnPreviewFilterKey(SpawnResourceModel res) {
    return res.resourceName;
  }

  double _previewSpawnPointOpacity(SpawnPointModel point) {
    if (point.hasAnyVotedByMe) return 1.0;
    if (point.isOakVerified || point.isFluoriteVerified) return 1.0;

    final int maxVote = point.resources.isEmpty
        ? 0
        : point.resources
        .map((r) => r.voteCount)
        .reduce((a, b) => a > b ? a : b);

    switch (maxVote) {
      case 0:
        return 0.32;
      case 1:
        return 0.46;
      case 2:
        return 0.60;
      case 3:
        return 0.76;
      case 4:
        return 0.90;
      default:
        return 1.0;
    }
  }

  Widget _buildPreviewSpawnPin(SpawnPointModel point) {
    final bool isSelected = false;

    return IgnorePointer(
      child: SizedBox(
        width: 26,
        height: 34,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF8E7C),
                    width: isSelected ? 2.4 : 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  point.isOakOnly ? '🌳' : '💎',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            Positioned(
              top: 18,
              child: CustomPaint(
                size: const Size(10, 14),
                painter: _PreviewSpawnTailPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SpawnPointModel> _getVisiblePreviewSpawnPoints() {
    return _previewSpawnPoints.where((point) {
      if (point.resources.isEmpty) return false;

      return point.resources.any((res) {
        final key = _normalizeSpawnPreviewFilterKey(res);
        return _previewEnabledResources.contains(key);
      });
    }).toList();
  }

  List<SpawnPointModel> _previewSpawnPoints = [];

  final Color snackAccent = const Color(0xFFFF8E7C);

  String _currentWeather = '맑음';

  late final AnimationController _weatherController;

  final PageController _eventPageController = PageController();

  List<EventItem> get _activeEvents {
    final now = DateTime.now();

    final items = widget.eventList.where((e) {
      return e.isActive &&
          !now.isBefore(e.startAt) &&
          !now.isAfter(e.endAt);
    }).toList();

    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  List<String> _getDistinctPreviewResourceKeysByCategory(
      List<String> categories) {
    return _allPreviewCandidates
        .where((res) => categories.contains(res.category))
        .where((res) => res.category != 'npc' && res.category != 'animal')
        .map((res) => _normalizePreviewFilterKey(res))
        .toSet()
        .toList()
      ..sort((a, b) {
        final aName = _getPreviewDisplayName(a);
        final bName = _getPreviewDisplayName(b);
        return aName.compareTo(bName);
      });
  }

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<GlobalSearchItem> _allSearchItems = [];
  List<GlobalSearchItem> _searchSuggestions = [];
  bool _isSearchLoading = false;

  ResourceModel? _getPreviewRepresentativeByResourceName(String resourceName) {
    try {
      return _allPreviewCandidates.firstWhere(
            (res) => _normalizePreviewFilterKey(res) == resourceName,
      );
    } catch (_) {
      return null;
    }
  }

  void _togglePreviewResource(String resourceName) {
    setState(() {
      if (_previewEnabledResources.contains(resourceName)) {
        _previewEnabledResources.remove(resourceName);
      } else {
        _previewEnabledResources.add(resourceName);
      }
      _mapPreviewResources =
          _getFilteredPreviewResources(_allPreviewCandidates);
    });
  }

  List<ResourceModel> _allPreviewCandidates = [];
  List<ResourceModel> _mapPreviewResources = [];
  bool _isMapPreviewLoading = true;

  String _voterId = "";

  int? _pressedEventIndex;
  bool _isPreviewFilterBarPressed = false;
  bool _isTodoCardPressed = false;
  bool _isInnerTap = false;
  int? _pressedTodoIndex;

  final TransformationController _previewTransformController =
  TransformationController();

  bool _didSetPreviewInitialTransform = false;
  bool _isPointerDownOnMapPreview = false;

  bool _isProgressiveVotePin(ResourceModel res) {
    final key = _normalizePreviewFilterKey(res);
    return key == 'roaming_oak' || key == 'fluorite';
  }

  bool _isPreviewVotableResource(ResourceModel res) {
    final key = _normalizePreviewFilterKey(res);
    return key == 'roaming_oak' || key == 'fluorite';
  }

  bool _isPreviewVoteCompleted(ResourceModel res) {
    return res.voteCount >= 5 || res.isFixed || res.isVerified;
  }

  bool _shouldHideOtherSameTypePins(ResourceModel res) {
    final String key = _normalizePreviewFilterKey(res);
    final bool isVoteTarget = key == 'roaming_oak' || key == 'fluorite';

    if (!isVoteTarget) return false;

    final bool hasMyVoteInSameType = _allPreviewCandidates.any((r) {
      return _normalizePreviewFilterKey(r) == key && r.votedByMe;
    });

    if (!hasMyVoteInSameType) return false;

    // 내가 투표한 좌표만 남기고 나머지는 숨김
    return !res.votedByMe;
  }

  int _mapPreviewPointerCount = 0;

  static const double _previewMinScale = 1.0;
  static const double _previewMaxScale = 4.0;
  static const double _previewInitialScale = 1.0;
  static const double _previewPlaceRevealScale = 1.55;

  Set<String> _previewEnabledResources = {};

  bool _previewShowNpcs = false;
  bool _previewShowAnimals = false;

  static const List<BoxShadow> _kCommonShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  double _previewVotePinOpacity(ResourceModel res) {
    if (!_isPreviewVotableResource(res)) return 1.0;

    // 내가 투표해서 남아 있는 핀은 항상 완전 불투명
    if (res.votedByMe) return 1.0;

    if (_isPreviewVoteCompleted(res)) return 1.0;

    switch (res.voteCount) {
      case 0:
        return 0.28;
      case 1:
        return 0.42;
      case 2:
        return 0.58;
      case 3:
        return 0.74;
      case 4:
        return 0.88;
      default:
        return 1.0;
    }
  }

  void _startEventBannerAutoScroll({bool initialDelay = false}) {
    _eventBannerTimer?.cancel();
    final events = _activeEvents;
    if (events.length <= 1) return;

    Future.delayed(
      initialDelay ? const Duration(seconds: 3) : Duration.zero,
          () {
        if (!mounted || _isUserInteracting) return;

        _eventBannerTimer = Timer.periodic(const Duration(seconds: 7), (_) {
          if (!mounted || !_eventPageController.hasClients || _isUserInteracting) return;

          // 단순히 다음 페이지로 넘깁니다.
          // 큰 itemCount 덕분에 1번으로 되감기지 않고 다음 배너(순환된 1번)가 나옵니다.
          _eventPageController.nextPage(
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
          );
        });
      },
    );
  }

  String _resolveEventImageUrl(String raw) {
    if (raw.isEmpty) return '';

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    return 'http://161.33.30.40:8080$raw';
  }

  Future<void> _loadMapPreviewResources() async {
    try {
      final data = await ApiService.getResources(voterId: _voterId);
      if (!mounted) return;

      const defaultNames = <String>{
        'roaming_oak',
        'fluorite',
        'black_truffle',
      };

      final allFixed = data.fixedResources;
      final allSpawn = data.spawnPoints;

      setState(() {
        if (_previewEnabledResources.isEmpty) {
          _previewEnabledResources = {...defaultNames};
        } else {
          _previewEnabledResources = {
            ..._previewEnabledResources,
            ...defaultNames,
          };
        }

        _allPreviewCandidates = allFixed;
        _previewSpawnPoints = allSpawn;
        _mapPreviewResources = _getFilteredPreviewResources(allFixed);
        _isMapPreviewLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMapPreviewLoading = false;
      });
    }
  }

  Future<void> _openEventLink(String rawUrl, int eventId) async {
    final link = rawUrl.trim();

    if (link.isEmpty) {
      debugPrint('이벤트 링크가 없습니다. id=$eventId');
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null) {
      debugPrint('잘못된 이벤트 링크: $link');
      return;
    }

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok) {
      debugPrint('Could not launch $link');
    }
  }

  bool get _isPreviewAtMinScale {
    final double currentScale =
    _previewTransformController.value.getMaxScaleOnAxis();
    return currentScale <= (_previewMinScale + 0.01);
  }

  void _onPreviewTransformChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _setInitialPreviewTransform(BoxConstraints constraints) {
    if (_didSetPreviewInitialTransform) return;
    if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) return;

    final double scale = _previewInitialScale;
    final double contentWidth = constraints.maxWidth * scale;
    final double contentHeight = constraints.maxHeight * scale;

    final double tx = (constraints.maxWidth - contentWidth) / 2;
    final double ty = (constraints.maxHeight - contentHeight) / 2;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didSetPreviewInitialTransform) return;

      _previewTransformController.value = Matrix4.identity()
        ..translate(tx, ty)
        ..scale(scale);

      _didSetPreviewInitialTransform = true;
    });
  }

  @override
  void initState() {
    super.initState();

    _weatherController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )
      ..repeat();

    _previewTransformController.addListener(_onPreviewTransformChanged);
    _checkAndResetAtStart();
    _scheduleSixAMTimer();
    _initializePreview();
    _loadGlobalSearchItems();
    _searchController.addListener(_handleSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCenterPage());
  }

  // 데이터 유무를 확인하고 중앙으로 보내주는 헬퍼 함수
  void _jumpToCenterPage() {
    final events = _activeEvents;
    if (events.isNotEmpty && _eventPageController.hasClients) {
      // 10000개 중 딱 중간이면서 0번 인덱스인 곳 계산
      int centerPage = (10000 ~/ 2) - ((10000 ~/ 2) % events.length);
      _eventPageController.jumpToPage(centerPage);
      setState(() {
        _currentEventIndex = centerPage % events.length;
      });
      _startEventBannerAutoScroll(initialDelay: true);
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 이벤트 리스트가 변경되었을 때만 실행
    if (oldWidget.eventList != widget.eventList) {
      _eventResumeTimer?.cancel();
      _eventBannerTimer?.cancel();

      // 1. 새로운 리스트 기준으로 다시 중앙 위치(양방향 무한 스크롤 가능 지점) 계산 후 점프
      if (widget.eventList.isNotEmpty && _eventPageController.hasClients) {
        final events = _activeEvents;
        if (events.isNotEmpty) {
          int centerPage = (10000 ~/ 2) - ((10000 ~/ 2) % events.length);

          // 애니메이션 없이 즉시 새로운 중앙점으로 이동
          _eventPageController.jumpToPage(centerPage);

          setState(() {
            _currentEventIndex = centerPage % events.length;
          });
        }
      }

      // 2. 자동 스크롤 재시작
      _startEventBannerAutoScroll(initialDelay: true);
    }
  }

  Future<void> _handlePreviewVote(ResourceModel res) async {
    // 팝업 먼저 닫기
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (_voterId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 불러올 수 없습니다.')),
      );
      return;
    }

    if (res.alreadyVotedSameType) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 이 자원 종류에 투표했어요.')),
      );
      return;
    }

    try {
      final response = await ApiService.voteResource(
        id: res.id,
        voterId: _voterId,
      );

      await _loadMapPreviewResources();

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${res.koName}에 투표했습니다!')),
        );
        return;
      }

      if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.body.isNotEmpty
                ? response.body
                : '이미 투표했어요'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('투표 실패')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  Future<void> _handleTodoCardTap() async {
    if (_isInnerTap) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isTodoCardPressed = true;
    });

    await Future.delayed(const Duration(milliseconds: 85));

    if (!mounted) return;

    setState(() {
      _isTodoCardPressed = false;
    });

    widget.openEndDrawer?.call();
  }

  Future<void> _loadGlobalSearchItems() async {
    setState(() => _isSearchLoading = true);
    _allSearchItems = await GlobalSearchService.loadAllItems();
    if (mounted) {
      setState(() => _isSearchLoading = false);
    }
  }

  void _handleSearchChanged() {
    final results = GlobalSearchService.filter(
      _allSearchItems,
      _searchController.text,
    );
    setState(() {
      _searchSuggestions = results;
    });
  }


  Color _getWeatherTextColor(String weather) {
    switch (weather) {
      case '맑음':
      case '눈':
      case '무지개':
      // 생검정 대신 배경색과 조화로운 짙은 블루-그레이 사용
        return const Color(0xFF334155).withOpacity(0.9);
      default:
        return Colors.white;
    }
  }

  Color _getWeatherSubTextColor(String weather) {
    switch (weather) {
      case '맑음':
      case '눈':
      case '무지개':
      // 메인 글자보다 약간 연한 톤
        return const Color(0xFF475569).withOpacity(0.8);
      default:
        return Colors.white.withOpacity(0.9);
    }
  }

  BoxDecoration _buildWeatherBackground(String weather) {
    switch (weather) {
      case '맑음':
        return BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8ED8FF),
              Color(0xFFBEE9FF),
              Color(0xFFEAF8FF),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: _kCommonShadow,
        );
      case '흐림':
        return BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF93A4B8),
              Color(0xFF6E7F94),
              Color(0xFF536273),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: _kCommonShadow,
        );
      case '비':
        return BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3D5A80),
              Color(0xFF2B4162),
              Color(0xFF1B2840),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: _kCommonShadow,
        );
      case '무지개':
        return BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFC6DA),
              Color(0xFFFFE29A),
              Color(0xFFCDB4FF),
              Color(0xFFB8F2E6),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: _kCommonShadow,
        );
      case '눈':
        return BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFA9D0E7), // 개선된 깊은 서리색
              Color(0xFF8BB7D9),
              Color(0xFF6A9CC9),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: _kCommonShadow,
        );
    // 🔥 에러 해결 핵심: 어떤 조건에도 맞지 않을 때 반환할 기본값을 설정합니다.
      default:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: _kCommonShadow,
        );
    }
  }

  Widget _buildWeatherIcon(String weather, {double size = 24}) {
    switch (weather) {
      case '맑음':
        return Text('☀️', style: TextStyle(fontSize: size));

      case '흐림':
        return Text('☁️', style: TextStyle(fontSize: size));

      case '비':
        return Text('🌧️', style: TextStyle(fontSize: size));

      case '무지개':
        return Text('🌈', style: TextStyle(fontSize: size));

      case '눈':
        return Text('❄️', style: TextStyle(fontSize: size));

      default:
        return Text('🌤️', style: TextStyle(fontSize: size));
    }
  }

  Future<void> _initializePreview() async {
    await _loadVoterId();
    await _loadMapPreviewResources();
  }

  @override
  void dispose() {
    _sixAMTimer?.cancel();
    _eventBannerTimer?.cancel();
    _eventPageController.dispose();
    _previewTransformController.removeListener(_onPreviewTransformChanged);
    _previewTransformController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _eventResumeTimer?.cancel();
    _weatherController.dispose();
    super.dispose();
  }

  String _normalizePreviewFilterKey(ResourceModel res) {
    if (res.resourceName == 'fluorite' ||
        res.resourceName == 'flawless_fluorite' ||
        res.koName.contains('형광석')) {
      return 'fluorite';
    }

    if (res.resourceName == 'roaming_oak' ||
        res.koName.contains('참나무')) {
      return 'roaming_oak';
    }

    if (res.resourceName == 'black_truffle' ||
        res.resourceName == 'black-truffle' ||
        res.koName.contains('트러플')) {
      return 'black_truffle';
    }

    return res.resourceName;
  }

  Future<void> _loadVoterId() async {
    try {
      final user = await UserApi.instance.me();
      final voterId = user.id?.toString() ?? "";

      if (!mounted) return;
      setState(() {
        _voterId = voterId;
      });
    } catch (_) {}
  }

  Future<void> _checkAndResetAtStart() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final String? lastResetDate = prefs.getString('last_six_am_reset');

    final resetThreshold = DateTime(now.year, now.month, now.day, 6);
    final currentResetDate = now.isBefore(resetThreshold)
        ? resetThreshold.subtract(const Duration(days: 1))
        : resetThreshold;

    final currentResetStr =
        "${currentResetDate.year}-${currentResetDate.month}-${currentResetDate
        .day}";

    if (lastResetDate != currentResetStr) {
      _executeReset(currentResetStr);
    }
  }

  void _scheduleSixAMTimer() {
    _sixAMTimer?.cancel();

    final now = DateTime.now();
    var nextSixAM = DateTime(now.year, now.month, now.day, 6);

    if (now.isAfter(nextSixAM)) {
      nextSixAM = nextSixAM.add(const Duration(days: 1));
    }

    final durationUntilSix = nextSixAM.difference(now);

    _sixAMTimer = Timer(durationUntilSix, () {
      _executeReset("${nextSixAM.year}-${nextSixAM.month}-${nextSixAM.day}");
      _scheduleSixAMTimer();
    });
  }

  Future<void> _executeReset(String dateStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_six_am_reset', dateStr);

    debugPrint("오전 6시 리셋 실행: $dateStr");

    if (widget.onResetAll != null) {
      widget.onResetAll!();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Set<String> _getPreviewFilterKeys() {
    final fixedKeys = _allPreviewCandidates
        .map((res) => _normalizePreviewFilterKey(res))
        .toSet();

    final spawnKeys = _previewSpawnPoints
        .expand((point) => point.resources)
        .map((res) => _normalizeSpawnPreviewFilterKey(res))
        .toSet();

    return {
      ...fixedKeys,
      ...spawnKeys,
      'roaming_oak',
      'fluorite',
    };
  }

  List<ResourceModel> _getFilteredPreviewResources(List<ResourceModel> source) {
    return source.where((res) {
      if (_shouldHideOtherSameTypePins(res)) {
        return false;
      }

      final String key = _normalizePreviewFilterKey(res);
      final bool isMatched = _previewEnabledResources.contains(key);
      final bool isNpc = res.category == 'npc';
      final bool isAnimal = res.category == 'animal';

      return isMatched ||
          (_previewShowNpcs && isNpc) ||
          (_previewShowAnimals && isAnimal);
    }).toList();
  }

  void _applyPreviewFilter({
    required Set<String> resources,
    required bool showNpcs,
    required bool showAnimals,
  }) {
    setState(() {
      _previewEnabledResources = resources;
      _previewShowNpcs = showNpcs;
      _previewShowAnimals = showAnimals;
      _mapPreviewResources =
          _getFilteredPreviewResources(_allPreviewCandidates);
    });
  }

  void _showPreviewFilterPopup() {
    final Set<String> tempResources = {..._previewEnabledResources};
    bool tempShowNpcs = _previewShowNpcs;
    bool tempShowAnimals = _previewShowAnimals;

    final gatherItems = _getDistinctPreviewResourceKeysByCategory([
      'fruit',
      'bubble',
      'tree',
      'material',
      'mineral',
    ]);
    final mushroomItems =
    _getDistinctPreviewResourceKeysByCategory(['mushroom']);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildChip(String resourceName) {
              final bool selected = tempResources.contains(resourceName);
              final ResourceModel? sample =
              _getPreviewRepresentativeByResourceName(resourceName);

              return GestureDetector(
                onTap: () {
                  setModalState(() {
                    if (selected) {
                      tempResources.remove(resourceName);
                    } else {
                      tempResources.add(resourceName);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFFF4F1)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFF8E7C)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFFFD4CC)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: sample == null
                            ? const Icon(
                          Icons.inventory_2_outlined,
                          size: 12,
                          color: Colors.grey,
                        )
                            : Image.asset(
                          sample.iconPath,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) =>
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        sample?.koName ?? resourceName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? const Color(0xFF111827)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget buildSection(String title, List<String> items) {
              if (items.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items.map(buildChip).toList(),
                  ),
                ],
              );
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const Text(
                        '프리뷰 핀 선택',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '홈 프리뷰 지도에 보일 핀을 골라보세요.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _buildPreviewTopToggle(
                            title: 'NPC',
                            value: tempShowNpcs,
                            icon: Icons.people_alt_outlined,
                            onTap: () {
                              setModalState(() {
                                tempShowNpcs = !tempShowNpcs;
                              });
                            },
                          ),
                          const SizedBox(width: 10),
                          _buildPreviewTopToggle(
                            title: '동물',
                            value: tempShowAnimals,
                            icon: Icons.pets_outlined,
                            onTap: () {
                              setModalState(() {
                                tempShowAnimals = !tempShowAnimals;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      buildSection('채집 자원', gatherItems),
                      const SizedBox(height: 16),
                      buildSection('버섯 종류', mushroomItems),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // 1. setModalState를 사용하여 바텀시트 내부 UI를 즉시 갱신합니다.
                                setModalState(() {
                                  // 2. 임시 저장 변수(tempResources 등)를 기본값으로 초기화합니다.
                                  tempResources.clear();
                                  for (final res in _allPreviewCandidates) {
                                    final key = _normalizePreviewFilterKey(res);
                                    if (key == 'roaming_oak' ||
                                        key == 'fluorite' ||
                                        key == 'black-truffle') {
                                      tempResources.add(key);
                                    }
                                  }
                                  tempShowNpcs = false;
                                  tempShowAnimals = false;
                                });
                                // 3. Navigator.pop(context)를 호출하지 않으므로 창이 닫히지 않습니다.
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(
                                  color: Color(0xFFD7DEE7),
                                ),
                                minimumSize: const Size(double.infinity, 48),
                              ),
                              child: const Text('기본값'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                _applyPreviewFilter(
                                  resources: tempResources,
                                  showNpcs: tempShowNpcs,
                                  showAnimals: tempShowAnimals,
                                );
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8E7C),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                elevation: 0,
                              ),
                              child: const Text('적용'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _openMap(openFilter: true);
                          },
                          child: const Text(
                            '지도에서 자세히 보기',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPreviewResourceDetail(ResourceModel res) {
    final bool isActuallyVerified = _isPreviewVoteCompleted(res);
    final bool isVoteTarget = _isPreviewVotableResource(res);
    final bool isAlreadyVoted = res.alreadyVotedSameType;

    final bool showVoteButton = isVoteTarget && !isActuallyVerified;
    final bool canVote = showVoteButton && !isAlreadyVoted;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.asset(
                        res.iconPath,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) =>
                        const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        res.koName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    (res.description != null &&
                        res.description!.trim().isNotEmpty)
                        ? res.description!
                        : '설명 정보가 없습니다.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (showVoteButton) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handlePreviewVote(res),
                          icon: const Icon(Icons.thumb_up_outlined),
                          label: Text(
                            canVote
                                ? "여기 있어요! (${res.voteCount})"
                                : "이미 투표했어요",
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                            canVote ? const Color(0xFFFF8E7C) : Colors.grey,
                            side: BorderSide(
                              color: canVote
                                  ? const Color(0xFFFF8E7C)
                                  : Colors.grey.shade400,
                            ),
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8E7C),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          elevation: 0,
                        ),
                        child: const Text('확인'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  void _openMap({bool openFilter = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(openFilterOnStart: openFilter),
      ),
    );
  }

  void _setMapPreviewPointerDown(bool value) {
    if (_isPointerDownOnMapPreview == value) return;
    setState(() {
      _isPointerDownOnMapPreview = value;
    });
  }

  bool get _shouldLockHomeScroll {
    return (_mapPreviewPointerCount >= 2) ||
        (_isPointerDownOnMapPreview && !_isPreviewAtMinScale);
  }

  bool _shouldShowPreviewPlaceLabel(PlaceLabel place) {
    if (place.showFromBaseZoom) return true;

    final double currentScale =
    _previewTransformController.value.getMaxScaleOnAxis();

    return currentScale >= _previewPlaceRevealScale;
  }

  String _getPreviewDisplayName(String filterKey) {
    switch (filterKey) {
      case 'roaming_oak':
        return '그 자리 참나무';
      case 'fluorite':
        return '완벽한 형광석';
      case 'black_truffle':
        return '검은 트러플';
      default:
        final sample = _getPreviewRepresentativeByResourceName(filterKey);
        return sample?.koName ?? filterKey;
    }
  }

  Widget _buildPreviewResourceChip(String resourceName) {
    final bool selected = _previewEnabledResources.contains(resourceName);
    final ResourceModel? sample =
    _getPreviewRepresentativeByResourceName(resourceName);

    return GestureDetector(
      onTap: () => _togglePreviewResource(resourceName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFF4F1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF8E7C)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFFFFD4CC)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: sample == null
                  ? const Icon(
                Icons.inventory_2_outlined,
                size: 12,
                color: Colors.grey,
              )
                  : Image.asset(
                sample.iconPath,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) =>
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 12,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              _getPreviewDisplayName(resourceName),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF111827)
                    : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPlaceLabels(double mapSize) {
    final double currentScale =
    _previewTransformController.value.getMaxScaleOnAxis();

    final double textScale = (1 / (currentScale * 1.18)).clamp(0.42, 0.82);

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final place in placeLabels)
            if (_shouldShowPreviewPlaceLabel(place))
              for (final pos in place.positions)
                Positioned(
                  left: pos.dx * mapSize,
                  top: pos.dy * mapSize,
                  child: Transform.translate(
                    offset: const Offset(-20, -6),
                    child: Transform.scale(
                      scale: textScale,
                      alignment: Alignment.centerLeft,
                      child: Opacity(
                        opacity: 0.74,
                        child: Text(
                          place.nameKo,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: Color(0xBB000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                              Shadow(
                                color: Color(0x55000000),
                                blurRadius: 8,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPreviewTopToggle({
    required String title,
    required bool value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: value
                ? const Color(0xFFFFF4F1)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: value
                  ? const Color(0xFFFF8E7C)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: value
                    ? const Color(0xFFFF8E7C)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    // 커스텀 앱바가 실제로 차지하는 높이
    const double appBarBodyHeight = 108;
    final double refreshTop = topPadding + appBarBodyHeight;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F6),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // [Layer 1] 배경
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFF6F3),
                      Color(0xFFFFFBFA),
                    ],
                  ),
                ),
              ),
            ),

            // [Layer 2] 본문 - 앱바 아래에서부터 새로고침/스크롤 시작
            Positioned.fill(
              top: refreshTop,
              child: RefreshIndicator(
                color: const Color(0xFFFF8E7C),
                backgroundColor: Colors.white,
                edgeOffset: 8,
                displacement: 26,
                onRefresh: () async {
                  await widget.onRefresh?.call();
                  await _loadMapPreviewResources();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(top: 26, bottom: 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSectionTitle('진행중 이벤트'),
                      ),
                      _buildEventSection(context),
                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('오늘의 할 일'),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 246,
                                    child: _buildTodoSummaryCard(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('날씨'),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 246,
                                    child: _buildWeatherCard(_currentWeather),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSectionTitle('지도'),
                      ),
                      _buildMapSection(context),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // [Layer 3] 앱바
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildCustomAppBar(context, topPadding),
            ),

            // [Layer 4] 검색 팝업 바깥 영역 터치 시 닫기
            if (_searchSuggestions.isNotEmpty)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    _searchFocusNode.unfocus();
                    setState(() {
                      _searchSuggestions = [];
                    });
                  },
                  child: const SizedBox.expand(),
                ),
              ),

            // [Layer 5] 검색 제안 팝업
            if (_searchSuggestions.isNotEmpty)
              Positioned(
                top: topPadding + 140,
                left: 0,
                right: 0,
                child: _buildSearchSuggestionsOverlay(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSuggestionsOverlay() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _searchSuggestions.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final item = _searchSuggestions[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    _searchFocusNode.unfocus();
                    _searchController.clear();

                    setState(() {
                      _searchSuggestions = [];
                    });

                    widget.onSearchItemSelected?.call(item);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7F4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildSuggestionLeading(item),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if ((item.subtitle ?? '').isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  item.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.north_west_rounded,
                          size: 18,
                          color: Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionLeading(GlobalSearchItem item) {
    final iconPath = item.iconPath.trim();

    if (iconPath.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(5),
        child: Image.asset(
          iconPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.search_rounded,
              size: 18,
              color: Color(0xFFFF8E7C),
            );
          },
        ),
      );
    }

    return const Icon(
      Icons.search_rounded,
      size: 18,
      color: Color(0xFFFF8E7C),
    );
  }

  String _getWeatherDescription(String weather) {
    switch (weather) {
      case '맑음':
        return '햇살이 반짝이는 날이에요';
      case '흐림':
        return '구름이 천천히 지나가고 있어요';
      case '비':
        return '촉촉하게 비가 내리고 있어요';
      case '무지개':
        return '무지개 빛이 반짝이고 있어요';
      case '눈':
        return '포근하게 눈이 내리고 있어요';
      default:
        return '';
    }
  }

  Widget _buildAnimatedWeatherBackground(String weather) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AnimatedBuilder(
        animation: _weatherController,
        builder: (context, child) {
          final t = _weatherController.value;

          switch (weather) {
            case '맑음':
              final skyOffset = lerpDouble(-30, 30, t)!;
              final cloudOffset = lerpDouble(24, -24, t)!;
              return Stack(
                children: [
                  Transform.translate(
                    offset: Offset(skyOffset, 0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x6698E2FF),
                            Color(0x3398E2FF),
                            Color(0x0098E2FF),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    left: cloudOffset,
                    child: _weatherBlob(
                      width: 68,
                      height: 24,
                      color: Colors.white.withOpacity(0.28),
                    ),
                  ),
                  Positioned(
                    bottom: 26,
                    right: 24 - cloudOffset * 0.25,
                    child: _weatherBlob(
                      width: 58,
                      height: 20,
                      color: Colors.white.withOpacity(0.16),
                    ),
                  ),
                ],
              );

            case '흐림':
              final dx1 = lerpDouble(-40, 20, t)!;
              final dx2 = lerpDouble(30, -20, t)!;
              return Stack(
                children: [
                  Positioned(
                    top: 22,
                    left: dx1,
                    child: _weatherBlob(
                      width: 96,
                      height: 34,
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                  Positioned(
                    top: 54,
                    right: dx2,
                    child: _weatherBlob(
                      width: 74,
                      height: 28,
                      color: Colors.white.withOpacity(0.14),
                    ),
                  ),
                  Positioned(
                    bottom: 18,
                    left: 18 + dx2 * 0.2,
                    child: _weatherBlob(
                      width: 82,
                      height: 26,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ],
              );

            case '비':
              return CustomPaint(
                painter: _RainPainter(progress: t),
                child: const SizedBox.expand(),
              );

            case '눈':
              return CustomPaint(
                painter: _SnowPainter(progress: t),
                child: const SizedBox.expand(),
              );

            case '무지개':
              final glow = 0.65 + (0.35 * (0.5 - (t - 0.5).abs()) * 2);
              return Stack(
                children: [
                  Positioned(
                    left: -12,
                    right: -12,
                    bottom: -22,
                    child: Opacity(
                      opacity: glow,
                      child: CustomPaint(
                        size: const Size(double.infinity, 120),
                        painter: _RainbowPainter(),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    right: 24,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.28 * glow),
                            blurRadius: 22,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );

            default:
              return const SizedBox.expand();
          }
        },
      ),
    );
  }

  Widget _weatherBlob({
    required double width,
    required double height,
    required Color color,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height),
      ),
    );
  }

  Widget _buildWeatherAnimatedIcon(String weather) {
    return AnimatedBuilder(
      animation: _weatherController,
      builder: (context, child) {
        final t = _weatherController.value;
        double dy = 0;
        double scale = 1.0;

        switch (weather) {
          case '맑음':
            dy = lerpDouble(-2, 2, (t <= 0.5 ? t * 2 : (1 - t) * 2))!;
            scale = 1.0 + 0.03 * (0.5 - (t - 0.5).abs()) * 2;
            break;
          case '흐림':
            dy = lerpDouble(-1, 1, (t <= 0.5 ? t * 2 : (1 - t) * 2))!;
            break;
          case '비':
            dy = lerpDouble(0, 3, (t <= 0.5 ? t * 2 : (1 - t) * 2))!;
            break;
          case '무지개':
            scale = 1.0 + 0.06 * (0.5 - (t - 0.5).abs()) * 2;
            break;
          case '눈':
            dy = lerpDouble(-2, 2, (t <= 0.5 ? t * 2 : (1 - t) * 2))!;
            break;
        }

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: _buildWeatherIcon(weather, size: 52),
          ),
        );
      },
    );
  }

  Widget _buildWeatherCard(String weather) {
    final bool isLightBg = ['맑음', '눈', '무지개'].contains(weather);

    return SizedBox.expand(
      child: Container(
        decoration: _buildWeatherBackground(weather),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildAnimatedWeatherBackground(weather),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '현재 날씨',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _getWeatherSubTextColor(weather),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _showWeeklyWeatherPopup,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(13, 5, 9, 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                isLightBg ? 0.22 : 0.14,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withOpacity(
                                  isLightBg ? 0.28 : 0.18,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '주간',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getWeatherSubTextColor(weather),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 15,
                                  color: _getWeatherSubTextColor(weather),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 6), // ⭐ 여기 숫자 조절
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: Center(
                              child: _buildWeatherAnimatedIcon(weather),
                            ),
                          ),
                        ),
                        const SizedBox(width: 25),
                        Expanded(
                          child: Text(
                            weather,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                              color: _getWeatherTextColor(weather),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Text(
                      _getWeatherDescription(weather),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: _getWeatherSubTextColor(weather),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _buildHourlyWeatherStrip(weather),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyWeatherStrip(String currentWeather) {
    final bool isLightBg = ['맑음', '눈', '무지개'].contains(currentWeather);

    final hourly = [
      {'time': '09시', 'weather': '맑음'},
      {'time': '12시', 'weather': '맑음'},
      {'time': '15시', 'weather': '흐림'},
      {'time': '18시', 'weather': '비'},
      {'time': '21시', 'weather': '맑음'},
      {'time': '00시', 'weather': '눈'},
    ];

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: hourly.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = hourly[index];
          final weather = item['weather']!;

          return Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isLightBg
                  ? Colors.white.withOpacity(0.42)
                  : Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.20),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['time']!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _getWeatherTextColor(currentWeather),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Center(
                    child: _buildWeatherIcon(weather, size: 16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showWeeklyWeatherPopup() {
    final weekly = [
      {'day': '오늘', 'weather': '맑음'},
      {'day': '내일', 'weather': '흐림'},
      {'day': '금요일', 'weather': '비'},
      {'day': '토요일', 'weather': '무지개'},
      {'day': '일요일', 'weather': '눈'},
    ];

    final bool isLightBg = ['맑음', '눈', '무지개'].contains(_currentWeather);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const Text(
                    '주간 날씨 예보',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '날씨를 탭하면 홈 날씨 카드에 바로 반영돼요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Column(
                    children: weekly.map((item) {
                      final weather = item['weather']!;
                      final day = item['day']!;
                      final isSelected = _currentWeather == weather;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _currentWeather = weather;
                              });
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFF4F1)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFFD4CC)
                                      : const Color(0xFFEAEFF5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isLightBg
                                          ? Colors.white.withOpacity(0.32)
                                          : Colors.white.withOpacity(0.10),
                                      shape: BoxShape.circle,
                                    ),
                                    child: _buildWeatherIcon(weather, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          day,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          weather,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFFF8E7C)
                                          : const Color(0xFFEFF3F8),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      isSelected ? '현재 적용됨' : '선택',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTodoSummaryCard() {
    const int displayLimit = 4;

    final items = widget.todoList;
    final visibleItems = items.take(displayLimit).toList();
    final int extraCount =
    items.length > displayLimit ? items.length - displayLimit : 0;

    return GestureDetector(
      onTapDown: (_) {
        if (_isInnerTap) return;
        setState(() => _isTodoCardPressed = true);
      },
      onTapCancel: () {
        if (_isInnerTap) return;
        setState(() => _isTodoCardPressed = false);
      },
      onTapUp: (_) async {
        if (_isInnerTap) return;

        await Future.delayed(const Duration(milliseconds: 70));
        if (!mounted) return;

        setState(() => _isTodoCardPressed = false);
        await _handleTodoCardTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _isTodoCardPressed ? 0.985 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: _kCommonShadow,
          ),
          child: items.isEmpty
              ? const Align(
            alignment: Alignment.topLeft,
            child: Text(
              '오늘의 할 일을 등록해보세요! 🌿',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(visibleItems.length, (index) {
                final todo = visibleItems[index];
                final String text = (todo['taskName'] ?? '')
                    .toString()
                    .replaceAll('\n', ' ')
                    .replaceAll('\r', ' ')
                    .trim();
                final bool isDone = todo['completed'] == true;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == visibleItems.length - 1 ? 0 : 10,
                  ),
                  child: _buildTodoSummaryRow(
                    index: index,
                    text: text,
                    isDone: isDone,
                  ),
                );
              }),
              const Spacer(),
              Row(
                children: [
                  if (extraCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4F1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+$extraCount개 더 있어요',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF8E7C),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF1F5F9),
                      ),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFFCBD5E1),
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

  Widget _buildTodoSummaryRow({
    required int index,
    required String text,
    required bool isDone,
  }) {
    const TextStyle todoTextStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.25,
      color: Color(0xFF1E293B),
    );

    final Color splashColor = Colors.grey.withOpacity(0.08);
    final Color highlightColor = Colors.grey.withOpacity(0.05);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: splashColor,
        highlightColor: highlightColor,
        onTap: () {
          _isInnerTap = true;
          widget.onTodoToggle?.call(index);

          Future.delayed(const Duration(milliseconds: 120), () {
            _isInnerTap = false;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
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
                    width: 1.3,
                  ),
                ),
                child: isDone
                    ? const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: Colors.white,
                )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double textWidth = _measureTodoTextWidth(
                      text: text,
                      style: todoTextStyle,
                      maxWidth: constraints.maxWidth,
                    );

                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          strutStyle: const StrutStyle(
                            forceStrutHeight: true,
                            fontSize: 14,
                            height: 1.25,
                          ),
                          style: todoTextStyle.copyWith(
                            color: isDone
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        if (isDone)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Transform.translate(
                                  offset: const Offset(0, 0.5),
                                  child: Container(
                                    width: textWidth.clamp(0, constraints.maxWidth),
                                    height: 0.9,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF94A3B8)
                                          .withOpacity(0.72),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherTimeline() {
    final items = [
      {'label': '아침', 'current': true},
      {'label': '낮', 'current': false},
      {'label': '밤', 'current': false},
      {'label': '새벽', 'current': false},
      {'label': '내일', 'current': false},
    ];

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: 56,
            child: _buildTimeItem(
              item['label'] as String,
              item['current'] as bool,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeItem(String label, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFFFFF4F1)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFFFFD4CC)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wb_sunny_rounded,
            size: 16,
            color: isCurrent
                ? const Color(0xFFFF8E7C)
                : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
              color: isCurrent
                  ? const Color(0xFF111827)
                  : const Color(0xFF64748B),
              fontFamily: 'SF Pro',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyWeather(List<Map<String, String>> weekly) {
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: weekly.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = weekly[index];
          final weather = item['weather']!;

          return Container(
            width: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['day']!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: weather == '눈'
                        ? const Color(0xFF334155)
                        : Colors.white,
                    fontFamily: 'SF Pro',
                  ),
                ),
                const SizedBox(height: 6),
                _buildWeatherIcon(weather, size: 24),
                const SizedBox(height: 6),
                Text(
                  weather,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: weather == '눈'
                        ? const Color(0xFF475569)
                        : Colors.white.withOpacity(0.92),
                    fontFamily: 'SF Pro',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodoSection() {
    const int displayLimit = 6;
    final int displayCount =
    widget.todoList.length > displayLimit ? displayLimit : widget.todoList
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('오늘의 할 일'),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTapDown: (_) {
              if (_isInnerTap) return;
              setState(() {
                _isTodoCardPressed = true;
              });
            },
            onTapCancel: () {
              if (!mounted) return;
              setState(() {
                _isTodoCardPressed = false;
              });
            },
            onTapUp: (_) async {
              if (_isInnerTap) return;

              // 손을 뗀 뒤에도 잠깐 눌림 유지
              await Future.delayed(const Duration(milliseconds: 95));
              if (!mounted) return;

              setState(() {
                _isTodoCardPressed = false;
              });

              // 끊기지 않게 아주 조금 더 텀
              await Future.delayed(const Duration(milliseconds: 35));
              if (!mounted) return;

              widget.openEndDrawer?.call();
            },
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 70),
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    shadows: _kCommonShadow,
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 28),
                        child: widget.todoList.isEmpty
                            ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            "오늘의 할 일을 등록해보세요! 🌿",
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                            : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...List.generate(displayCount, (index) {
                              final todo = widget.todoList[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == displayCount - 1 ? 0 : 10,
                                ),
                                child: _buildTodoRow(
                                  index: index,
                                  text: todo['taskName'] ?? "",
                                  isDone: todo['completed'] ?? false,
                                  onCheckTap: () =>
                                      widget.onTodoToggle?.call(index),
                                ),
                              );
                            }),
                            if (widget.todoList.length > displayLimit)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 4, bottom: 2),
                                child: Text(
                                  "+ ${widget.todoList.length -
                                      displayLimit}개 더보기",
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFFF8E7C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Positioned(
                        top: 0,
                        right: 0,
                        child: Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 90),
                      opacity: _isTodoCardPressed ? 1.0 : 0.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(18),
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
    );
  }

  Widget _buildTodoRow({
    required int index,
    required String text,
    required bool isDone,
    required VoidCallback onCheckTap,
  }) {
    final bool isPressed = _pressedTodoIndex == index;

    const TextStyle todoTextStyle = TextStyle(
      fontSize: 12.5,
      height: 1.15,
      fontWeight: FontWeight.w600,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _isInnerTap = true;
        setState(() {
          _pressedTodoIndex = index;
          _isTodoCardPressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          if (_pressedTodoIndex == index) {
            _pressedTodoIndex = null;
          }
        });
        Future.microtask(() {
          _isInnerTap = false;
        });
      },
      onTapUp: (_) async {
        await Future.delayed(const Duration(milliseconds: 45));

        if (!mounted) return;

        setState(() {
          if (_pressedTodoIndex == index) {
            _pressedTodoIndex = null;
          }
        });

        onCheckTap();

        Future.microtask(() {
          _isInnerTap = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFFF8FAFC) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFFFF8E7C)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDone
                      ? const Color(0xFFFF8E7C)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: isDone
                  ? const Icon(
                Icons.check,
                size: 12,
                color: Colors.white,
              )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final visibleWidth = _measureTodoTextWidth(
                    text: text,
                    style: todoTextStyle,
                    maxWidth: constraints.maxWidth,
                  );

                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        strutStyle: const StrutStyle(
                          forceStrutHeight: true,
                          height: 1.15,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        style: todoTextStyle.copyWith(
                          color: isDone
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF111827),
                        ),
                      ),

                      if (isDone)
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Transform.translate(
                              offset: const Offset(0, 0.5),
                              child: Container(
                                width: visibleWidth,
                                height: 0.8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF94A3B8).withOpacity(0.9),
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
          ],
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
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    return textPainter.size.width;
  }

  Widget _buildMapSection(BuildContext context) {
    final double previewWidth = MediaQuery.of(context).size.width - 32;

    // Column과 내부 제목을 지우고 바로 패딩 컨테이너만 반환
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        height: previewWidth,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          shadows: _kCommonShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _setInitialPreviewTransform(constraints);
              return Stack(
                children: [
                  // ... (기존 InteractiveViewer 및 버튼 코드는 동일) ...
                  Positioned.fill(
                    child: Listener(
                      onPointerDown: (_) { _mapPreviewPointerCount++; if (!_isPointerDownOnMapPreview) _setMapPreviewPointerDown(true); },
                      onPointerUp: (_) { _mapPreviewPointerCount = (_mapPreviewPointerCount - 1).clamp(0, 999); if (_mapPreviewPointerCount == 0) _setMapPreviewPointerDown(false); },
                      child: InteractiveViewer(
                        transformationController: _previewTransformController,
                        minScale: _previewMinScale, maxScale: _previewMaxScale,
                        constrained: false, panEnabled: true, scaleEnabled: true,
                        child: SizedBox(
                          width: constraints.maxWidth, height: constraints.maxHeight,
                          child: Stack(
                            children: [
                              Positioned.fill(child: Image.asset('assets/images/map_background.png', fit: BoxFit.cover)),
                              _buildPreviewPlaceLabels(constraints.maxWidth),
                              if (_isMapPreviewLoading) const Center(child: CircularProgressIndicator(color: Color(0xFFFF8E7C)))
                              else ...[
                                ..._mapPreviewResources.map(
                                      (res) => _buildHomeMapPreviewMarker(
                                    res,
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ),
                                ),
                                ..._getVisiblePreviewSpawnPoints().map(
                                      (point) => _buildHomeSpawnPreviewMarker(
                                    point,
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12, top: 12,
                    child: GestureDetector(
                      onTap: () => _openMap(),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)]),
                        child: const Icon(Icons.open_in_full_rounded, color: Color(0xFF475569), size: 18),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12, right: 12, bottom: 12,
                    child: GestureDetector(
                      onTap: _showPreviewFilterPopup,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15)]),
                        child: Row(
                          children: [
                            Expanded(child: Text(_buildPreviewCaption(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))),
                            const Icon(Icons.tune_rounded, size: 18, color: Color(0xFFFF8E7C)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHomeSpawnPreviewMarker(
      SpawnPointModel point,
      double width,
      double height,
      ) {
    final double currentScale =
    _previewTransformController.value.getMaxScaleOnAxis();

    const double pinWidth = 24;
    const double pinHeight = 32;
    final double visualScale = (1 / currentScale).clamp(0.5, 1.0);

    return Positioned(
      left: (point.x * width) - (pinWidth / 2),
      top: (point.y * height) - pinHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showPreviewSpawnPointDetail(point),
        child: Transform.scale(
          scale: visualScale,
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: _previewSpawnPointOpacity(point),
            child: _buildPreviewSpawnPin(point),
          ),
        ),
      ),
    );
  }

  void _showPreviewSpawnPointDetail(SpawnPointModel point) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final oak = point.oak;
    final fluorite = point.fluorite;

    Widget buildVoteButton(SpawnResourceModel res) {
      final bool canVote = !res.isVerified && !res.alreadyVotedSameType;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton.icon(
          onPressed: canVote ? () => _handlePreviewSpawnVote(res) : null,
          icon: Image.asset(
            res.iconPath,
            width: 22,
            height: 22,
            errorBuilder: (c, e, s) =>
            const Icon(Icons.help_outline, size: 18),
          ),
          label: Text(
            res.isVerified
                ? '${res.koName} 확정됨'
                : canVote
                ? '${res.koName} 여기 있어요! (${res.voteCount})'
                : '${res.koName} 이미 투표했어요',
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (oak != null) buildVoteButton(oak),
            if (fluorite != null) buildVoteButton(fluorite),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeMapPreviewMarker(ResourceModel res,
      double width,
      double height,) {
    final double currentScale =
    _previewTransformController.value.getMaxScaleOnAxis();

    const double markerSize = 24;
    final double visualScale = (1 / currentScale).clamp(0.5, 1.0);

    return Positioned(
      left: (res.x * width) - (markerSize / 2),
      top: (res.y * height) - (markerSize / 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showPreviewResourceDetail(res),
        child: Transform.scale(
          scale: visualScale,
          alignment: Alignment.center,
          child: Opacity(
            opacity: _previewVotePinOpacity(res),
            child: _buildPreviewPin(res),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewPin(ResourceModel res) {
    return Container(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFF8E7C),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Image.asset(
        res.iconPath,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) =>
        const Icon(
          Icons.circle,
          size: 10,
          color: Colors.grey,
        ),
      ),
    );
  }

  String _buildPreviewCaption() {
    if (_previewEnabledResources.isEmpty &&
        !_previewShowNpcs &&
        !_previewShowAnimals) {
      return '표시할 핀을 선택해보세요';
    }

    final labels = <String>[];

    for (final resourceName in _previewEnabledResources) {
      labels.add(_getPreviewDisplayName(resourceName));
    }

    if (_previewShowNpcs) {
      labels.add('NPC');
    }

    if (_previewShowAnimals) {
      labels.add('동물');
    }

    return labels.join(' · ');
  }

  Widget _buildEventSection(BuildContext context) {
    final events = _activeEvents;

    if (events.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: Text('진행 중인 이벤트가 없습니다.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    }

    // Column 내부에서 제목 제거하고 PageView 영역만 남김
    return Column(
      children: [
        const SizedBox(height: 4),
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _eventPageController,
            itemCount: 10000,
            onPageChanged: (index) => setState(() => _currentEventIndex = index % events.length),
            itemBuilder: (context, index) {
              // ... (기존 PageView 아이템 빌더 코드는 동일하게 유지) ...
              final event = events[index % events.length];
              final imageUrl = _resolveEventImageUrl(event.imageUrl);

              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () async => await _openEventLink(event.linkUrl, event.id),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: _kCommonShadow,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            imageUrl.isEmpty
                                ? Container(color: const Color(0xFFF8FAFC), child: const Icon(Icons.image_not_supported_outlined))
                                : Image.network(imageUrl, fit: BoxFit.cover),
                            Positioned(
                              left: 0, right: 0, bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(20, 32, 110, 18),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0x88000000), Color(0x00000000)]),
                                ),
                                child: Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1),
                              ),
                            ),
                            Positioned(
                              top: 14, right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(999)),
                                child: Text(formatDdayLabel(event.endAt), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12, right: 28,
                    child: GestureDetector(
                      onTap: () => widget.openEventScreen?.call(),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.grid_view_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('${_currentEventIndex + 1}/${events.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (events.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(events.length, (index) {
              final selected = index == _currentEventIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 14 : 6, height: 6,
                decoration: BoxDecoration(color: selected ? snackAccent : const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(999)),
              );
            }),
          ),
        ],
      ],
    );
  }

  // 1. 설정 화면 이동 함수 정의
  void _navigateToSettings() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

// 2. 앱 타이틀 위젯 정의 (실험실 스타일)
  Widget _buildAppTitle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Keeper's Note",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF2D3436),
            letterSpacing: -0.6,
            fontFamily: 'SF Pro',
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: snackAccent,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildIntegratedSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF4A4543),
          fontWeight: FontWeight.w600,
        ),
        onTapOutside: (_) {
          _searchFocusNode.unfocus();
          setState(() {
            _searchSuggestions = [];
          });
        },
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          prefixIcon: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFFFF8E7C),
            ),
          ),
          hintText: '찾는 아이템을 검색해보세요.',
          hintStyle: const TextStyle(
            color: Color(0xFFA8A29E),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(
              Icons.close,
              size: 18,
              color: Color(0xFFA8A29E),
            ),
            onPressed: () {
              _searchController.clear();
              _searchFocusNode.unfocus();
              setState(() {
                _searchSuggestions = [];
              });
            },
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, double topPadding) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.42, 1.0],
          colors: [
            const Color(0xFFFFC2B8).withOpacity(0.45),
            const Color(0xFFFFECE8).withOpacity(0.30),
            const Color(0xFFFFFAF8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildAppBarButton(
                      icon: 'assets/icons/ic_menu.svg',
                      onTap: widget.openDrawer ?? () {},
                    ),
                    const Spacer(),
                    _buildAppTitle(),
                    const Spacer(),
                    _buildAppBarButton(
                      icon: 'assets/icons/ic_settings.svg',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildIntegratedSearchBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarButton({
    required String icon,
    required VoidCallback onTap,
  }) {
    final bool isMenu = icon.contains('menu');

    return Material(
      color: isMenu
          ? const Color(0xFFFFF3F0)
          : const Color(0xFFF2F7FF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40, // 🔥 40 → 34
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMenu
                  ? const Color(0xFFFFE2DB)
                  : const Color(0xFFDCEBFF),
              width: 1,
            ),
          ),
          child: SvgPicture.asset(
            icon,
            width: 17, // 🔥 20 → 17
            height: 17,
            colorFilter: ColorFilter.mode(
              isMenu
                  ? const Color(0xFFFF8E7C)
                  : const Color(0xFF4A90E2),
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    // 함수 내부의 Padding을 최소화하여 재사용성을 높였습니다.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10), // 위아래 간격만 유지
      child: Row(
        children: [
          // 얇고 깔끔한 포인트 캡슐
          Container(
            width: 3.5,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8E7C),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 8),

          // 세련된 두께의 텍스트
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3436),
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  final double progress;
  // 생성자에서 prompt를 삭제하고 progress만 남겼습니다.
  _RainPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xBBD6F0FF) // 맑고 투명한 빗방울 색상
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 18; i++) {
      // i를 활용해 불규칙한 가로 위치 생성
      double factor = (i * 19.3) % 1.0;
      double x = (size.width * factor);

      // 속도 차이 부여 (1.0배 ~ 2.5배 속도)
      double speed = 1.0 + (i % 4) * 0.5;
      double y = ((size.height + 40) * (progress * speed) + (i * 25)) % (size.height + 40) - 20;

      // 빗방울 크기를 동글동글한 비율로 설정 (너비 2.5~3.3, 높이 6~10)
      double dropWidth = 2.5 + (i % 3) * 0.8;
      double dropHeight = 6.0 + (i % 5) * 4.0;

      // 둥근 빗방울(RRect) 그리기
      RRect drop = RRect.fromLTRBR(
        x,
        y,
        x + dropWidth,
        y + dropHeight,
        Radius.circular(dropWidth / 2), // 모서리를 완전히 둥글게 하여 방울 모양 구현
      );

      // 개별 투명도 랜덤화로 입체감 부여
      paint.color = const Color(0xBBD6F0FF).withOpacity(0.4 + (i % 5) * 0.1);

      canvas.drawRRect(drop, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) => oldDelegate.progress != progress;
}

class _SnowPainter extends CustomPainter {
  final double progress;
  _SnowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xCCFFFFFF);

    for (int i = 0; i < 25; i++) {
      // 불규칙한 가로 위치
      double factor = (i * 13.3) % 1.0;
      double baseX = size.width * factor;

      // 각 눈송이마다 흔들리는 타이밍(Phase)과 폭을 다르게 설정
      double swayPhase = i * 0.5;
      double swayWidth = 10.0 + (i % 3) * 5.0;
      double x = baseX + sin((progress * 2 * pi) + swayPhase) * swayWidth;

      // 속도 차이 (큰 눈송이는 살짝 더 무겁게)
      double speed = 0.5 + (i % 5) * 0.2;
      double y = ((size.height + 20) * (progress * speed) + (i * 15)) % (size.height + 20) - 10;

      // 눈송이 크기 다양화
      double radius = 1.5 + (i % 4) * 0.8;

      // 살짝 번지는 느낌을 위해 투명도 조절
      paint.color = Colors.white.withOpacity(0.4 + (i % 5) * 0.12);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => oldDelegate.progress != progress;
}

class _RainbowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFFFFB703),
      const Color(0xFFFFF08A),
      const Color(0xFF7AE582),
      const Color(0xFF72DDF7),
      const Color(0xFF8093F1),
      const Color(0xFFC77DFF),
    ];

    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i].withOpacity(0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8;

      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height),
          width: size.width - (i * 16),
          height: size.height * 1.2 - (i * 10),
        ),
        3.141592,
        3.141592,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PreviewSpawnTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFF8E7C);

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..quadraticBezierTo(0, size.height * 0.45, size.width / 2, 0)
      ..quadraticBezierTo(size.width, size.height * 0.45, size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
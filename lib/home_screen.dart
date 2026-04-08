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

  Color _getWeatherIconColor(String weather) {
    switch (weather) {
      case '맑음':
        return const Color(0xFFFFB703);
      case '흐림':
        return const Color(0xFF94A3B8);
      case '비':
        return const Color(0xFF7DD3FC);
      case '무지개':
        return const Color(0xFFFFD166);
      case '눈':
        return const Color(0xFFBFE9FF);
      default:
        return Colors.white;
    }
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


  IconData _getWeatherIcon(String weather) {
    switch (weather) {
      case '맑음':
        return Icons.wb_sunny_rounded;
      case '흐림':
        return Icons.cloud_rounded;
      case '비':
        return Icons.umbrella_rounded;
      case '무지개':
        return Icons.auto_awesome;
      case '눈':
        return Icons.ac_unit;
      default:
        return Icons.wb_cloudy_rounded;
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
    if (res.resourceName.contains('fluorite') ||
        res.koName.contains('형광석')) {
      return 'fluorite';
    }

    if (res.resourceName.contains('oak') ||
        res.koName.contains('참나무')) {
      return 'roaming_oak';
    }

    if (res.resourceName.contains('truffle') ||
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

  Future<void> _loadMapPreviewResources() async {
    try {
      final data = await ApiService.getResources(voterId: _voterId);
      if (!mounted) return;

      final defaultNames = <String>{};

      for (final res in data) {
        final key = _normalizePreviewFilterKey(res);

        if (key == 'roaming_oak' ||
            key == 'fluorite' ||
            key == 'black_truffle') {
          defaultNames.add(key);
        }
      }

      setState(() {
        _allPreviewCandidates = data;

        if (_previewEnabledResources.isEmpty) {
          _previewEnabledResources = defaultNames;
        }

        _mapPreviewResources = _getFilteredPreviewResources(data);
        _isMapPreviewLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMapPreviewLoading = false;
      });
    }
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
                                        key == 'black_truffle') {
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

  String _getPreviewDisplayName(String resourceName) {
    final sample = _getPreviewRepresentativeByResourceName(resourceName);
    return sample?.koName ?? resourceName;
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
    final double topPadding = MediaQuery.of(context).padding.top;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // [Layer 1] 배경 이미지 (최하단)
            Positioned.fill(
              child: Image.asset('assets/images/bg_gradient.png', fit: BoxFit.cover),
            ),

            // [Layer 2] 메인 콘텐츠 스크롤 영역
            Positioned.fill(
              child: RefreshIndicator(
                color: snackAccent,
                backgroundColor: Colors.white,
                onRefresh: () async {
                  if (widget.onRefresh != null) await widget.onRefresh!();
                  await _loadMapPreviewResources();
                },
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  // [수정] 강제 여백을 없애고 콘텐츠가 위로 자연스럽게 올라가게 설정
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 중요: 앱바의 높이만큼 빈 공간을 주어 첫 콘텐츠(이벤트)가 앱바 아래에서 시작하게 함
                      // 앱바의 높이가 대략 180~200px 정도이므로 그만큼 여백을 줍니다.
                      const SizedBox(height: 190),

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
                                  const SizedBox(height: 2),
                                  _buildTodoSummaryCard(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('날씨'),
                                  const SizedBox(height: 2),
                                  _buildWeatherCard(_currentWeather),
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

                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
            ),

            // [Layer 3] 커스텀 앱바 (최상단에 고정)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildCustomAppBar(context, topPadding),
            ),

            // 검색 제안 목록 (검색바 바로 아래 배치)
            if (_searchSuggestions.isNotEmpty)
              Positioned(
                // 앱바 높이와 돋보기 아이콘 위치를 고려해 대략적인 위치 잡기
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

// 검색 제안 목록 위젯 분리 (깔끔한 코드를 위해)
  Widget _buildSearchSuggestionsOverlay() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _searchSuggestions.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final item = _searchSuggestions[index];
              return InkWell(
                onTap: () {
                  _searchFocusNode.unfocus();
                  _searchController.clear();
                  setState(() => _searchSuggestions = []);
                  widget.onSearchItemSelected?.call(item);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset(item.iconPath, width: 34, height: 34, fit: BoxFit.cover)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3436)))),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFD1D1D6)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
    return Positioned.fill(
      child: ClipRRect(
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
                );

              case '눈':
                return CustomPaint(
                  painter: _SnowPainter(progress: t),
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
                return const SizedBox.shrink();
            }
          },
        ),
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
        double scale = 1;

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
            child: Icon(
              _getWeatherIcon(weather),
              size: 52,
              color: _getWeatherIconColor(weather),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeatherCard(String weather) {
    return Container(
      height: 220,
      decoration: _buildWeatherBackground(weather),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            _buildAnimatedWeatherBackground(weather),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _getWeatherSubTextColor(weather),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showWeeklyWeatherPopup,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            // 배경색에 따라 버튼 색상을 다르게 (유리창 느낌)
                            color: (weather == '맑음' || weather == '눈')
                                ? Colors.black.withOpacity(0.06) // 밝은 배경에선 살짝 어두운 유리
                                : Colors.white.withOpacity(0.2), // 어두운 배경에선 밝은 유리
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '주간',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              // 글자색을 헤더 색상과 맞춤
                              color: _getWeatherTextColor(weather),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildWeatherAnimatedIcon(weather),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weather,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 23, // 크기를 27 -> 23으로 축소
                                height: 1.2,
                                fontWeight: FontWeight.w700, // 굵기를 w800 -> w700으로 소폭 하향
                                color: _getWeatherTextColor(weather),
                                letterSpacing: -0.5, // 자간을 살짝 좁혀서 더 단정한 느낌 추가
                              ),
                            ),
                            const SizedBox(height: 4), // 간격도 살짝 조정
                            Text(
                              _getWeatherDescription(weather),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w500, // 설명 글자도 살짝 얇게 조정
                                color: _getWeatherSubTextColor(weather),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(height: 12),
                  _buildHourlyWeatherStrip(weather),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyWeatherStrip(String currentWeather) {
    // 밝은 배경색인지 확인 (맑음, 눈, 무지개)
    final bool isLightBg = ['맑음', '눈', '무지개'].contains(currentWeather);

    final hourly = [
      {'time': '12시', 'weather': '맑음'},
      {'time': '15시', 'weather': '흐림'},
      {'time': '18시', 'weather': '비'},
      {'time': '21시', 'weather': '맑음'},
      {'time': '00시', 'weather': '눈'},
    ];

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: hourly.length,
        // 🔥 에러 해결: 아이템 사이의 간격을 정의합니다.
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = hourly[index];
          final weather = item['weather']!;

          return Container(
            width: 58,
            decoration: BoxDecoration(
              // 🎨 개선된 디자인: 회색 대신 반투명 화이트(유리 효과) 적용
              color: isLightBg
                  ? Colors.white.withOpacity(0.45) // 밝은 배경에선 조금 더 불투명하게
                  : Colors.white.withOpacity(0.12), // 어두운 배경에선 투명하게
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.2), // 미세한 테두리 추가
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['time']!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    // 글자색을 배경색 톤에 맞춘 네이비 그레이로 설정
                    color: _getWeatherTextColor(currentWeather),
                  ),
                ),
                const SizedBox(height: 5),
                Icon(
                  _getWeatherIcon(weather),
                  size: 16,
                  color: _getWeatherIconColor(weather).withOpacity(0.9),
                  // 🔥 아이콘 가독성을 위한 그림자 추가
                  shadows: [
                    Shadow(
                      color: isLightBg
                          ? Colors.black.withOpacity(0.12) // 밝은 배경에선 아주 미세하게
                          : Colors.black.withOpacity(0.3),  // 어두운 배경에선 조금 더 선명하게
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 22, color: Color(0xFF64748B)),
                  SizedBox(width: 10),
                  Text(
                    '주간 날씨 예보 (클릭 시 변경)', // 안내 텍스트 살짝 수정
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                children: weekly.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    // 🔥 클릭 가능하도록 InkWell 추가
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _currentWeather = item['weather']!; // 클릭한 날씨로 변경
                        });
                        Navigator.pop(context); // 팝업 닫기
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFF1F5F9),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                item['day']!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Icon(
                                    _getWeatherIcon(item['weather']!),
                                    size: 24,
                                    color: _getWeatherIconColor(item['weather']!),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    item['weather']!,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
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
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodoSummaryCard() {
    const int displayLimit = 5;

    final items = widget.todoList;
    final visible = items.take(displayLimit).toList();
    final extraCount = items.length - visible.length;

    return GestureDetector(
      onTap: _handleTodoCardTap,
      onTapDown: (_) {
        setState(() => _isTodoCardPressed = true);
      },
      onTapCancel: () {
        setState(() => _isTodoCardPressed = false);
      },
      onTapUp: (_) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await Future.delayed(const Duration(milliseconds: 70));
        if (!mounted) return;
        setState(() => _isTodoCardPressed = false);
        await _handleTodoCardTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _isTodoCardPressed ? 0.985 : 1.0,
        child: Container(
          height: 220,
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: _kCommonShadow,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(visible.length, (index) {
                          final todo = visible[index];
                          final String text =
                          (todo['taskName'] ??
                              todo['title'] ??
                              todo['task'] ??
                              '')
                              .toString();
                          final bool isDone =
                              (todo['completed'] ?? false) == true;

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == visible.length - 1 ? 0 : 6,
                            ),
                            child: _buildTodoRow(
                              index: index,
                              text: text,
                              isDone: isDone,
                              onCheckTap: () =>
                                  widget.onTodoToggle?.call(index),
                            ),
                          );
                        }),
                      ),
                    ),
                    if (extraCount > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '+$extraCount개 더 있어요',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFFF8E7C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFFCBD5E1),
                  ),
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
                        borderRadius: BorderRadius.circular(22),
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
                Icon(
                  _getWeatherIcon(weather),
                  size: 19,
                  color: weather == '눈'
                      ? const Color(0xFF60A5FA)
                      : Colors.white,
                ),
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
                              else ..._mapPreviewResources.map((res) => _buildHomeMapPreviewMarker(res, constraints.maxWidth, constraints.maxHeight)),
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

// 3. 통합 검색바 수정 (기존 검색 로직 연결)
  Widget _buildIntegratedSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        // 1. 따뜻한 베이지 빛이 도는 웜 그레이 배경 (비스킷 느낌)
        color: const Color(0xFFF7F6F2),
        borderRadius: BorderRadius.circular(24),
        // 2. 테두리에 코랄 포인트를 주되, 따뜻한 배경과 어울리게 투명도 조절
        border: Border.all(
          color: snackAccent.withOpacity(0.28),
          width: 1.3,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: 14,
          // 3. 글자색도 차가운 네이비 대신 따뜻한 다크 브라운 그레이 사용
          color: Color(0xFF4A4543),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: snackAccent, // 여전히 코랄 포인트로 활력 부여
            ),
          ),
          hintText: '어떤 아이템을 찾으시나요?',
          hintStyle: const TextStyle(
            // 4. 힌트 텍스트도 배경과 톤을 맞춘 부드러운 토프(Taupe) 색상
            color: Color(0xFFA8A29E),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: const Color(0xFFA8A29E),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchSuggestions = []);
            },
          )
              : null,
        ),
        onChanged: (value) => _handleSearchChanged(),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, double topPadding) {
    return Container(
      // 1. 천장(상태바)부터 검색창 하단부까지 배경을 채웁니다.
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90), // 뒤가 은은하게 비치는 반투명 화이트
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24), // 하단 모서리만 살짝 굴려 단정하게 마무리
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // 2. 내부 패딩에서 상단바 높이(topPadding)를 더해 아이콘들이 상태바 아래에 오게 합니다.
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단: 메뉴 - 타이틀 - 설정
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAppBarButton(
                icon: 'assets/icons/ic_menu.svg',
                onTap: widget.openDrawer,
                bgColor: const Color(0xFFF8FAFC),
              ),
              _buildAppTitle(),
              _buildAppBarButton(
                icon: 'assets/icons/ic_settings.svg',
                onTap: _navigateToSettings,
                bgColor: const Color(0xFFF8FAFC),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 하단: 따뜻한 웜그레이 검색바
          _buildIntegratedSearchBar(),
        ],
      ),
    );
  }

  Widget _buildAppBarButton({
    required String icon,
    required VoidCallback? onTap,
    required Color bgColor,
  }) {
    return StatefulBuilder(
      builder: (context, setBtnState) {
        bool isPressed = false;

        return GestureDetector(
          // 터치 시작 시 상태 변경
          onTapDown: (_) => setBtnState(() => isPressed = true),
          // 터치 종료/취소 시 상태 복구
          onTapUp: (_) => setBtnState(() => isPressed = false),
          onTapCancel: () => setBtnState(() => isPressed = false),
          onTap: onTap,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 100),
            scale: isPressed ? 0.9 : 1.0, // 1. 누를 때 크기 10% 축소
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                // 2. 누를 때 배경색을 살짝 어둡게 변경 (0.85 투명도 적용)
                color: isPressed ? bgColor.withOpacity(0.7) : bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isPressed
                    ? [] // 3. 누를 때는 그림자를 없애서 바닥에 붙은 느낌 전달
                    : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SvgPicture.asset(
                icon,
                colorFilter: ColorFilter.mode(
                  // 4. 누를 때 아이콘 색상도 살짝 강조 (선택 사항)
                  isPressed ? const Color(0xFF1E293B) : const Color(0xFF475569),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        );
      },
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
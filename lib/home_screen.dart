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
import 'services/home_widget_service.dart';
import 'setting_screen.dart';
import 'map_screen.dart';
import 'models/global_search_item.dart';
import 'services/global_search_service.dart';
import 'models/event_item.dart';
import 'dart:ui';
import 'dart:math';
import 'dart:convert';

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
  Timer? _weatherRefreshTimer;
  bool _isUserInteracting = false;
  bool _isWeatherCardPressed = false;
  int _currentEventIndex = 0;

  static const Set<String> _previewDefaultResourceKeys = {
    'roaming_oak',
    'fluorite',
  };

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
    final raw = res.resourceName;

    if (raw == 'fluorite' ||
        raw == 'flawless_fluorite' ||
        res.koName.contains('형광석')) {
      return 'fluorite';
    }

    if (raw == 'roaming_oak' || res.koName.contains('참나무')) {
      return 'roaming_oak';
    }

    if (raw == 'black_truffle' ||
        raw == 'black-truffle' ||
        res.koName.contains('트러플')) {
      return 'black_truffle';
    }

    return raw;
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
    final bool hasOak = point.oak != null;
    final bool hasFluorite = point.fluorite != null;
    final bool isVerified = point.isOakVerified || point.isFluoriteVerified;

    final Color borderColor = hasOak && hasFluorite
        ? const Color(0xFFBFA2FF) // 둘다 (연보라)
        : hasOak
        ? const Color(0xFFFF8E7C) // 🌳 참나무 (코랄/주황)
        : const Color(0xFF8ED6FF); // 💎 형광석 (파스텔 하늘)

    final String iconPath = hasOak
        ? point.oak!.iconPath
        : hasFluorite
        ? point.fluorite!.iconPath
        : 'assets/images/default.png';

    return IgnorePointer(
      child: isVerified
          ? _buildHomePreviewCircleMarker(
        iconPath: iconPath,
        borderColor: borderColor,
        size: 24,
        fit: BoxFit.contain,
        padding: const EdgeInsets.all(3),
      )
          : Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor,
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '❓',
          style: TextStyle(
            fontSize: 12,
            height: 1.0,
            fontWeight: FontWeight.w900,
            color: borderColor,
          ),
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

  static const String _baseUrl = 'http://161.33.30.40:8080';

  String _currentWeather = '맑음';
  bool _isWeatherLoading = false;

  List<Map<String, String>> _hourlyWeather = [];
  List<Map<String, String>> _weeklyWeather = [];

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
      List<String> categories,
      ) {
    final fixedKeys = _allPreviewCandidates
        .where((res) => categories.contains(res.category))
        .where((res) => res.category != 'npc' && res.category != 'animal')
        .map((res) => _normalizePreviewFilterKey(res));

    final spawnKeys = _previewSpawnPoints
        .expand((point) => point.resources)
        .where((res) {
      if (categories.contains('tree') && res.resourceName == 'roaming_oak') {
        return true;
      }
      if (categories.contains('mineral') &&
          (res.resourceName == 'fluorite' ||
              res.resourceName == 'flawless_fluorite')) {
        return true;
      }
      return false;
    })
        .map((res) => _normalizeSpawnPreviewFilterKey(res));

    return {
      ...fixedKeys,
      ...spawnKeys,
    }.toList()
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
    } catch (_) {}

    for (final point in _previewSpawnPoints) {
      for (final res in point.resources) {
        if (_normalizeSpawnPreviewFilterKey(res) == resourceName) {
          return ResourceModel(
            id: res.id,
            resourceName: res.resourceName,
            category: point.isOakOnly ? 'tree' : 'mineral',
            description: '',
            x: point.x,
            y: point.y,
            voteCount: res.voteCount,
            isVerified: res.isVerified,
            isFixed: false,
            isActive: true,
            alreadyVoted: false,
            alreadyVotedSameType: res.alreadyVotedSameType,
            votedByMe: res.votedByMe,
          );
        }
      }
    }

    return null;
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

      final allFixed = data.fixedResources;
      final allSpawn = data.spawnPoints;

      setState(() {
        if (_previewEnabledResources.isEmpty) {
          _previewEnabledResources = {..._previewDefaultResourceKeys};
        } else {
          _previewEnabledResources = {
            ..._previewEnabledResources,
          }..removeWhere((key) => !_getPreviewFilterKeys().contains(key));
        }

        _allPreviewCandidates = allFixed;
        _previewSpawnPoints = allSpawn;
        _mapPreviewResources = _getFilteredPreviewResources(allFixed);
        _isMapPreviewLoading = false;
      });

      await _syncTodayInfoToWidget(); // 추가
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMapPreviewLoading = false;
      });
    }
  }

  Future<void> _syncTodayInfoToWidget() async {
    String oakText = '미확정';
    String fluoriteText = '미확정';

    SpawnPointModel? oakPoint;
    SpawnPointModel? fluoritePoint;

    for (final point in _previewSpawnPoints) {
      for (final r in point.resources) {
        if (r.resourceName == 'roaming_oak' &&
            (r.isVerified || r.isFixed) &&
            r.isActive) {
          oakPoint = point;
        }

        if (r.resourceName == 'fluorite' &&
            (r.isVerified || r.isFixed) &&
            r.isActive) {
          fluoritePoint = point;
        }
      }
    }

    if (oakPoint != null) {
      oakText = oakPoint.placeLabel?.trim().isNotEmpty == true
          ? oakPoint.placeLabel!.trim()
          : '위치 확인 중';
    }

    if (fluoritePoint != null) {
      fluoriteText = fluoritePoint.placeLabel?.trim().isNotEmpty == true
          ? fluoritePoint.placeLabel!.trim()
          : '위치 확인 중';
    }

    final now = DateTime.now();
    final updatedAt =
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await KeepersHomeWidgetService.saveAndRefresh(
      weather: _normalizeWeatherLabel(_currentWeather),
      oakText: oakText,
      fluoriteText: fluoriteText,
      updatedAt: updatedAt,
    );
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
      duration: const Duration(seconds: 14),
    )
      ..repeat();

    _previewTransformController.addListener(_onPreviewTransformChanged);
    _checkAndResetAtStart();
    _scheduleSixAMTimer();
    _initializeHomeWidgetSync();
    _loadGlobalSearchItems();
    _scheduleNextWeatherRefresh();
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

  String _normalizeWeatherLabel(String? raw) {
    final value = (raw ?? '').trim();

    switch (value) {
      case 'SUNNY':
      case 'CLEAR':
      case '맑음':
        return '맑음';
      case 'CLOUDY':
      case 'OVERCAST':
      case '흐림':
        return '흐림';
      case 'RAIN':
      case '비':
        return '비';
      case 'SNOW':
      case '눈':
        return '눈';
      case 'RAINBOW':
      case '무지개':
        return '무지개';
      default:
        return value.isEmpty ? '맑음' : value;
    }
  }

  String _formatHourlyWeatherLabel(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final lower = value.toLowerCase();

    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
    if (timeMatch == null) {
      return value;
    }

    final hour = timeMatch.group(1)!.padLeft(2, '0');
    final formattedHour = '$hour시';

    if (lower.contains('내일')) {
      return '내일 $formattedHour';
    }

    return formattedHour;
  }

  String _weekdayLabelFromDate(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate);
      const labels = ['월', '화', '수', '목', '금', '토', '일'];
      return labels[dt.weekday - 1];
    } catch (_) {
      return rawDate;
    }
  }

  void _scheduleNextWeatherRefresh() {
    _weatherRefreshTimer?.cancel();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final candidates = <DateTime>[
      today.add(const Duration(hours: 6)),
      today.add(const Duration(hours: 12)),
      today.add(const Duration(hours: 18)),
      today.add(const Duration(days: 1)),
      today.add(const Duration(days: 1, hours: 6)),
    ].where((t) => t.isAfter(now)).toList()
      ..sort();

    if (candidates.isEmpty) return;

    final nextTime = candidates.first;
    final duration = nextTime.difference(now);

    _weatherRefreshTimer = Timer(duration, () async {
      await _loadWeather();
      _scheduleNextWeatherRefresh();
    });
  }

  Future<void> _loadWeather() async {
    try {
      if (mounted) {
        setState(() {
          _isWeatherLoading = true;
        });
      }

      final currentRes = await http.get(
        Uri.parse('$_baseUrl/api/weather/current'),
      );

      final weeklyRes = await http.get(
        Uri.parse('$_baseUrl/api/weather/weekly'),
      );

      if (!mounted) return;

      if (currentRes.statusCode == 200) {
        final currentData = jsonDecode(utf8.decode(currentRes.bodyBytes));
        final String currentWeather =
        (currentData['currentWeather'] ?? '맑음').toString();

        final List<dynamic> timeline =
            (currentData['timeline'] as List<dynamic>?) ?? const [];

        final List<Map<String, String>> hourly = timeline.map((e) {
          final map = e as Map<String, dynamic>;
          return {
            'time': (map['label'] ?? '').toString(),
            'weather': (map['weather'] ?? '맑음').toString(),
            'slot': (map['slot'] ?? '').toString(),
          };
        }).toList();

        setState(() {
          _currentWeather = currentWeather;
          _hourlyWeather = hourly;
        });
      }

      if (weeklyRes.statusCode == 200) {
        final weeklyData = jsonDecode(utf8.decode(weeklyRes.bodyBytes));
        final List<dynamic> days =
            (weeklyData['days'] as List<dynamic>?) ?? const [];

        final List<Map<String, String>> weekly = days.map((e) {
          final map = e as Map<String, dynamic>;
          return {
            'day': (map['dayOfWeek'] ?? '').toString(),
            'weather': (map['weather'] ?? '맑음').toString(),
            'date': (map['date'] ?? '').toString(),
          };
        }).toList();

        setState(() {
          _weeklyWeather = weekly;
        });
      }

      await _syncTodayInfoToWidget(); // 추가
    } catch (e) {
      debugPrint('날씨 로드 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isWeatherLoading = false;
      });
    }
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

  Future<void> _initializeHomeWidgetSync() async {
    await _loadVoterId();
    await _loadMapPreviewResources();
    await _loadWeather();
    await _syncTodayInfoToWidget();
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
    _weatherRefreshTimer?.cancel();
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
      final String key = _normalizePreviewFilterKey(res);
      final bool isNpc = res.category == 'npc';
      final bool isAnimal = res.category == 'animal';
      final bool isVoteTarget = key == 'roaming_oak' || key == 'fluorite';

      // 같은 종류에 내가 이미 투표한 다른 좌표 숨김
      if (isVoteTarget && _shouldHideOtherSameTypePins(res)) {
        return false;
      }

      // 일반 자원 필터
      if (_previewEnabledResources.contains(key)) {
        return true;
      }

      // NPC / 동물 토글
      if (_previewShowNpcs && isNpc) {
        return true;
      }

      if (_previewShowAnimals && isAnimal) {
        return true;
      }

      return false;
    }).toList();
  }

  void _applyPreviewFilter({
    required Set<String> resources,
    required bool showNpcs,
    required bool showAnimals,
  }) {
    setState(() {
      _previewEnabledResources = {...resources};
      _previewShowNpcs = showNpcs;
      _previewShowAnimals = showAnimals;
      _mapPreviewResources = _getFilteredPreviewResources(_allPreviewCandidates);
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

    void resetToDefault(StateSetter setModalState) {
      setModalState(() {
        tempResources
          ..clear()
          ..addAll(_previewDefaultResourceKeys);
        tempShowNpcs = false;
        tempShowAnimals = false;
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildToggleRow({
              required IconData icon,
              required String title,
              required bool value,
              required ValueChanged<bool> onChanged,
            }) {
              return Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: value
                      ? const Color(0xFFFFF8F5)
                      : Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: value
                        ? const Color(0xFFFFE0D8)
                        : const Color(0xFFF1E7E3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.025),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: value
                          ? const Color(0xFFFF8E7C)
                          : const Color(0xFF7A8A9A),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: value ? FontWeight.w700 : FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onChanged(!value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 49,
                        height: 28,
                        decoration: BoxDecoration(
                          color: value
                              ? const Color(0xFFFF8E7C).withOpacity(0.42)
                              : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment:
                          value ? Alignment.centerRight : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: Container(
                              width: 23,
                              height: 23,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
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

            Widget buildSectionLabel(String title) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                  ),
                ),
              );
            }

            Widget buildChip(String resourceName) {
              final bool selected = tempResources.contains(resourceName);
              final sample =
              _getPreviewRepresentativeByResourceName(resourceName);

              String? fallbackIconPath;
              if (resourceName == 'roaming_oak') {
                fallbackIconPath = 'assets/images/resources/oak.png';
              } else if (resourceName == 'fluorite') {
                fallbackIconPath = 'assets/images/resources/fluorite.png';
              }

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
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFFF1ED)
                        : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFF8E7C)
                          : const Color(0xFFFFE4DE),
                      width: 1,
                    ),
                    boxShadow: selected
                        ? [
                      BoxShadow(
                        color: const Color(0xFFFF8E7C).withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sample != null || fallbackIconPath != null)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFFFD4CC)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: sample != null || fallbackIconPath != null
                              ? Image.asset(
                            sample?.iconPath ?? fallbackIconPath!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.inventory_2_outlined,
                                size: 12,
                                color: Colors.grey,
                              );
                            },
                          )
                              : const SizedBox.shrink(),
                        ),
                      const SizedBox(width: 7),
                      Text(
                        _getPreviewDisplayName(resourceName),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600,
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

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.98),
                    const Color(0xFFFFFBFA),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 26,
                    offset: const Offset(0, -8),
                  ),
                  BoxShadow(
                    color: const Color(0xFFFF8E7C).withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7E5E4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '지도 미리보기 필터',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '보고 싶은 자원과 캐릭터만 골라서 볼 수 있어요.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A8A9A),
                        ),
                      ),
                      const SizedBox(height: 18),

                      buildSectionLabel('캐릭터'),
                      Row(
                        children: [
                          Expanded(
                            child: buildToggleRow(
                              icon: Icons.person_rounded,
                              title: 'NPC',
                              value: tempShowNpcs,
                              onChanged: (value) {
                                setModalState(() {
                                  tempShowNpcs = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: buildToggleRow(
                              icon: Icons.pets_rounded,
                              title: '동물',
                              value: tempShowAnimals,
                              onChanged: (value) {
                                setModalState(() {
                                  tempShowAnimals = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),
                      buildSectionLabel('채집 자원'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: gatherItems.map(buildChip).toList(),
                      ),

                      if (mushroomItems.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        buildSectionLabel('버섯'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: mushroomItems.map(buildChip).toList(),
                        ),
                      ],

                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => resetToDefault(setModalState),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side: const BorderSide(
                                  color: Color(0xFFFFD8D0),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                foregroundColor: const Color(0xFFFF8E7C),
                              ),
                              child: const Text(
                                '기본값으로',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: const Color(0xFFFF8E7C),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                '적용하기',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
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

    final bool isNpc = res.category == 'npc';
    final bool isAnimal = res.category == 'animal';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildPreviewUnifiedSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreviewSheetHandle(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isAnimal
                          ? const Color(0xFFD9EEFF)
                          : isNpc
                          ? const Color(0xFFFFDDD7)
                          : const Color(0xFFFFDDD7),
                      width: 1.4,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      res.iconPath,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                      const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        res.koName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isAnimal
                              ? const Color(0xFFEFF8FF)
                              : const Color(0xFFFFF4F1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isAnimal
                              ? '동물 친구'
                              : isNpc
                              ? '마을 주민'
                              : isActuallyVerified
                              ? '위치 확정'
                              : isVoteTarget
                              ? '투표 가능한 위치'
                              : '위치 정보',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isAnimal
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFFF8E7C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE7EDF5)),
              ),
              child: Text(
                (res.description != null && res.description!.trim().isNotEmpty)
                    ? res.description!.trim()
                    : '설명 정보가 없습니다.',
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            if (showVoteButton) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Color(0xFFFFFAF8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFFE7E1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8E7C).withOpacity(0.07),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3EF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFDED6),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isActuallyVerified
                            ? Icons.check_rounded
                            : Icons.how_to_vote_rounded,
                        color: const Color(0xFFFF8E7C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            canVote ? '여기 있어요!' : '이미 투표했어요',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2D3436),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '현재 ${res.voteCount}표 모였어요',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7A8A9A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: canVote ? () => _handlePreviewVote(res) : null,
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: canVote
                                ? const Color(0xFFFF8E7C)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: canVote
                                ? [
                              BoxShadow(
                                color: const Color(0xFFFF8E7C)
                                    .withOpacity(0.24),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                                : null,
                          ),
                          child: Text(
                            canVote ? '투표' : '완료',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: canVote
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8E7C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 15,
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

    const double appBarBodyHeight = 108;
    const double appBarBottomGap = 2; // 앱바 아래 고정 여백
    final double refreshTop = topPadding + appBarBodyHeight + appBarBottomGap;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F6),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/bg_gradient.png',
                fit: BoxFit.cover,
              ),
            ),

            Positioned.fill(
              top: refreshTop,
              child: RefreshIndicator(
                color: const Color(0xFFFF8E7C),
                backgroundColor: Colors.white,
                edgeOffset: 8,
                displacement: 26,
                onRefresh: () async {
                  await _loadWeather();
                  await widget.onRefresh?.call();
                  await _loadMapPreviewResources();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.only(
                    top: _getHomeSectionTopSpacing(context),
                    bottom: 110,
                  ),
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

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildCustomAppBar(context, topPadding),
            ),

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
        return '햇살이 내리고 있어요';
      case '흐림':
        return '구름이 지나고 있어요';
      case '비':
        return '비가 내리고 있어요';
      case '무지개':
        return '채집하러 가볼까요?';
      case '눈':
        return '눈이 내리고 있어요';
      default:
        return '오늘의 날씨예요';
    }
  }

  Widget _buildAnimatedWeatherBackground(String weather) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AnimatedBuilder(
        animation: _weatherController,
        builder: (context, child) {
          final t = _weatherController.value;
          final wave = sin(t * pi * 2);

          switch (weather) {
            case '맑음':
              final skyOffset = wave * 10;
              final cloudOffset1 = sin(t * pi * 2) * 12;
              final cloudOffset2 = sin((t * pi * 2) + 1.2) * 10;
              final cloudOffset3 = sin((t * pi * 2) + 2.1) * 8;

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
                    left: 18 + cloudOffset1,
                    child: _weatherBlob(
                      width: 70,
                      height: 24,
                      color: Colors.white.withOpacity(0.28),
                    ),
                  ),

                  Positioned(
                    bottom: 24,
                    right: 18 - cloudOffset2,
                    child: _weatherBlob(
                      width: 60,
                      height: 21,
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),

                  Positioned(
                    bottom: 52,
                    right: 82 - cloudOffset3,
                    child: _weatherBlob(
                      width: 56,
                      height: 20,
                      color: Colors.white.withOpacity(0.20),
                    ),
                  ),
                ],
              );

            case '흐림':
              final cloudDrift = wave * 8;

              return Stack(
                children: [
                  Positioned(
                    top: 22,
                    left: 18 + cloudDrift,
                    child: _weatherBlob(
                      width: 84,
                      height: 28,
                      color: Colors.white.withOpacity(0.14),
                    ),
                  ),
                  Positioned(
                    top: 56,
                    right: 20 - cloudDrift * 0.8,
                    child: _weatherBlob(
                      width: 66,
                      height: 24,
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                  Positioned(
                    bottom: 34,
                    left: 36 + cloudDrift * 0.5,
                    child: _weatherBlob(
                      width: 92,
                      height: 30,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ],
              );

            case '비':
              final rainShift = wave * 5;

              return Stack(
                children: List.generate(9, (index) {
                  final double left = 20 + (index * 28).toDouble();
                  final double top = 12 + ((index % 3) * 24).toDouble();

                  return Positioned(
                    left: left,
                    top: top + (index.isEven ? rainShift : -rainShift),
                    child: Container(
                      width: 2,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              );

            case '무지개':
              final glow = 0.08 + ((wave + 1) / 2) * 0.08;

              return Stack(
                children: [
                  Positioned(
                    left: -10,
                    right: -10,
                    bottom: -28,
                    child: Opacity(
                      opacity: 0.22,
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(120),
                          gradient: const SweepGradient(
                            startAngle: 3.2,
                            endAngle: 6.2,
                            colors: [
                              Color(0xFFFF8BA7),
                              Color(0xFFFFC46B),
                              Color(0xFFFFF08A),
                              Color(0xFF8DE3B7),
                              Color(0xFF82CFFF),
                              Color(0xFFC5A3FF),
                              Color(0xFFFF8BA7),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withOpacity(glow),
                    ),
                  ),
                ],
              );

            case '눈':
              final snowShift = wave * 4;

              return Stack(
                children: List.generate(10, (index) {
                  final double left = 18 + (index * 26).toDouble();
                  final double top = 10 + ((index % 4) * 22).toDouble();

                  return Positioned(
                    left: left,
                    top: top + (index.isEven ? snowShift : -snowShift),
                    child: Opacity(
                      opacity: 0.25,
                      child: Text(
                        '✦',
                        style: TextStyle(
                          fontSize: index.isEven ? 12 : 9,
                          color: Colors.white.withOpacity(0.65),
                        ),
                      ),
                    ),
                  );
                }),
              );

            default:
              return const SizedBox.shrink();
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
        final wave = sin(t * pi * 2);

        double dy = 0;
        double scale = 1.0;

        switch (weather) {
          case '맑음':
            dy = wave * 1.6; // 기존보다 진폭도 살짝 줄임
            scale = 1.0 + (sin(t * pi * 2) * 0.012);
            break;
          case '흐림':
            dy = wave * 0.8;
            break;
          case '비':
            dy = wave * 1.2;
            break;
          case '무지개':
            scale = 1.0 + (sin(t * pi * 2) * 0.02);
            break;
          case '눈':
            dy = wave * 1.2;
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
    final subColor = _getWeatherSubTextColor(weather);
    final textColor = _getWeatherTextColor(weather);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleWeatherCardTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: Colors.white.withOpacity(0.12),
        highlightColor: Colors.white.withOpacity(0.05),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          scale: _isWeatherCardPressed ? 0.985 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    _isWeatherCardPressed ? 0.025 : 0.05,
                  ),
                  blurRadius: _isWeatherCardPressed ? 8 : 12,
                  offset: Offset(0, _isWeatherCardPressed ? 2 : 4),
                ),
              ],
            ),
            child: SizedBox.expand(
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
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                '현재 날씨',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: subColor.withOpacity(0.9),
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: Center(
                                      child: Transform.translate(
                                        offset: const Offset(0, -2),
                                        child: _buildWeatherAnimatedIcon(weather),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    weather,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      height: 1.0,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: Padding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  _getWeatherDescription(weather),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.32,
                                    fontWeight: FontWeight.w500,
                                    color: subColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildHourlyWeatherStrip(weather),
                            const Spacer(),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '탭해서 주간 날씨 보기',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: subColor.withOpacity(0.52),
                                  ),
                                ),
                              ),
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
        ),
      ),
    );
  }

  Widget _buildHourlyWeatherStrip(String currentWeather) {
    final bool isLightBg = ['맑음', '눈', '무지개'].contains(currentWeather);
    final textColor = _getWeatherTextColor(currentWeather);

    final hourly = _hourlyWeather.isEmpty
        ? [
      {'time': '06시', 'weather': currentWeather},
      {'time': '12시', 'weather': currentWeather},
      {'time': '18시', 'weather': currentWeather},
      {'time': '00시', 'weather': currentWeather},
      {'time': '내일 06시', 'weather': currentWeather},
    ]
        : _hourlyWeather;

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: hourly.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = hourly[index];
          final weather = item['weather']!;
          final bool isNow = index == 0;
          final String displayTime =
          _formatHourlyWeatherLabel(item['time'] ?? '');

          return Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: isLightBg
                  ? Colors.white.withOpacity(isNow ? 0.54 : 0.34)
                  : Colors.white.withOpacity(isNow ? 0.20 : 0.11),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(isNow ? 0.34 : 0.18),
                width: isNow ? 1.1 : 1,
              ),
              boxShadow: isNow
                  ? [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    isLightBg ? 0.05 : 0.08,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    displayTime,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: displayTime.length >= 6 ? 8.4 : 9.4,
                      fontWeight: isNow ? FontWeight.w800 : FontWeight.w700,
                      height: 1.05,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Center(
                    child: _buildWeatherIcon(weather, size: 14),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleWeatherCardTap() async {
    setState(() {
      _isWeatherCardPressed = true;
    });

    await Future.delayed(const Duration(milliseconds: 90));

    if (!mounted) return;

    setState(() {
      _isWeatherCardPressed = false;
    });

    _showWeeklyWeatherPopup();
  }

  void _showWeeklyWeatherPopup() {
    final weekly = _weeklyWeather.isEmpty
        ? [
      {'day': '월', 'weather': _currentWeather, 'date': ''},
      {'day': '화', 'weather': _currentWeather, 'date': ''},
      {'day': '수', 'weather': _currentWeather, 'date': ''},
      {'day': '목', 'weather': _currentWeather, 'date': ''},
      {'day': '금', 'weather': _currentWeather, 'date': ''},
      {'day': '토', 'weather': _currentWeather, 'date': ''},
      {'day': '일', 'weather': _currentWeather, 'date': ''},
    ]
        : _weeklyWeather;

    Color weatherAccent(String weather) {
      switch (weather) {
        case '맑음':
          return const Color(0xFFFFC85A);
        case '흐림':
          return const Color(0xFF94A3B8);
        case '비':
          return const Color(0xFF7FB3FF);
        case '눈':
          return const Color(0xFF9FD4F2);
        case '무지개':
          return const Color(0xFFFF8EBF);
        default:
          return const Color(0xFFFF8E7C);
      }
    }

    Color weatherSoftBg(String weather) {
      switch (weather) {
        case '맑음':
          return const Color(0xFFFFF6DE);
        case '흐림':
          return const Color(0xFFF3F6FA);
        case '비':
          return const Color(0xFFEEF5FF);
        case '눈':
          return const Color(0xFFF1F8FD);
        case '무지개':
          return const Color(0xFFFFF1F8);
        default:
          return const Color(0xFFFFF3F0);
      }
    }

    bool isTodayIndex(int index, String day) {
      if (index == 0) return true;
      return day == '오늘';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        final bottomInset = media.padding.bottom;
        final maxHeight = media.size.height * 0.68;

        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBFA),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 26,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9D9D3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFFDED6),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.cloud_queue_rounded,
                        size: 22,
                        color: Color(0xFFFF8E7C),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '주간 날씨 예보',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2E2A27),
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '이번 주 날씨를 확인해보세요.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8C817B),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: List.generate(weekly.length, (index) {
                        final item = weekly[index];
                        final weather = _normalizeWeatherLabel(
                          (item['weather'] ?? '').toString(),
                        );
                        final day = (item['day'] ?? '').toString();
                        final date = (item['date'] ?? '').toString();
                        final today = isTodayIndex(index, day);

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == weekly.length - 1 ? 0 : 8,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: today
                                  ? const Color(0xFFFFF6F3)
                                  : Colors.white.withOpacity(0.94),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: today
                                    ? const Color(0xFFFFD7CF)
                                    : const Color(0xFFF1E6E2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.022),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: weatherSoftBg(weather),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: _buildWeatherIcon(weather, size: 21),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (today) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFEEE8),
                                                borderRadius:
                                                BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                '오늘',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFFF8E7C),
                                                  height: 1,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            day,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF2F2A27),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        date.isEmpty ? weather : '$date · $weather',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF7E746E),
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: weatherAccent(weather),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
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

  Widget _buildPreviewSheetHandle() {
    return Center(
      child: Container(
        width: 54,
        height: 6,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFD6CD),
              Color(0xFFFFB3A3),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
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

  Widget _buildPreviewUnifiedSheet({required Widget child}) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.98),
              const Color(0xFFFFFBFA),
            ],
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
            BoxShadow(
              color: const Color(0xFFFF8E7C).withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: child,
            ),
          ),
        ),
      ),
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
                  final fittedFontSize = _fitSingleLineFontSize(
                    text: text,
                    baseStyle: todoTextStyle,
                    maxWidth: constraints.maxWidth,
                    minFontSize: 9.8,
                  );

                  final fittedStyle = todoTextStyle.copyWith(
                    fontSize: fittedFontSize,
                    color: isDone
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF111827),
                  );

                  final visibleWidth = _measureTodoTextWidth(
                    text: text,
                    style: fittedStyle,
                    maxWidth: constraints.maxWidth,
                  );

                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        strutStyle: StrutStyle(
                          forceStrutHeight: true,
                          height: 1.15,
                          fontSize: fittedFontSize,
                        ),
                        style: fittedStyle,
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

  double _fitSingleLineFontSize({
    required String text,
    required TextStyle baseStyle,
    required double maxWidth,
    double minFontSize = 9.5,
  }) {
    double low = minFontSize;
    double high = baseStyle.fontSize ?? 14;
    double best = low;

    bool fits(double size) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: baseStyle.copyWith(fontSize: size),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

      return !painter.didExceedMaxLines && painter.width <= maxWidth;
    }

    if (fits(high)) return high;

    for (int i = 0; i < 10; i++) {
      final mid = (low + high) / 2;
      if (fits(mid)) {
        best = mid;
        low = mid;
      } else {
        high = mid;
      }
    }

    return best;
  }

  double _getHomeSectionTopSpacing(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    if (height <= 690) return 12;
    if (height <= 780) return 16;
    if (height <= 900) return 20;
    return 24;
  }

  double _measureTodoTextWidth({
    required String text,
    required TextStyle style,
    required double maxWidth,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    return textPainter.size.width.clamp(0, maxWidth);
  }

  Widget _buildMapSection(BuildContext context) {
    final double previewWidth = MediaQuery.of(context).size.width - 32;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        height: previewWidth,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          shadows: _kCommonShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _setInitialPreviewTransform(constraints);

              return Stack(
                children: [
                  Positioned.fill(
                    child: Listener(
                      onPointerDown: (_) {
                        _mapPreviewPointerCount++;
                        if (!_isPointerDownOnMapPreview) {
                          _setMapPreviewPointerDown(true);
                        }
                      },
                      onPointerUp: (_) {
                        _mapPreviewPointerCount =
                            (_mapPreviewPointerCount - 1).clamp(0, 999);
                        if (_mapPreviewPointerCount == 0) {
                          _setMapPreviewPointerDown(false);
                        }
                      },
                      child: InteractiveViewer(
                        transformationController: _previewTransformController,
                        minScale: _previewMinScale,
                        maxScale: _previewMaxScale,
                        constrained: false,
                        panEnabled: true,
                        scaleEnabled: true,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/map_background.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                              _buildPreviewPlaceLabels(constraints.maxWidth),
                              if (_isMapPreviewLoading)
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFFF8E7C),
                                  ),
                                )
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

                  // ✅ 지도 열기 버튼 복구
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _openMap,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.90),
                              const Color(0xFFFFF6F3).withOpacity(0.95),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFFE4DE),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: const Color(0xFFFF8E7C).withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          color: Color(0xFFFF8E7C),
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  // 하단 프리뷰 필터바
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: GestureDetector(
                      onTap: _showPreviewFilterPopup,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.90),
                              const Color(0xFFFFF6F3).withOpacity(0.95),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFFFE4DE),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.045),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                            BoxShadow(
                              color: const Color(0xFFFF8E7C).withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _buildPreviewCaption(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3EF),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFFFE5DE),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                size: 14,
                                color: Color(0xFFFF8E7C),
                              ),
                            ),
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

    const double markerSize = 24;
    final double visualScale = (1 / currentScale).clamp(0.5, 1.0);

    return Positioned(
      left: (point.x * width) - (markerSize / 2),
      top: (point.y * height) - (markerSize / 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showPreviewSpawnPointDetail(point),
        child: Transform.scale(
          scale: visualScale,
          alignment: Alignment.center,
          child: _buildPreviewSpawnPin(point),
        ),
      ),
    );
  }

  Widget _buildPreviewSpawnPointBottomSheetIcon(SpawnPointModel point) {
    if (point.isBothVerified) {
      return Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 28,
            color: Color(0xFFFF8E7C),
          ),
          Positioned(
            left: 2,
            bottom: 2,
            child: Image.asset(
              'assets/images/resources/oak.png',
              width: 16,
              height: 16,
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: Image.asset(
              'assets/images/resources/fluorite.png',
              width: 16,
              height: 16,
            ),
          ),
        ],
      );
    }

    if (point.isOakVerified && point.oak != null) {
      return Image.asset(point.oak!.iconPath, width: 28, height: 28);
    }

    if (point.isFluoriteVerified && point.fluorite != null) {
      return Image.asset(point.fluorite!.iconPath, width: 28, height: 28);
    }

    if (point.isOakOnly) {
      return Image.asset(
        'assets/images/resources/oak.png',
        width: 24,
        height: 24,
        color: const Color(0xFFFFC7BE),
        colorBlendMode: BlendMode.modulate,
      );
    }

    return const Icon(
      Icons.location_on_rounded,
      size: 28,
      color: Color(0xFFFFC7BE),
    );
  }

  void _showPreviewSpawnPointDetail(SpawnPointModel point) {
    final oak = point.oak;
    final fluorite = point.fluorite;

    Widget buildVoteCard(SpawnResourceModel res) {
      final bool canVote = !res.isVerified && !res.alreadyVotedSameType;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color(0xFFFFFAF8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFE7E1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8E7C).withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFFFDED6),
                ),
              ),
              child: Image.asset(
                res.iconPath,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) =>
                const Icon(Icons.help_outline_rounded, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    res.koName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    res.isVerified
                        ? '오늘 위치가 확정되었어요'
                        : res.alreadyVotedSameType
                        ? '이미 같은 종류에 투표했어요'
                        : '현재 ${res.voteCount}표 모였어요',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7A8A9A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: canVote ? () => _handlePreviewSpawnVote(res) : null,
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: canVote
                        ? const Color(0xFFFF8E7C)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: canVote
                        ? [
                      BoxShadow(
                        color: const Color(0xFFFF8E7C).withOpacity(0.24),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                        : null,
                  ),
                  child: Text(
                    res.isVerified
                        ? '확정'
                        : res.alreadyVotedSameType
                        ? '완료'
                        : '투표',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: canVote
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildPreviewUnifiedSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreviewSheetHandle(),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFFFE1D9),
                    ),
                  ),
                  child: _buildPreviewSpawnPointBottomSheetIcon(point),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.isOakOnly ? '참나무 후보 위치' : '참나무/형광석 후보 위치',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        point.isBothVerified
                            ? '오늘 위치가 모두 확정되었어요.'
                            : '게임에서 확인한 위치에 투표해 주세요.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A8A9A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (oak != null) buildVoteCard(oak),
            if (fluorite != null) buildVoteCard(fluorite),
            if (oak == null && fluorite == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE7EDF5)),
                ),
                child: const Text(
                  '표시할 후보 자원이 없어요.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePreviewCircleMarker({
    required String iconPath,
    required Color borderColor,
    bool isSelected = false,
    double size = 24,
    BoxFit fit = BoxFit.cover,
    EdgeInsets padding = const EdgeInsets.all(2),
  }) {
    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: isSelected ? 2.6 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isSelected ? 0.20 : 0.14),
            blurRadius: isSelected ? 10 : 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: Colors.white,
          child: Image.asset(
            iconPath,
            fit: fit,
            errorBuilder: (c, e, s) => const Icon(
              Icons.image_not_supported_outlined,
              size: 14,
              color: Colors.grey,
            ),
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
            child: _buildPreviewPin(res),
        ),
      ),
    );
  }

  Widget _buildPreviewPin(ResourceModel res) {
    final bool isNpc = res.category == 'npc';
    final bool isAnimal = res.category == 'animal';

    final Color borderColor = isAnimal
        ? const Color(0xFF38BDF8)
        : isNpc
        ? const Color(0xFF3B82F6)
        : const Color(0xFFFF8E7C);

    return _buildHomePreviewCircleMarker(
      iconPath: res.iconPath,
      borderColor: borderColor,
      size: 24,
      fit: BoxFit.cover,
      padding: const EdgeInsets.all(2),
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
                    bottom: 12,
                    right: 28,
                    child: GestureDetector(
                      onTap: () => widget.openEventScreen?.call(),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 16,
                              child: Center(
                                child: Transform.translate(
                                  offset: const Offset(0, 0.8),
                                  child: const Icon(
                                    Icons.grid_view_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 6),

                            const SizedBox(
                              height: 16,
                              child: Center(
                                child: Text(
                                  '전체보기',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 6),

                            const SizedBox(
                              height: 16,
                              child: Center(
                                child: Text(
                                  '|',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 6),

                            SizedBox(
                              height: 16,
                              child: Center(
                                child: Text(
                                  '${_currentEventIndex + 1}/${events.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
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

  Widget _buildIntegratedSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF1DED8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
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
          color: Color(0xFF2D3436),
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
              color: Color(0xFFE58F7C),
            ),
          ),
          hintText: '찾는 아이템을 검색해보세요.',
          hintStyle: const TextStyle(
            color: Color(0xFF9AA4B2),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          contentPadding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Color(0xFFB0B8C4),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
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
              children: [
                Padding(
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
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

class HomeScreen extends StatefulWidget {
  final VoidCallback? openDrawer;
  final VoidCallback? openEndDrawer;
  final List<Map<String, dynamic>> todoList;
  final Function(int)? onTodoToggle;
  final VoidCallback? onResetAll;
  final Future<void> Function()? onRefresh;
  final void Function(GlobalSearchItem item)? onSearchItemSelected;

  const HomeScreen({
    super.key,
    this.openDrawer,
    this.openEndDrawer,
    this.todoList = const [],
    this.onTodoToggle,
    this.onResetAll,
    this.onRefresh,
    this.onSearchItemSelected,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _sixAMTimer;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didSetPreviewInitialTransform) return;

      final double scale = _previewInitialScale;
      final double contentWidth = constraints.maxWidth * scale;
      final double contentHeight = constraints.maxHeight * scale;

      final double tx = (constraints.maxWidth - contentWidth) / 2;
      final double ty = (constraints.maxHeight - contentHeight) / 2;

      _previewTransformController.value = Matrix4.identity()
        ..translate(tx, ty)
        ..scale(scale);

      _didSetPreviewInitialTransform = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _previewTransformController.addListener(_onPreviewTransformChanged);
    _checkAndResetAtStart();
    _scheduleSixAMTimer();
    _initializePreview();
    _loadGlobalSearchItems();
    _searchController.addListener(_handleSearchChanged);
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

  Future<void> _initializePreview() async {
    await _loadVoterId();
    await _loadMapPreviewResources();
  }

  @override
  void dispose() {
    _sixAMTimer?.cancel();
    _previewTransformController.removeListener(_onPreviewTransformChanged);
    _previewTransformController.dispose();
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
    } catch (e) {
      debugPrint('유저 정보 불러오기 실패: $e');
    }
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
                                final defaults = <String>{};

                                for (final res in _allPreviewCandidates) {
                                  final key = _normalizePreviewFilterKey(res);

                                  if (key == 'roaming_oak' ||
                                      key == 'fluorite' ||
                                      key == 'black_truffle') {
                                    defaults.add(key);
                                  }
                                }

                                _applyPreviewFilter(
                                  resources: defaults,
                                  showNpcs: false,
                                  showAnimals: false,
                                );
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(
                                  color: Color(0xFFD7DEE7),
                                ),
                                minimumSize: const Size.fromHeight(48),
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
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg_gradient.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(context),
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFFF8E7C),
                backgroundColor: Colors.white,
                onRefresh: () async {
                  if (widget.onRefresh != null) {
                    await widget.onRefresh!();
                  }
                  await _loadMapPreviewResources();
                },
                child: SingleChildScrollView(
                  physics: _shouldLockHomeScroll
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildSectionTitle('날씨 정보'),
                      const SizedBox(height: 8),
                      _buildWeatherCard(),
                      const SizedBox(height: 24),
                      _buildTodoSection(),
                      const SizedBox(height: 24),
                      _buildMapSection(context),
                      const SizedBox(height: 24),
                      _buildEventSection(context),
                      const SizedBox(height: 70),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      width: double.infinity,
      height: 128,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        shadows: _kCommonShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildWeatherTimeline(),
                  ),
                  const Center(
                    child: Text(
                      '현재 날씨에는 특별한 이벤트가 없습니다.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            _buildWeeklyColumn(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherTimeline() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildTimeItem('현재 (아침)', true),
          _buildTimeItem('낮', false),
          _buildTimeItem('밤', false),
          _buildTimeItem('내일 새벽', false),
          _buildTimeItem('내일 아침', false),
        ],
      ),
    );
  }

  Widget _buildTimeItem(String label, bool isCurrent) {
    return Container(
      width: 54,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent
                  ? const Color(0xFF111827)
                  : const Color(0xFF64748B),
              fontFamily: 'SF Pro',
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFFFFF4F1)
                  : const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(
                color: isCurrent
                    ? const Color(0xFFFFD4CC)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Icon(
              Icons.wb_sunny_rounded,
              size: 17,
              color: isCurrent
                  ? const Color(0xFFFF8E7C)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyColumn() {
    final days = [
      {'day': '수 (내일)', 'icon': true},
      {'day': '목', 'icon': true},
      {'day': '금', 'icon': true},
      {'day': '토', 'icon': true},
      {'day': '일', 'icon': false},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days
          .map(
            (data) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data['day'] as String,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF475569),
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: (data['icon'] as bool)
                    ? const Color(0xFFCBD5E1)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      )
          .toList(),
    );
  }

  Widget _buildTodoSection() {
    const int displayLimit = 6;
    final int displayCount =
    widget.todoList.length > displayLimit ? displayLimit : widget.todoList.length;

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
                                padding: const EdgeInsets.only(top: 4, bottom: 2),
                                child: Text(
                                  "+ ${widget.todoList.length - displayLimit}개 더보기",
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

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isPressed ? const Color(0xFFF8FAFC) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
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
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.0,
                          fontWeight: FontWeight.w500,
                          color: isDone
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF111827),
                        ),
                      ),
                      if (isDone)
                        Positioned(
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 1.1,
                            color: const Color(0xFF94A3B8).withOpacity(0.7),
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
    );
  }

  Widget _buildMapSection(BuildContext context) {
    final double previewWidth = MediaQuery
        .of(context)
        .size
        .width - 32;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('지도'),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            height: previewWidth,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              shadows: _kCommonShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _setInitialPreviewTransform(constraints);

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (_) {
                            _mapPreviewPointerCount++;

                            if (!_isPointerDownOnMapPreview) {
                              _setMapPreviewPointerDown(true);
                            } else {
                              setState(() {});
                            }
                          },
                          onPointerUp: (_) {
                            _mapPreviewPointerCount =
                                (_mapPreviewPointerCount - 1).clamp(0, 999);

                            if (_mapPreviewPointerCount == 0) {
                              _setMapPreviewPointerDown(false);
                            } else {
                              setState(() {});
                            }
                          },
                          onPointerCancel: (_) {
                            _mapPreviewPointerCount =
                                (_mapPreviewPointerCount - 1).clamp(0, 999);

                            if (_mapPreviewPointerCount == 0) {
                              _setMapPreviewPointerDown(false);
                            } else {
                              setState(() {});
                            }
                          },
                          child: InteractiveViewer(
                            transformationController: _previewTransformController,
                            minScale: _previewMinScale,
                            maxScale: _previewMaxScale,
                            boundaryMargin: EdgeInsets.zero,
                            clipBehavior: Clip.hardEdge,
                            constrained: false,
                            panEnabled: true,
                            scaleEnabled: true,
                            interactionEndFrictionCoefficient: 0.0000135,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: Image.asset(
                                      'assets/images/map_background.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) =>
                                          Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.map_outlined,
                                              color: Colors.grey,
                                            ),
                                          ),
                                    ),
                                  ),
                                  _buildPreviewPlaceLabels(
                                    constraints.maxWidth,
                                  ),
                                  if (_isMapPreviewLoading)
                                    const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Color(0xFFFF8E7C),
                                        ),
                                      ),
                                    )
                                  else
                                    ..._mapPreviewResources.map(
                                          (res) =>
                                          _buildHomeMapPreviewMarker(
                                            res,
                                            constraints.maxWidth,
                                            constraints.maxHeight,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: GestureDetector(
                          onTap: () => _openMap(),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.94),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.open_in_full_rounded,
                              color: Color(0xFF334155),
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) {
                            setState(() {
                              _isPreviewFilterBarPressed = true;
                            });
                          },
                          onTapCancel: () {
                            setState(() {
                              _isPreviewFilterBarPressed = false;
                            });
                          },
                          onTapUp: (_) async {
                            await Future.delayed(const Duration(milliseconds: 70));
                            if (!mounted) return;

                            setState(() {
                              _isPreviewFilterBarPressed = false;
                            });

                            await Future.delayed(const Duration(milliseconds: 20));
                            if (!mounted) return;

                            _showPreviewFilterPopup();
                          },
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFEAECEF),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x10000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _buildPreviewCaption(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF0F172A),
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(
                                      Icons.tune_rounded,
                                      size: 18,
                                      color: Color(0xFFFF8E7C),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 80),
                                    opacity: _isPreviewFilterBarPressed ? 1.0 : 0.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF334155).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(14),
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
                },
              ),
            ),
          ),
        ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('진행중인 이벤트'),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              shadows: _kCommonShadow,
            ),
            child: GridView.count(
              crossAxisCount: 3, // 👉 항상 3개
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1, // 정사각형
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildEventCard(
                  context,
                  0,
                  'https://scontent-icn2-1.xx.fbcdn.net/v/t39.30808-6/653560105_122127351237021391_2534542623193999458_n.jpg?_nc_cat=110&ccb=1-7&_nc_sid=13d280&_nc_ohc=GJ6gMkapj0EQ7kNvwGe2VZj&_nc_oc=AdoiTg1t670K8-kTotsOj-LbC134Aq6plrE5HNZuqP7TmI07StiCU9mt_MJCAlh2YlE&_nc_zt=23&_nc_ht=scontent-icn2-1.xx&_nc_gid=cd7roSdfW4Yhunct6S5Ghg&_nc_ss=7a32e&oh=00_AfwXPj2QZt7wKp-poD2VpNQkENY9kC40PFj5WJa_DwUSZA&oe=69CE102B',
                  'https://www.facebook.com/HeartopiaKR/photos/122127351225021391/',
                  isNetworkImage: true,
                ),
                _buildEventCard(
                  context,
                  1,
                  'assets/images/event_2.png',
                  'https://www.leagueoflegends.com',
                ),
                _buildEventCard(
                  context,
                  2,
                  'assets/images/event_3.png',
                  'https://github.com',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(
      BuildContext context,
      int index,
      String path,
      String url, {
        bool isNetworkImage = false,
      }) {
    final bool isPressed = _pressedEventIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() {
          _pressedEventIndex = index;
        });
      },
      onTapCancel: () {
        setState(() {
          if (_pressedEventIndex == index) {
            _pressedEventIndex = null;
          }
        });
      },
      onTapUp: (_) async {
        await Future.delayed(const Duration(milliseconds: 80));

        if (!mounted) return;

        setState(() {
          if (_pressedEventIndex == index) {
            _pressedEventIndex = null;
          }
        });

        await Future.delayed(const Duration(milliseconds: 20));

        if (!mounted) return;

        final Uri uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          debugPrint('Could not launch $url');
        }
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: isPressed ? 0.985 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFF1F5F9),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                isNetworkImage
                    ? Image.network(
                  path,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: const Color(0xFFF8FAFC),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ),
                )
                    : Image.asset(
                  path,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: const Color(0xFFF8FAFC),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_outlined,
                      color: Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ),
                ),

                IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 90),
                    opacity: isPressed ? 1.0 : 0.0,
                    child: Container(
                      color: const Color(0xFF334155).withOpacity(0.08),
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

  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: widget.openDrawer,
            icon: SvgPicture.asset(
              'assets/icons/ic_menu.svg',
              width: 24,
              height: 24,
            ),
          ),
          const Text(
            "Keeper's Note",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'SF Pro',
            ),
          ),
          IconButton(
            onPressed: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                ),
            icon: SvgPicture.asset(
              'assets/icons/ic_settings.svg',
              width: 24,
              height: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 40,
            decoration: ShapeDecoration(
              color: const Color(0xFFFFFDFD),
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: Color(0x30FF7A65)),
                borderRadius: BorderRadius.circular(36),
              ),
              shadows: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: SvgPicture.asset(
                    'assets/icons/ic_search.svg',
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF898989),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                hintText: '아이템을 검색해보세요.',
                hintStyle: const TextStyle(
                  color: Color(0xFF898989),
                  fontSize: 14,
                  fontFamily: 'SF Pro',
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchSuggestions = []);
                  },
                )
                    : null,
              ),
            ),
          ),
        ),

        if (_searchSuggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _kCommonShadow,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: _searchSuggestions.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1F5F9),
                  ),
                  itemBuilder: (context, index) {
                    final item = _searchSuggestions[index];

                    return InkWell(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchSuggestions = []);

                        widget.onSearchItemSelected?.call(item);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                item.iconPath,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                const Icon(Icons.inventory_2_outlined),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
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
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8E7C),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:ui';
import 'setting_screen.dart';
import 'models/global_search_item.dart';
import 'package:auto_size_text/auto_size_text.dart';

class AchievementItem {
  final String id;
  final String title;
  final String image;
  final String condition;
  final String unlockedTitle;
  final bool isHidden;

  AchievementItem({
    required this.id,
    required this.title,
    required this.image,
    required this.condition,
    required this.unlockedTitle,
    required this.isHidden,
  });

  factory AchievementItem.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
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
          if (lower == 'true' || lower == 'y' || lower == 'yes' || lower == '1') {
            return true;
          }
          if (lower == 'false' || lower == 'n' || lower == 'no' || lower == '0') {
            return false;
          }
        }
      }
      return fallback;
    }

    return AchievementItem(
      id: readString(['id'], fallback: UniqueKey().toString()),
      title: readString(['name_ko', 'nameKo', 'name', 'title'], fallback: '이름 없음'),
      image: readString(['image', 'imageUrl', 'icon']),
      condition: readString(
        ['condition', 'achievementCondition', 'description', 'unlockCondition'],
        fallback: '',
      ),
      unlockedTitle: readString(
        ['unlocked_title', 'unlockedTitle', 'titleReward', 'rewardTitle'],
        fallback: '',
      ),
      isHidden: readBool(['is_hidden', 'isHidden', 'hidden'], fallback: false),
    );
  }
}

class EncyclopediaScreen extends StatefulWidget {
  final VoidCallback? openDrawer;
  final GlobalSearchItem? initialSearchItem;

  const EncyclopediaScreen({
    super.key,
    this.openDrawer,
    this.initialSearchItem,
  });

  @override
  State<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends State<EncyclopediaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _selectedFilter = '주방 가구';
  String _searchQuery = '';
  GlobalSearchItem? _pendingSearchItem;

  final ScrollController _achievementScrollController = ScrollController();
  final ScrollController _furnitureScrollController = ScrollController();
  final ScrollController _outfitScrollController = ScrollController();

  bool _showTopBtn = false;
  bool _isFilterVisible = true;
  bool _isRefreshing = false;

  final Color snackAccent = const Color(0xFFFF8E7C);

  static const String _baseUrl = 'https://api.keepers-note.o-r.kr';
  static const String _achievementEndpoint = '$_baseUrl/api/achievements';

  bool _isAchievementLoading = false;
  String? _achievementError;
  List<AchievementItem> _achievementItems = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!mounted) return;
      _dismissSearchFocus();
      _syncFilterForCurrentTab();
      setState(() {});
    });

    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });

    _attachScrollListener(_achievementScrollController);
    _attachScrollListener(_furnitureScrollController);
    _attachScrollListener(_outfitScrollController);

    _fetchAchievements();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFilterForCurrentTab();
      if (widget.initialSearchItem != null) {
        _applySearchItem(widget.initialSearchItem!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant EncyclopediaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialSearchItem != null &&
        widget.initialSearchItem != oldWidget.initialSearchItem) {
      _pendingSearchItem = widget.initialSearchItem;
      _applySearchItem(widget.initialSearchItem!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _achievementScrollController.dispose();
    _furnitureScrollController.dispose();
    _outfitScrollController.dispose();
    super.dispose();
  }

  void _attachScrollListener(ScrollController controller) {
    double lastOffset = 0;

    controller.addListener(() {
      if (!mounted || !controller.hasClients) return;

      final double offset = controller.offset;
      final bool showBtn = offset > 100;

      if (showBtn != _showTopBtn) {
        setState(() => _showTopBtn = showBtn);
      }

      if (_isAchievementTab) {
        lastOffset = offset;
        return;
      }

      if (offset <= 8) {
        if (!_isFilterVisible) {
          setState(() => _isFilterVisible = true);
        }
        lastOffset = offset;
        return;
      }

      final double delta = offset - lastOffset;

      if (delta > 4 && _isFilterVisible) {
        setState(() => _isFilterVisible = false);
      } else if (delta < -4 && !_isFilterVisible) {
        setState(() => _isFilterVisible = true);
      }

      lastOffset = offset;
    });
  }

  Future<void> _fetchAchievements({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _isAchievementLoading = true;
        _achievementError = null;
      });
    } else {
      setState(() {
        _achievementError = null;
      });
    }

    try {
      final response = await http.get(Uri.parse(_achievementEndpoint));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('업적 API 호출 실패 (${response.statusCode})');
      }

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      List<dynamic> rawList = [];

      if (decoded is List) {
        rawList = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final dynamic candidates =
            decoded['data'] ??
                decoded['items'] ??
                decoded['content'] ??
                decoded['achievements'] ??
                decoded['result'];

        if (candidates is List) {
          rawList = candidates;
        }
      }

      final parsed = rawList
          .whereType<Map>()
          .map((e) => AchievementItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted) return;

      setState(() {
        _achievementItems = parsed;
        _isAchievementLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _achievementError = e.toString();
        _isAchievementLoading = false;
      });
    }
  }

  ScrollController _getCurrentController() {
    final index = _tabController.index.clamp(0, 2);
    if (index == 0) return _achievementScrollController;
    if (index == 1) return _furnitureScrollController;
    return _outfitScrollController;
  }

  String _getCurrentTabType() {
    final index = _tabController.index.clamp(0, 2);
    if (index == 0) return '업적';
    if (index == 1) return '가구';
    return '옷';
  }

  List<String> _getCurrentFilterList() {
    if (_tabController.index == 1) {
      return ['주방 가구', '침실 가구', '거실 가구', '야외 장식', '테마 가구'];
    }
    return ['몰린 옷가게', '금토리 전시회', '축제 패키지', '한정 상품', '이벤트 아이템'];
  }

  void _dismissSearchFocus() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _syncFilterForCurrentTab() {
    if (_tabController.index == 0) return;

    final filters = _getCurrentFilterList();
    if (filters.isEmpty) return;

    if (!filters.contains(_selectedFilter)) {
      _selectedFilter = filters.first;
    }
  }

  bool get _isAchievementTab => _tabController.index == 0;

  String _resolveAchievementImagePath(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return '';

    final raw = imagePath.trim();
    if (raw.startsWith('assets/')) return raw;
    return 'assets/$raw';
  }

  Widget _buildAchievementImage({
    required String title,
    required String? imagePath,
    bool isHidden = false,
    double padding = 6,
    double iconSize = 24,
    BoxFit fit = BoxFit.contain,
  }) {
    final resolvedPath = _resolveAchievementImagePath(imagePath);

    if (resolvedPath.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.all(padding),
        child: Image.asset(
          resolvedPath,
          fit: fit,
          errorBuilder: (_, __, ___) => isHidden
              ? Center(
            child: Text(
              '🌟',
              style: TextStyle(fontSize: iconSize),
            ),
          )
              : Icon(
            Icons.emoji_events_outlined,
            size: iconSize,
            color: const Color(0xFFFF8E7C),
          ),
        ),
      );
    }

    if (isHidden) {
      return Center(
        child: Text(
          '🌟',
          style: TextStyle(fontSize: iconSize),
        ),
      );
    }

    return Center(
      child: Icon(
        Icons.emoji_events_outlined,
        size: iconSize,
        color: const Color(0xFFFF8E7C),
      ),
    );
  }

  List<AchievementItem> _getFilteredAchievements() {
    return _achievementItems.where((item) {
      final query = _searchQuery.toLowerCase();
      return query.isEmpty || item.title.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    final bool showFilterInAppBar = !_isAchievementTab && _isFilterVisible;
    final double appBarHeight = topPadding +
        (_isAchievementTab
            ? 190
            : showFilterInAppBar
            ? 214
            : 170);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissSearchFocus,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/bg_gradient.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: appBarHeight - 22),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildAchievementContent(),
                        _buildFurnitureContent(),
                        _buildOutfitContent(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildIntegratedAppBar(context, topPadding),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 24 : 140,
              child: _buildScrollToTopButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return AnimatedScale(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      scale: _showTopBtn ? 1.0 : 0.0,
      child: GestureDetector(
        onTap: () => _getCurrentController().animateTo(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutQuart,
        ),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withOpacity(0.05),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.keyboard_arrow_up_rounded,
            color: Color(0xFF64748B),
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildIntegratedAppBar(BuildContext context, double topPadding) {
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
                  padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _buildBackButton(),

                          const Spacer(),

                          _buildAppTitle(),

                          const Spacer(),

                          const SizedBox(width: 40),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildTabBar(),
                      const SizedBox(height: 8),
                      _buildIntegratedSearchBar(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeOutCubic,
                        child: (!_isAchievementTab && _isFilterVisible)
                            ? Padding(
                          key: const ValueKey('filter_visible'),
                          padding: const EdgeInsets.only(top: 10),
                          child: _buildFilterAndSortHeader(
                            _getCurrentTabType(),
                          ),
                        )
                            : const SizedBox(
                          key: ValueKey('filter_hidden'),
                          height: 0,
                        ),
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
          width: 40,
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
            width: 17,
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

  Widget _buildAppTitle() {
    return const Text(
      '도감',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2D3436),
        letterSpacing: -0.2,
      ),
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
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2D3436),
        ),
        decoration: InputDecoration(
          hintText: _isAchievementTab ? '업적을 검색해보세요.' : '아이템을 검색해보세요.',
          hintStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9AA4B2),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFFE58F7C),
            size: 24,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            splashRadius: 18,
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFFB0B8C4),
              size: 20,
            ),
            onPressed: () {
              _searchController.clear();
              _dismissSearchFocus();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 13,
          ),
        ),
        onTapOutside: (_) => _dismissSearchFocus(),
      ),
    );
  }

  Widget _buildAchievementContent() {
    final items = _getFilteredAchievements();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        final bool isTablet = width >= 700;
        final int crossAxisCount = isTablet ? 5 : 3;

        return RefreshIndicator(
          key: const PageStorageKey('achievement_tab'),
          onRefresh: () => _fetchAchievements(showLoading: false),
          color: snackAccent,
          child: _isAchievementLoading && _achievementItems.isEmpty
              ? ListView(
            controller: _achievementScrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 180),
            children: const [
              Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF8E7C),
                ),
              ),
            ],
          )
              : _achievementError != null && _achievementItems.isEmpty
              ? ListView(
            controller: _achievementScrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 180),
            children: [
              _buildAchievementErrorCard(),
            ],
          )
              : items.isEmpty
              ? ListView(
            controller: _achievementScrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 180),
            children: [
              _buildAchievementEmptyCard(),
            ],
          )
              : GridView.builder(
            controller: _achievementScrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 180),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: isTablet ? 14 : 10,
              mainAxisSpacing: isTablet ? 14 : 12,
              mainAxisExtent: isTablet ? 210 : 200,
            ),
            itemBuilder: (context, index) {
              return _buildAchievementCard(items[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildAchievementCard(AchievementItem item) {
    return _AchievementPressableCard(
      item: item,
      baseUrl: _baseUrl,
      onDismissSearchFocus: _dismissSearchFocus,
      imageBuilder: ({
        required String title,
        required String? imagePath,
        double padding = 6,
        double iconSize = 24,
        BoxFit fit = BoxFit.contain,
      }) {
        return _buildAchievementImage(
          title: title,
          imagePath: imagePath,
          isHidden: item.isHidden,
          padding: padding,
          iconSize: iconSize,
          fit: fit,
        );
      },
    );
  }

  Widget _buildAchievementErrorCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.18),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 34,
            color: Color(0xFFFF8E7C),
          ),
          const SizedBox(height: 10),
          const Text(
            '업적 목록을 불러오지 못했어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _achievementError ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _fetchAchievements,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8E7C),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '다시 불러오기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Material(
      color: const Color(0xFFFFF3F0),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFE2DB),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFFFF8E7C),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementEmptyCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.14),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 34,
            color: Color(0xFFFF8E7C),
          ),
          SizedBox(height: 10),
          Text(
            '표시할 업적이 없어요',
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

  Widget _buildFurnitureContent() {
    return _buildSequentialUpdateContent(
      controller: _furnitureScrollController,
      title: '가구 도감',
      subtitle: '콘텐츠는 순차적으로 업데이트될 예정이에요.',
      emoji: '🪑',
      description:
      '가구 도감은 정보가 더 모이면 데이트 예정이에요.',
      onRefresh: () async {
        setState(() => _isRefreshing = true);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) {
          setState(() => _isRefreshing = false);
        }
      },
    );
  }

  Widget _buildOutfitContent() {
    return _buildSequentialUpdateContent(
      controller: _outfitScrollController,
      title: '옷 도감',
      subtitle: '콘텐츠는 순차적으로 업데이트될 예정이에요.',
      emoji: '👗',
      description:
      '옷 도감은 정보가 더 모이면 업데이트 예정이에요.',
      onRefresh: () async {
        setState(() => _isRefreshing = true);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) {
          setState(() => _isRefreshing = false);
        }
      },
    );
  }

  Widget _buildSequentialUpdateContent({
    required ScrollController controller,
    required String title,
    required String subtitle,
    required String emoji,
    required String description,
    required Future<void> Function() onRefresh,
  }) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;

        _dismissSearchFocus();

        final double delta = notification.scrollDelta ?? 0;

        if (notification.metrics.pixels <= 8) {
          if (!_isFilterVisible) {
            setState(() => _isFilterVisible = true);
          }
          return false;
        }

        if (delta > 2 && _isFilterVisible) {
          setState(() => _isFilterVisible = false);
        } else if (delta < -2 && !_isFilterVisible) {
          setState(() => _isFilterVisible = true);
        }

        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: snackAccent,
        child: ListView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 180),
          children: [
            const SizedBox(height: 36),
            _buildSequentialUpdateCard(
              title: title,
              subtitle: subtitle,
              emoji: emoji,
              description: description,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSequentialUpdateCard({
    required String title,
    required String subtitle,
    required String emoji,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.93),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFFFDDD4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4F1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFE2DB),
              ),
            ),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 30),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7B8794),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAF8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFFFE7E0),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 28,
                  color: Color(0xFFFF8E7C),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6E7683),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildInfoPill(
                icon: Icons.update_rounded,
                label: '순차 업데이트 예정',
              ),
              _buildInfoPill(
                icon: Icons.inventory_2_outlined,
                label: '콘텐츠 확장 예정',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonContent({
    required ScrollController controller,
    required String title,
    required String subtitle,
    required String emoji,
    required String previewTitle,
    required List<String> sampleItems,
    required Future<void> Function() onRefresh,
  }) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;

        _dismissSearchFocus();

        final double delta = notification.scrollDelta ?? 0;

        if (notification.metrics.pixels <= 8) {
          if (!_isFilterVisible) {
            setState(() => _isFilterVisible = true);
          }
          return false;
        }

        if (delta > 2 && _isFilterVisible) {
          setState(() => _isFilterVisible = false);
        } else if (delta < -2 && !_isFilterVisible) {
          setState(() => _isFilterVisible = true);
        }

        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: snackAccent,
        child: ListView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 180),
          children: [
            _buildComingSoonHeroCard(
              title: title,
              subtitle: subtitle,
              emoji: emoji,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                previewTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF5C6675),
                ),
              ),
            ),
            ...sampleItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),

                // 👇 첫 번째 아이템만 "진짜 카드"
                child: index == 0 && item.contains('몰린 옷가게')
                    ? _buildSampleRealOutfitCard(item)
                    : _buildSampleSeriesCard(item),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleRealOutfitCard(String title) {
    return Stack(
      children: [
        // 👉 기존 카드 재사용 (여기 핵심)
        _buildSeriesCard(title),

        // 👉 샘플 뱃지 (우상단)
        Positioned(
          top: 10,
          right: 12,
          child: _buildSampleBadge(),
        ),
      ],
    );
  }

  Widget _buildComingSoonHeroCard({
    required String title,
    required String subtitle,
    required String emoji,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD9D1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFE1D9),
                  ),
                ),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7B8794),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoPill(
                icon: Icons.science_rounded,
                label: '샘플 데이터',
              ),
              _buildInfoPill(
                icon: Icons.construction_rounded,
                label: '정식 도감 준비중',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFFE0D9),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFFFF8E7C),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E7683),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSortHeader(String type) {
    final List<String> filterList = _getCurrentFilterList();

    if (!filterList.contains(_selectedFilter) && filterList.isNotEmpty) {
      _selectedFilter = filterList.first;
    }

    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 4, right: 16),
              itemCount: filterList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return _buildFilterChip(filterList[index]);
              },
            ),
          ),
          const SizedBox(width: 10),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                // TODO: 정렬 변경
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 4, right: 4, top: 7, bottom: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '고가순',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSampleSeriesCard(String seriesTitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: ShapeDecoration(
        color: Colors.white.withOpacity(0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: const Color(0xFFFF8E7C).withOpacity(0.12),
            width: 1,
          ),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  seriesTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              _buildSampleBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAF8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFFFE3DC),
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 32,
                  color: Color(0xFFFF8E7C),
                ),
                SizedBox(height: 10),
                Text(
                  '샘플 데이터가 표시되고 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF444B55),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '가구/옷 도감은 준비중이며, 현재 화면은 테스트용 샘플 데이터입니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B8794),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFA08F),
            Color(0xFFFF8E7C),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8E7C).withOpacity(0.20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 14,
            color: Colors.white,
          ),
          SizedBox(width: 5),
          Text(
            'SAMPLE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesCard(String seriesTitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: ShapeDecoration(
        color: Colors.white.withOpacity(0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: const Color(0xFFFF8E7C).withOpacity(0.12),
            width: 1,
          ),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 12),
            child: Text(
              seriesTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
                fontFamily: 'SF Pro',
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildColorCard(
                '분홍',
                'assets/images/woods_pink.png',
                isFavorite: false,
              ),
              _buildColorCard(
                '목가',
                'assets/images/woods_wood.png',
                isFavorite: true,
              ),
              _buildColorCard(
                '보라',
                'assets/images/woods_purple.png',
                isFavorite: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorCard(
      String colorName,
      String imagePath, {
        required bool isFavorite,
      }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: ShapeDecoration(
          color: const Color(0xFFFFFAF8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFFFF8E7C).withOpacity(0.14),
              width: 1,
            ),
          ),
          shadows: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    colorName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF505050),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 24,
                  color: isFavorite
                      ? const Color(0xFFFF8E7C)
                      : const Color(0xFFD9D9D9),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF8E7C).withOpacity(0.10),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) =>
                      const SizedBox(height: 100, child: Icon(Icons.broken_image)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Colors.black.withOpacity(0.08),
              margin: const EdgeInsets.only(bottom: 8),
            ),
            _buildSmallGridRow(),
            const SizedBox(height: 4),
            _buildSmallGridRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallGridRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (index) => Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: ShapeDecoration(
            color: const Color(0xC6FFF8E7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildTabBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF3D8D1),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
        splashBorderRadius: BorderRadius.circular(18),
        indicatorAnimation: TabIndicatorAnimation.elastic,
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.black.withOpacity(0.03);
          }
          return Colors.transparent;
        }),
        indicator: BoxDecoration(
          color: const Color(0xFFFFF1EC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFFDDD4),
            width: 1,
          ),
        ),
        labelColor: const Color(0xFFFF8E7C),
        unselectedLabelColor: const Color(0xFF94A3B8),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          fontFamily: 'SF Pro',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'SF Pro',
        ),
        tabs: const [
          Tab(text: '업적'),
          Tab(text: '가구'),
          Tab(text: '옷'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool isSelected = _selectedFilter == label;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashColor: const Color(0xFFFF8E7C).withOpacity(0.10),
        highlightColor: const Color(0xFFFF8E7C).withOpacity(0.05),
        onTap: () {
          if (_selectedFilter == label) return;
          setState(() {
            _selectedFilter = label;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFF1EC)
                : Colors.white.withOpacity(0.76),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFFDDD4)
                  : const Color(0xFFE9EEF4),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: const Color(0xFFFF8E7C).withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.8,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFFFF8E7C)
                    : const Color(0xFF667085),
                letterSpacing: -0.1,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _applySearchItem(GlobalSearchItem item) {
    _pendingSearchItem = item;
    final title = item.title.toLowerCase();

    if (title.contains('업적')) {
      _tabController.animateTo(0);
    } else if (title.contains('가구')) {
      _tabController.animateTo(1);
    } else if (title.contains('옷') || title.contains('코디')) {
      _tabController.animateTo(2);
    }

    setState(() {
      _searchController.text = item.title;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
      _syncFilterForCurrentTab();
    });
  }
}

class AchievementDetailScreen extends StatefulWidget {
  final AchievementItem achievement;
  final String baseUrl;

  const AchievementDetailScreen({
    super.key,
    required this.achievement,
    required this.baseUrl,
  });

  @override
  State<AchievementDetailScreen> createState() => _AchievementDetailScreenState();
}

class _AchievementDetailScreenState extends State<AchievementDetailScreen> {
  late AchievementItem _detailItem;
  bool _isLoading = true;
  String? _error;

  String _resolveAchievementImagePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('assets/')) return trimmed;
    return 'assets/$trimmed';
  }

  @override
  void initState() {
    super.initState();
    _detailItem = widget.achievement;
    _fetchDetail();
  }



  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/achievements/${widget.achievement.id}'),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));

        if (decoded is Map<String, dynamic>) {
          _detailItem = AchievementItem.fromJson(decoded);
        } else if (decoded is Map) {
          _detailItem =
              AchievementItem.fromJson(Map<String, dynamic>.from(decoded));
        }
      } else {
        _error = '상세 정보를 불러오지 못했어요.';
      }
    } catch (_) {
      _error = '상세 정보를 불러오지 못했어요.';
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildAchievementImage({
    required String? imagePath,
    double iconSize = 48,
  }) {
    final assetPath = _resolveAchievementImagePath(imagePath ?? '');

    if (assetPath.isNotEmpty) {
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.emoji_events_outlined,
          size: iconSize,
          color: const Color(0xFFFF8E7C),
        ),
      );
    }

    return Center(
      child: Icon(
        Icons.emoji_events_outlined,
        size: iconSize,
        color: const Color(0xFFFF8E7C),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFE0D9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF8E7C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3436),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlockedTitle = _detailItem?.unlockedTitle ?? '';
    final imagePath = _resolveAchievementImagePath(_detailItem?.image ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFAF8),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3436)),
        title: const Text(
          '업적 상세',
          style: TextStyle(
            color: Color(0xFF2D3436),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFFE0D9),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFAF8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFFE0D9),
                          ),
                        ),
                        child: _buildAchievementImage(
                          imagePath: imagePath,
                          iconSize: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _detailItem.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _detailItem.isHidden
                            ? const Color(0xFF5B3AAE)
                            : const Color(0xFF2D3436),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _detailItem.isHidden
                            ? const Color(0xFFF4EEFF)
                            : const Color(0xFFFFF3F0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _detailItem.isHidden
                              ? const Color(0xFFD8C7FF)
                              : const Color(0xFFFFDDD4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            size: 16,
                            color: _detailItem.isHidden
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFFFF8E7C),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              unlockedTitle.isNotEmpty
                                  ? '칭호 · $unlockedTitle'
                                  : '칭호 정보 없음',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: _detailItem.isHidden
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0xFFE67E6B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildInfoCard(
                title: '달성 조건',
                value: _detailItem.condition.isNotEmpty
                    ? _detailItem.condition
                    : '아직 달성 조건 정보가 없어요.',
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                title: '히든 업적 여부',
                value: _detailItem.isHidden ? '히든 업적' : '일반 업적',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
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

class _AchievementPressableCard extends StatefulWidget {
  final AchievementItem item;
  final String baseUrl;
  final VoidCallback onDismissSearchFocus;
  final Widget Function({
  required String title,
  required String? imagePath,
  double padding,
  double iconSize,
  BoxFit fit,
  }) imageBuilder;

  const _AchievementPressableCard({
    required this.item,
    required this.baseUrl,
    required this.onDismissSearchFocus,
    required this.imageBuilder,
  });

  @override
  State<_AchievementPressableCard> createState() =>
      _AchievementPressableCardState();
}

class _AchievementPressableCardState extends State<_AchievementPressableCard> {
  bool _isPressed = false;
  String _cardUnlockedTitle = '';
  bool _isTitleLoading = false;

  @override
  void initState() {
    super.initState();
    _cardUnlockedTitle = widget.item.unlockedTitle.trim();
    if (_cardUnlockedTitle.isEmpty) {
      _fetchCardDetailTitle();
    }
  }

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  Future<void> _fetchCardDetailTitle() async {
    if (_isTitleLoading) return;
    _isTitleLoading = true;

    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/achievements/${widget.item.id}'),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));

        AchievementItem? detail;
        if (decoded is Map<String, dynamic>) {
          detail = AchievementItem.fromJson(decoded);
        } else if (decoded is Map) {
          detail = AchievementItem.fromJson(Map<String, dynamic>.from(decoded));
        }

        if (!mounted || detail == null) return;

        setState(() {
          _cardUnlockedTitle = (detail?.unlockedTitle ?? '').trim();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isTitleLoading = false);
      }
    }
  }

  Future<void> _handleTap() async {
    widget.onDismissSearchFocus();
    await Future.delayed(const Duration(milliseconds: 25));
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AchievementDetailScreen(
          achievement: AchievementItem(
            id: widget.item.id,
            title: widget.item.title,
            image: widget.item.image,
            condition: widget.item.condition,
            unlockedTitle: _cardUnlockedTitle,
            isHidden: widget.item.isHidden,
          ),
          baseUrl: widget.baseUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final bool isHidden = item.isHidden;
    final bool hasUnlockedTitle = _cardUnlockedTitle.trim().isNotEmpty;

    final Color hiddenAccent = const Color(0xFF8B5CF6);
    final Color hiddenBg = const Color(0xFFF4EEFF);
    final Color normalAccent = const Color(0xFFFF8E7C);
    final Color normalBg = const Color(0xFFFFF3F0);

    final Color accent = isHidden ? hiddenAccent : normalAccent;
    final Color chipBg = isHidden ? hiddenBg : normalBg;

    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      scale: _isPressed ? 0.972 : 1.0,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isHidden
                  ? hiddenAccent.withOpacity(0.30)
                  : const Color(0xFFFFE0D9),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? accent.withOpacity(0.14)
                    : Colors.black.withOpacity(0.05),
                blurRadius: _isPressed ? 16 : 12,
                offset: Offset(0, _isPressed ? 6 : 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            splashColor: const Color(0xFFFF8E7C).withOpacity(0.16),
            highlightColor: const Color(0xFFFF8E7C).withOpacity(0.07),
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTap: () async {
              await Future.delayed(const Duration(milliseconds: 85));
              if (!mounted) return;
              _setPressed(false);
              await _handleTap();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /// ⭐ 이미지 (유지)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isHidden
                            ? hiddenBg.withOpacity(0.78)
                            : const Color(0xFFFFFAF8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isHidden
                              ? hiddenAccent.withOpacity(0.16)
                              : const Color(0xFFFFE0D9),
                        ),
                      ),
                      child: _buildAchievementImageArea(
                        title: item.title,
                        imagePath: item.image,
                        isHidden: isHidden,
                        accent: accent,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// ⭐ 제목 (AutoSizeText 유지 - 1줄)
                  SizedBox(
                    height: 18,
                    child: Center(
                      child: AutoSizeText(
                        item.title,
                        maxLines: 1,
                        minFontSize: 9.5,
                        stepGranularity: 0.1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w900,
                          color: isHidden
                              ? const Color(0xFF5B3AAE)
                              : const Color(0xFF2D3436),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  /// ⭐ 칩
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withOpacity(0.18),
                        ),
                      ),
                      child: Text(
                        isHidden ? '히든' : '일반',
                        style: TextStyle(
                          fontSize: 10.0,
                          fontWeight: FontWeight.w800,
                          color: accent,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  /// ⭐ 칭호 (Text로 안정화)
                  SizedBox(
                    height: 28,
                    child: Center(
                      child: _isTitleLoading && !hasUnlockedTitle
                          ? const Text(
                        '...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8.0,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      )
                          : hasUnlockedTitle
                          ? Text(
                        '“$_cardUnlockedTitle”',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.2,
                          fontWeight: FontWeight.w800,
                          color: accent.withOpacity(0.94),
                          height: 1.0,
                        ),
                      )
                          : const Text(
                        '???',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8.0,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
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

  Widget _buildAchievementImageArea({
    required String title,
    required String? imagePath,
    required bool isHidden,
    required Color accent,
  }) {
    final hasImage = imagePath != null && imagePath.trim().isNotEmpty;

    if (hasImage) {
      return widget.imageBuilder(
        title: title,
        imagePath: imagePath,
        padding: 8,
        iconSize: 28,
        fit: BoxFit.contain,
      );
    }

    if (isHidden) {
      return Center(
        child: Text(
          '🌟',
          style: TextStyle(fontSize: 28),
        ),
      );
    }

    return widget.imageBuilder(
      title: title,
      imagePath: imagePath,
      padding: 8,
      iconSize: 28,
      fit: BoxFit.contain,
    );
  }
}

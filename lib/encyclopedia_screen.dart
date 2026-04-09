import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'setting_screen.dart';
import 'models/global_search_item.dart';
import 'dart:ui';

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
  String _selectedFilter = '금토리 전시회';
  GlobalSearchItem? _pendingSearchItem;

  final ScrollController _outfitScrollController = ScrollController();
  final ScrollController _furnitureScrollController = ScrollController();
  final ScrollController _achievementScrollController = ScrollController();

  bool _showTopBtn = false;
  bool _isFilterVisible = true;
  bool _isRefreshing = false;

  final Color snackAccent = const Color(0xFFFF8E7C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });

    _attachScrollListener(_outfitScrollController);
    _attachScrollListener(_furnitureScrollController);
    _attachScrollListener(_achievementScrollController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    _outfitScrollController.dispose();
    _furnitureScrollController.dispose();
    _achievementScrollController.dispose();
    super.dispose();
  }

  void _attachScrollListener(ScrollController controller) {
    controller.addListener(() {
      if (!mounted || !controller.hasClients) return;

      final bool showBtn = controller.offset > 100;
      if (showBtn != _showTopBtn) {
        setState(() => _showTopBtn = showBtn);
      }

      if (controller.offset <= 5 && !_isFilterVisible) {
        setState(() => _isFilterVisible = true);
      }
    });
  }

  ScrollController _getCurrentController() {
    final index = _tabController.index.clamp(0, 2);
    if (index == 0) return _outfitScrollController;
    if (index == 1) return _furnitureScrollController;
    return _achievementScrollController;
  }

  String _getCurrentTabType() {
    final index = _tabController.index.clamp(0, 2);
    if (index == 0) return '옷';
    if (index == 1) return '가구';
    return '업적';
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double appBarHeight = topPadding + 168;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
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
                SizedBox(height: appBarHeight),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                    final controller = _getCurrentController();
                    final double offset =
                    controller.hasClients ? controller.offset : 0;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      height: (_isFilterVisible || offset < 20) ? 48 : 0,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity:
                          (_isFilterVisible || offset < 20) ? 1.0 : 0.0,
                          child:
                          _buildFilterAndSortHeader(_getCurrentTabType()),
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildOutfitContent(),
                      _buildFurnitureContent(),
                      _buildAchievementContent(),
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
          Positioned(
            right: 20,
            bottom: 140,
            child: _buildScrollToTopButton(),
          ),
        ],
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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFF8E7C).withOpacity(0.05), // 핵심 수정
            const Color(0xFFFFFAF8).withOpacity(0.96),
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
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 12),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAppBarButton(
                    icon: 'assets/icons/ic_menu.svg',
                    onTap: widget.openDrawer,
                  ),
                  _buildAppTitle(),
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
              const SizedBox(height: 4),
              _buildTabBar(),
              const SizedBox(height: 8),
              _buildIntegratedSearchBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarButton({
    required String icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SvgPicture.asset(
          icon,
          colorFilter: const ColorFilter.mode(
            Color(0xFF475569),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "도감",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF2D3436),
            letterSpacing: 0.8,
            fontFamily: 'SF Pro',
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFFFF8E7C),
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
        color: const Color(0xFFFFFAF8), // ✅ 추천 색상
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const TextField(
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF4A4543),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          prefixIcon: Padding(
            padding: EdgeInsets.all(12),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFFFF8E7C),
            ),
          ),
          hintText: '아이템을 검색해보세요.',
          hintStyle: TextStyle(
            color: Color(0xFFA8A29E),
            fontSize: 14,
          ),
          contentPadding: EdgeInsets.fromLTRB(0, 0, 16, 0),
        ),
      ),
    );
  }

  Widget _buildOutfitContent() {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;

        final controller = _outfitScrollController;
        if (!controller.hasClients) return false;

        if (controller.offset < 20 || _isRefreshing) {
          if (!_isFilterVisible) setState(() => _isFilterVisible = true);
          return false;
        }

        if ((notification.scrollDelta ?? 0) > 2 && _isFilterVisible) {
          setState(() => _isFilterVisible = false);
        } else if ((notification.scrollDelta ?? 0) < -2 && !_isFilterVisible) {
          setState(() => _isFilterVisible = true);
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isRefreshing = true);
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) setState(() => _isRefreshing = false);
        },
        color: snackAccent,
        child: ListView.builder(
          controller: _outfitScrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 180),
          itemCount: 20,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSeriesCard('숲의 주문 (${index + 1})'),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFurnitureContent() {
    return RefreshIndicator(
      onRefresh: () async {},
      color: snackAccent,
      child: ListView(
        controller: _furnitureScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
        children: [
          _buildSeriesCard('클래식 거실'),
          const SizedBox(height: 16),
          _buildSeriesCard('포근한 침실'),
        ],
      ),
    );
  }

  Widget _buildAchievementContent() {
    return RefreshIndicator(
      key: const PageStorageKey('achievement_tab'),
      onRefresh: () async {},
      color: snackAccent,
      child: ListView(
        controller: _achievementScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
        children: [
          _buildSeriesCard('기본 업적 세트'),
          const SizedBox(height: 16),
          _buildSeriesCard('수집 업적 세트'),
        ],
      ),
    );
  }

  Widget _buildFilterAndSortHeader(String type) {
    List<String> filterList = [];

    if (type == '옷') {
      filterList = ['몰린 옷가게', '금토리 전시회', '축제 패키지', '한정 상품', '이벤트 아이템'];
    } else if (type == '가구') {
      filterList = ['주방 가구', '침실 가구', '거실 가구', '야외 장식', '테마 가구'];
    } else {
      filterList = ['일반 업적', '비밀 업적', '수집 업적', '성장 업적'];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect rect) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.black, Colors.transparent],
                stops: [0.92, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 16, right: 20),
                  children:
                  filterList.map((label) => _buildFilterChip(label)).toList(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '고가순',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
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
      height: 38,
      margin: EdgeInsets.zero, // 검색창과 가로폭 완전 동일
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.25),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashFactory: NoSplash.splashFactory,

        // 살짝 밀리는 느낌
        indicatorAnimation: TabIndicatorAnimation.elastic,

        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.black.withOpacity(0.03);
          }
          return Colors.transparent;
        }),

        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
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
          Tab(text: '옷'),
          Tab(text: '가구'),
          Tab(text: '업적'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool isSelected = _selectedFilter == label;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF8E7C).withOpacity(0.12)
              : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF8E7C).withOpacity(0.4)
                : Colors.black.withOpacity(0.05),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFFFF8E7C)
                : const Color(0xFF64748B),
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _applySearchItem(GlobalSearchItem item) {
    _pendingSearchItem = item;
    final title = item.title.toLowerCase();

    if (title.contains('옷') || title.contains('코디')) {
      _tabController.animateTo(0);
    } else if (title.contains('가구')) {
      _tabController.animateTo(1);
    } else if (title.contains('업적')) {
      _tabController.animateTo(2);
    }

    setState(() {
      _selectedFilter = item.title;
    });
  }
}
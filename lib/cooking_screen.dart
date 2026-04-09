import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/global_search_item.dart';
import 'setting_screen.dart';
import 'dart:ui';

// --- 데이터 모델 및 클래스 생략 (기존과 동일) ---
class Gourmet {
  final String id;
  final String nameKo;
  final List<String> ingredients;
  final int level;
  final String? image;
  final List<int> prices;
  Gourmet({required this.id, required this.nameKo, required this.ingredients, required this.level, this.image, required this.prices});
  factory Gourmet.fromJson(Map<String, dynamic> json) {
    return Gourmet(
      id: json['id'].toString(),
      nameKo: json['nameKo'] ?? json['name_ko'] ?? '',
      ingredients: (json['ingredients'] as String? ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      image: json['image'],
      prices: [
        int.tryParse((json['price1'] ?? json['price_1'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price2'] ?? json['price_2'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price3'] ?? json['price_3'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price4'] ?? json['price_4'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price5'] ?? json['price_5'] ?? '0').toString()) ?? 0,
      ],
    );
  }
}

class CookingMaterialItem {
  final String id;
  final String nameKo;
  final String? image;
  final bool isCultivable;
  final int level;
  final List<int> prices;
  CookingMaterialItem({required this.id, required this.nameKo, this.image, required this.isCultivable, required this.level, required this.prices});
  factory CookingMaterialItem.fromJson(Map<String, dynamic> json) {
    return CookingMaterialItem(
      id: json['id']?.toString() ?? '',
      nameKo: json['nameKo'] ?? json['name_ko'] ?? '',
      image: json['image'],
      isCultivable: (json['isCultivable'] ?? json['is_cultivable'] ?? 0) == 1,
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      prices: [
        int.tryParse((json['price1'] ?? json['price_1'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price2'] ?? json['price_2'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price3'] ?? json['price_3'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price4'] ?? json['price_4'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price5'] ?? json['price_5'] ?? '0').toString()) ?? 0,
      ],
    );
  }
}

class CookingScreen extends StatefulWidget {
  final VoidCallback? openDrawer;
  final GlobalSearchItem? initialSearchItem;
  final int resetSearchSignal;

  const CookingScreen({super.key, this.openDrawer, this.initialSearchItem, this.resetSearchSignal = 0});

  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> with SingleTickerProviderStateMixin {
  static const String _favoritesKey = 'favorite_gourmet_ids';

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _recipeScrollController = ScrollController();
  final ScrollController _materialScrollController = ScrollController();

  String? _highlightedId;
  GlobalSearchItem? _pendingSearchItem;

  String _selectedFilter = '전체';
  String _searchQuery = '';
  String _selectedSort = '이름순';

  List<Gourmet> _allRecipeList = [];
  List<Gourmet> _visibleRecipeList = [];
  List<CookingMaterialItem> _allMaterialList = [];
  List<CookingMaterialItem> _visibleMaterialList = [];

  bool _isRecipeLoading = true;
  bool _isMaterialLoading = true;
  bool _isFilterVisible = true;
  bool _showTopBtn = false;
  bool _isRefreshing = false;

  Set<String> _favoriteIds = {};
  final Color snackAccent = const Color(0xFFFF8E7C);
  final String _recipeApiUrl = 'http://161.33.30.40:8080/api/gourmet';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedFilter = '전체');
        _applyFilters();
      }
    });

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
      _applyFilters();
    });

    void _scrollListener(ScrollController controller) {
      if (!controller.hasClients) return;
      bool showBtn = controller.offset > 100;
      if (showBtn != _showTopBtn) setState(() => _showTopBtn = showBtn);
      if (controller.offset <= 5 && !_isFilterVisible) setState(() => _isFilterVisible = true);
    }

    _recipeScrollController.addListener(() => _scrollListener(_recipeScrollController));
    _materialScrollController.addListener(() => _scrollListener(_materialScrollController));

    _loadFavorites();
    _fetchRecipeData();
    _loadTemporaryMaterialData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSearchItem != null) _applySearchItem(widget.initialSearchItem!);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _recipeScrollController.dispose();
    _materialScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CookingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialSearchItem != null &&
        widget.initialSearchItem != oldWidget.initialSearchItem) {
      _pendingSearchItem = widget.initialSearchItem;
      _applySearchItem(widget.initialSearchItem!);
      return;
    }

    if (widget.resetSearchSignal != oldWidget.resetSearchSignal) {
      _clearSearchState();
    }
  }

  // 🔥 에러 해결 핵심: 탭 전환 시 인덱스를 안전하게 계산하여 반환
  ScrollController _getCurrentController() {
    int index = _tabController.index.clamp(0, 1);
    if (index == 0) return _recipeScrollController;
    return _materialScrollController;
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double appBarHeight = topPadding + 166;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/bg_gradient.png', fit: BoxFit.cover)),
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: appBarHeight - 8),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                    // 스크롤 위치가 0일 때 필터바를 강제 유지하기 위해 offset 확인
                    final controller = _getCurrentController();
                    double offset = controller.hasClients ? controller.offset : 0;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      height: (_isFilterVisible || offset < 20) ? 40 : 0,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: (_isFilterVisible || offset < 20) ? 1.0 : 0.0,
                          child: _buildFilterBarArea(),
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
                      _buildRecipeTabContent(),
                      _buildMaterialTabContent(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _buildIntegratedAppBar(context, topPadding)),
          Positioned(right: 20, bottom: 140, child: _buildScrollToTopButton()),
        ],
      ),
    );
  }

  // --- 통합 UI 함수 (도감 디자인) ---
  Widget _buildIntegratedAppBar(BuildContext context, double topPadding) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.42, 1.0],
          colors: [
            const Color(0xFFFF8E7C).withOpacity(0.12),
            const Color(0xFFFFCFC7).withOpacity(0.05),
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
      padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 8),
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

  Widget _buildAppTitle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "요리",
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
            color: snackAccent,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 38,
      margin: EdgeInsets.zero,
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
          Tab(text: '레시피'),
          Tab(text: '재료'),
        ],
      ),
    );
  }

  Widget _buildIntegratedSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF8), // ✅ 도감과 동일
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
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF4A4543),
          fontWeight: FontWeight.w600,
        ),
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
          hintText: _tabController.index == 0
              ? '음식 이름을 검색해보세요.'
              : '요리 재료를 검색해보세요.',
          hintStyle: const TextStyle(
            color: Color(0xFFA8A29E),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _searchController.clear(),
          )
              : null,
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
        onTap: () => _getCurrentController().animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutQuart),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), shape: BoxShape.circle, border: Border.all(color: Colors.black.withOpacity(0.05), width: 0.8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
          child: const Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFF64748B), size: 26),
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
          color: const Color(0xFFFFFBFA).withOpacity(0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF8E7C).withOpacity(0.07),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SvgPicture.asset(
          icon,
          colorFilter: const ColorFilter.mode(
            Color(0xFF5F6B7A),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  // --- 리스트 탭 콘텐츠 ---
  Widget _buildRecipeTabContent() {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        if (_recipeScrollController.offset < 20 || _isRefreshing) {
          if (!_isFilterVisible) setState(() => _isFilterVisible = true);
          return false;
        }
        if (notification.scrollDelta! > 2 && _isFilterVisible) setState(() => _isFilterVisible = false);
        else if (notification.scrollDelta! < -2 && !_isFilterVisible) setState(() => _isFilterVisible = true);
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async { setState(() => _isRefreshing = true); await _fetchRecipeData(); if (mounted) setState(() => _isRefreshing = false); },
        color: snackAccent,
        child: _isRecipeLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8E7C)))
            : ListView.builder(
          controller: _recipeScrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 180),
          itemCount: _visibleRecipeList.length,
          itemBuilder: (context, index) => _buildRecipeCard(_visibleRecipeList[index]),
        ),
      ),
    );
  }

  Widget _buildMaterialTabContent() {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        if (_materialScrollController.offset < 20 || _isRefreshing) {
          if (!_isFilterVisible) setState(() => _isFilterVisible = true);
          return false;
        }
        if (notification.scrollDelta! > 2 && _isFilterVisible) setState(() => _isFilterVisible = false);
        else if (notification.scrollDelta! < -2 && !_isFilterVisible) setState(() => _isFilterVisible = true);
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async { setState(() => _isRefreshing = true); await _refreshMaterialData(); if (mounted) setState(() => _isRefreshing = false); },
        color: snackAccent,
        child: _isMaterialLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8E7C)))
            : ListView.builder(
          controller: _materialScrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 180),
          itemCount: _visibleMaterialList.length,
          itemBuilder: (context, index) => _buildMaterialCard(_visibleMaterialList[index]),
        ),
      ),
    );
  }

  Widget _buildPriceTagLabel() {
    return Container(
      constraints: const BoxConstraints(minWidth: 46),
      height: 20,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFFFF7A65).withOpacity(0.5),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '판매가',
        style: TextStyle(
          color: Color(0xFFFF7A65),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildPriceButton(List<int> prices) {
    final validPrices = prices.where((e) => e > 0).toList();
    final pricePreview = validPrices.isEmpty
        ? '-'
        : (validPrices.first == validPrices.last
        ? '${_formatPrice(validPrices.first)}원'
        : '${_formatPrice(validPrices.first)}원 ~ ${_formatPrice(validPrices.last)}원');

    return GestureDetector(
      onTap: () => _showPriceBottomSheet(prices),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF8E7C).withOpacity(0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EE),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                '판매가',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF7A65),
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              pricePreview,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D3436),
                height: 1.0,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceBottomSheet(List<int> prices) {
    final visiblePrices = <Map<String, dynamic>>[];

    for (int i = 0; i < prices.length; i++) {
      if (prices[i] > 0) {
        visiblePrices.add({
          'star': i + 1,
          'price': prices[i],
        });
      }
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.18),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.98),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFFFE1DA),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        size: 16,
                        color: Color(0xFFFF8E7C),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '성급별 판매가',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (visiblePrices.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        '가격 정보 없음',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  )
                else
                  ...visiblePrices.map((item) {
                    final int star = item['star'] as int;
                    final int price = item['price'] as int;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _getStarBadgeColor(star),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$star성',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3F3F46),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_formatPrice(price)}원',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2D3436),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStarBadgeColor(int star) {
    switch (star) {
      case 1:
        return const Color(0xFFE5E7EB);
      case 2:
        return const Color(0xFFFFE4E6);
      case 3:
        return const Color(0xFFFFEDD5);
      case 4:
        return const Color(0xFFFEF3C7);
      case 5:
        return const Color(0xFFDCFCE7);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  // 2. [교정] 레시피 카드 내 판매가 위치 (채집 탭 레이아웃 이식)
  Widget _buildRecipeCard(Gourmet item) {
    final isFavorite = _favoriteIds.contains(item.id);
    final isHighlighted = _highlightedId == item.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ShapeDecoration(
        color: isHighlighted
            ? const Color(0xFFFFF4D8)
            : Colors.white.withOpacity(0.92),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),

          // ✅ 재료 카드랑 동일한 테두리 톤
          side: BorderSide(
            color: isHighlighted
                ? const Color(0xFFFFB27A).withOpacity(0.6)
                : const Color(0xFFFF8E7C).withOpacity(0.12),
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
      child: SizedBox(
        height: 160,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAF8), // ✅ 재료 카드랑 통일
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF8E7C).withOpacity(0.15),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.image != null
                      ? Image.asset(
                    'assets/${item.image}',
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) =>
                    const Icon(Icons.restaurant_menu, color: Colors.grey),
                  )
                      : const Icon(Icons.restaurant_menu, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _displayRecipeName(item),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                                height: 1.2,
                              ),
                              maxLines: 2, // ✅ 1 → 2줄 (더 안정적)
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _toggleFavorite(item.id),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 24,
                              color: isFavorite
                                  ? const Color(0xFFFF8E7C)
                                  : const Color(0xFFD9D9D9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _buildSmallTag('요리 ${item.level}레벨'),
                        if (_isEventRecipe(item))
                          _buildSmallTag('이벤트', isEvent: true),
                      ],
                    ),
                    const SizedBox(height: 10),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _buildIngredientIcons(item.ingredients),
                      ),
                    ),

                    const Spacer(),

                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildPriceButton(item.prices),
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

  Widget _buildMaterialCard(CookingMaterialItem item) {
    final isFavorite = _favoriteIds.contains(item.id);
    final isHighlighted = _highlightedId == item.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ShapeDecoration(
        color: isHighlighted
            ? const Color(0xFFFFF4D8)
            : Colors.white.withOpacity(0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isHighlighted
                ? const Color(0xFFFFB27A).withOpacity(0.55)
                : const Color(0xFFFF8E7C).withOpacity(0.12),
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
      child: IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAF8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFF8E7C).withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: item.image != null
                      ? Image.asset(
                    item.image!,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) =>
                    const Icon(Icons.spa_outlined, color: Colors.grey),
                  )
                      : const Icon(Icons.spa_outlined, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              item.nameKo,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _toggleFavorite(item.id),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 24,
                              color: isFavorite
                                  ? const Color(0xFFFF8E7C)
                                  : const Color(0xFFD9D9D9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildSmallTag('요리 ${item.level}레벨'),
                        _buildSmallTag(
                          item.isCultivable ? '작물' : '상점구매',
                          isEvent: !item.isCultivable,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildPriceButton(item.prices),
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

  String _normalizeSearchTargetId(String rawId) {
    if (rawId.startsWith('gourmet_')) {
      return rawId.replaceFirst('gourmet_', '');
    }
    if (rawId.startsWith('material_')) {
      return rawId.replaceFirst('material_', '');
    }
    return rawId;
  }

  void _moveToTopInList<T>(List<T> list, bool Function(T e) match) {
    final index = list.indexWhere(match);
    if (index <= 0) return;

    final selected = list.removeAt(index);
    list.insert(0, selected);
  }

  void _scrollToTopForCookingTab(CookingTabType tab) {
    final controller = tab == CookingTabType.material
        ? _materialScrollController
        : _recipeScrollController;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;

      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // --- 공통 카드 헬퍼 (레벨별 컬러 복구) ---
  String _ingredientImagePath(String ingredientName) {
    const map = {
      '토마토': 'assets/images/ingredient_tomato.png', '감자': 'assets/images/ingredient_potato.png', '밀': 'assets/images/ingredient_wheat.png',
      '상추': 'assets/images/ingredient_lettuce.png', '당근': 'assets/images/ingredient_carrot.png', '옥수수': 'assets/images/ingredient_corn.png',
      '딸기': 'assets/images/ingredient_strawberry.png', '포도': 'assets/images/ingredient_grape.png', '가지': 'assets/images/ingredient_eggplant.png',
      '사과': 'assets/images/ingredient_apple.png', '오렌지': 'assets/images/ingredient_orange.png', '파인애플': 'assets/images/ingredient_pineapple.png',
      '블루베리': 'assets/images/ingredient_blueberry.png', '라즈베리': 'assets/images/ingredient_raspberry.png', '무': 'assets/images/ingredient_radish.png',
      '아보카도': 'assets/images/ingredient_avocado.png', '달걀': 'assets/images/ingredient_egg.png', '우유': 'assets/images/ingredient_milk.png',
      '치즈': 'assets/images/ingredient_cheese.png', '버터': 'assets/images/ingredient_butter.png', '고기': 'assets/images/ingredient_meat.png',
      '식용유': 'assets/images/ingredient_oil.png', '커피 콩': 'assets/images/ingredient_coffee_bean.png', '슈가파우더': 'assets/images/ingredient_sugar_powder.png',
      '아무 채소': 'assets/images/icon_veg_any.png', '아무 생선': 'assets/images/icon_fish_any.png', '아무 버섯': 'assets/images/icon_mushroom_any.png',
      '혼합 과일': 'assets/images/icon_fruit_any.png', '아무 과일': 'assets/images/icon_fruit_any.png', '아무 설탕': 'assets/images/icon_sugar_any.png',
      '아무 조개류': 'assets/images/icon_shellfish_any.png', '아무 랍스터': 'assets/images/icon_lobster_any.png', '아무 킹크랩': 'assets/images/icon_king_crab_any.png',
      '아무 커피': 'assets/images/icon_coffee_any.png', '아무 음식': 'assets/images/icon_food_any.png', '아무 음료': 'assets/images/icon_drink_any.png',
    };
    return map[ingredientName] ?? 'assets/images/default.png';
  }

  List<Widget> _buildIngredientIcons(List<String> ingredients) {
    final List<Widget> widgets = [];
    for (final raw in ingredients) {
      final text = raw.trim();
      if (text.isEmpty || text == '----') continue;
      final reg = RegExp(r'^(.*?)\s*[\(x×]?\s*(\d+)?\)?$');
      final match = reg.firstMatch(text);
      String name = text; int count = 1;
      if (match != null) { name = match.group(1)!.trim(); count = int.tryParse(match.group(2) ?? '1') ?? 1; }
      final imagePath = _ingredientImagePath(name);
      for (int i = 0; i < count; i++) {
        widgets.add(Container(
          width: 32, height: 32, margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: const Color(0xC6FFF8E7), borderRadius: BorderRadius.circular(4)),
          child: Center(child: Padding(padding: const EdgeInsets.all(4.0), child: Image.asset(imagePath, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 16, color: Colors.grey)))),
        ));
      }
    }
    return widgets;
  }

  Widget _buildSmallTag(String text, {bool isEvent = false}) {
    final rawText = text.trim();
    final lowerText = rawText.toLowerCase();

    // 기본값 (회색)
    Color bg = const Color(0xFFF5F5F5);
    Color border = const Color(0xFFE0E0E0);
    Color textColor = const Color(0xFF757575);

    bool isHiddenActive = text.contains('있음');

    // 1. 이벤트 또는 히든 레시피 태그 (주황/분홍 톤)
    if (isHiddenActive || isEvent) {
      bg = const Color(0xFFFFEDE1);
      border = const Color(0xFFFFCCBC);
      textColor = const Color(0xFFD84315);
    }

    // 2. ★ 요리 레벨별 무지개 색상 로직 (채집 코드 규격 이식)
    if (rawText.contains('레벨')) {
      int level = int.tryParse(rawText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

      if (level == 1) {
        bg = const Color(0xFFEEEEEE); border = const Color(0xFFBDBDBD); textColor = const Color(0xFF616161);
      } else if (level == 2) {
        bg = const Color(0xFFFFEBEE); border = const Color(0xFFFFCDD2); textColor = const Color(0xFFC62828);
      } else if (level == 3) {
        bg = const Color(0xFFFFF3E0); border = const Color(0xFFFFE0B2); textColor = const Color(0xFFE65100);
      } else if (level == 4) {
        bg = const Color(0xFFFFFDE7); border = const Color(0xFFFFF9C4); textColor = const Color(0xFFF57F17);
      } else if (level == 5) {
        bg = const Color(0xFFE8F5E9); border = const Color(0xFFC8E6C9); textColor = const Color(0xFF2E7D32);
      } else if (level == 6) {
        bg = const Color(0xFFE1F5FE); border = const Color(0xFFB3E5FC); textColor = const Color(0xFF0277BD);
      } else if (level == 7) {
        bg = const Color(0xFFE8EAF6); border = const Color(0xFFC5CAE9); textColor = const Color(0xFF1A237E);
      } else if (level == 8) {
        bg = const Color(0xFFF3E5F5); border = const Color(0xFFE1BEE7); textColor = const Color(0xFF7B1FA2);
      } else if (level == 9) {
        bg = const Color(0xFFFCE4EC); border = const Color(0xFFF8BBD0); textColor = const Color(0xFFC2185B);
      } else { // 10레벨 이상 마스터
        textColor = const Color(0xFF424242);
        border = const Color(0xFFBDBDBD).withOpacity(0.5);
      }
    }

    final bool isMasterLevel = rawText.contains('레벨') && (int.tryParse(rawText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) >= 10;

    return Container(
      // [교정] 채집 화면과 동일한 콤팩트 패딩 (가로 7, 세로 2.5)
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: isMasterLevel
            ? const LinearGradient(
          colors: [Color(0xFFFFD1D1), Color(0xFFFFF4D1), Color(0xFFD1FFDA), Color(0xFFD1E3FF), Color(0xFFE5D1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: isMasterLevel ? null : bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withOpacity(0.5), width: 0.8),
      ),
      child: Transform.translate(
        // [교정] 폰트 크기와 수직 정렬을 채집 화면 기준으로 통일
        offset: const Offset(0, -0.5),
        child: Text(
          rawText,
          style: TextStyle(
            fontSize: 9.5, // 9 -> 9.5로 미세 조정
            color: textColor,
            fontWeight: (isMasterLevel || isHiddenActive || isEvent) ? FontWeight.w700 : FontWeight.w600,
            height: 1.0,
            fontFamily: 'SF Pro',
          ),
        ),
      ),
    );
  }

  String _formatPrice(int? price) {
    if (price == null) return '0';
    return price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  List<PopupMenuEntry<String>> _buildPriceMenuItems(List<int> prices) {
    final items = <PopupMenuEntry<String>>[];

    for (int i = 0; i < prices.length; i++) {
      final value = prices[i];
      if (value > 0) {
        items.add(
          PopupMenuItem<String>(
            enabled: false, // 클릭할 필요 없는 정보용이므로 비활성화(색상은 유지)
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // 성급 표시 (별 아이콘 + 텍스트)
                  Icon(Icons.star_rounded, size: 16, color: Colors.orange[400]),
                  const SizedBox(width: 4),
                  Text(
                    '${i + 1}성',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        fontFamily: 'SF Pro'
                    ),
                  ),
                  const Spacer(),
                  // 가격 텍스트
                  Text(
                    '${_formatPrice(value)}원',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF2D3436),
                        fontFamily: 'SF Pro'
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        // 마지막 아이템이 아니면 얇은 구분선 추가
        if (i < prices.where((e) => e > 0).length - 1) {
          items.add(const PopupMenuDivider(height: 1));
        }
      }
    }

    if (items.isEmpty) {
      items.add(
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('가격 정보 없음', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ),
      );
    }

    return items;
  }

  // --- 데이터 및 필터 로직 ---
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_favoritesKey) ?? [];
    setState(() => _favoriteIds = stored.toSet());
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favoriteIds.toList());
  }

  Future<void> _toggleFavorite(String id) async {
    setState(() { if (_favoriteIds.contains(id)) _favoriteIds.remove(id); else _favoriteIds.add(id); });
    await _saveFavorites(); _applyFilters();
  }

  Future<void> _fetchRecipeData() async {
    setState(() => _isRecipeLoading = true);
    try {
      final response = await http.get(Uri.parse(_recipeApiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        _allRecipeList = data.map((json) => Gourmet.fromJson(json)).toList();
      }
    } catch (e) { debugPrint('로드 실패: $e'); }
    setState(() => _isRecipeLoading = false); _applyFilters();
  }

  Future<void> _refreshMaterialData() async { _loadTemporaryMaterialData(); }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();

    if (_tabController.index == 0) {
      List<Gourmet> temp = List.from(_allRecipeList);

      if (query.isNotEmpty) {
        temp = temp.where((item) {
          final name = item.nameKo.toLowerCase();
          final id = item.id.toLowerCase();
          return name.contains(query) || id.contains(query);
        }).toList();
      }

      if (_selectedFilter == '일반 레시피') {
        temp = temp.where((item) => !_isEventRecipe(item)).toList();
      } else if (_selectedFilter == '히든 레시피') {
        temp = temp.where((item) => _isEventRecipe(item)).toList();
      }

      _sortRecipes(temp);

      if (_pendingSearchItem != null &&
          _pendingSearchItem!.cookingTab == CookingTabType.recipe) {
        final normalizedId = _normalizeSearchTargetId(_pendingSearchItem!.id);

        _moveToTopInList<Gourmet>(
          temp,
              (e) => e.id.trim() == normalizedId.trim(),
        );
      }

      if (!mounted) return;
      setState(() {
        _visibleRecipeList = temp;
      });
    } else {
      List<CookingMaterialItem> temp = List.from(_allMaterialList);

      if (query.isNotEmpty) {
        temp = temp.where((item) {
          final name = item.nameKo.toLowerCase();
          final id = item.id.toLowerCase();
          return name.contains(query) || id.contains(query);
        }).toList();
      }

      if (_selectedFilter == '작물') {
        temp = temp.where((item) => item.isCultivable).toList();
      } else if (_selectedFilter == '상점구매') {
        temp = temp.where((item) => !item.isCultivable).toList();
      }

      _sortMaterials(temp);

      if (_pendingSearchItem != null &&
          _pendingSearchItem!.cookingTab == CookingTabType.material) {
        final normalizedId = _normalizeSearchTargetId(_pendingSearchItem!.id);

        _moveToTopInList<CookingMaterialItem>(
          temp,
              (e) => e.id.trim() == normalizedId.trim(),
        );
      }

      if (!mounted) return;
      setState(() {
        _visibleMaterialList = temp;
      });
    }
  }

  void _sortRecipes(List<Gourmet> list) {
    if (_selectedSort == '가격순') list.sort((a, b) => b.prices.first.compareTo(a.prices.first));
    else if (_selectedSort == '좋아요순') list.sort((a, b) => (_favoriteIds.contains(b.id) ? 1 : 0).compareTo(_favoriteIds.contains(a.id) ? 1 : 0));
    else list.sort((a, b) => a.nameKo.compareTo(b.nameKo));
  }

  void _sortMaterials(List<CookingMaterialItem> list) {
    if (_selectedSort == '가격순') list.sort((a, b) => b.prices.first.compareTo(a.prices.first));
    else if (_selectedSort == '좋아요순') list.sort((a, b) => (_favoriteIds.contains(b.id) ? 1 : 0).compareTo(_favoriteIds.contains(a.id) ? 1 : 0));
    else list.sort((a, b) => a.nameKo.compareTo(b.nameKo));
  }

  List<String> _currentFilters() => _tabController.index == 0 ? const ['전체', '일반 레시피', '히든 레시피'] : const ['전체', '작물', '상점구매'];

  void _loadTemporaryMaterialData() {
    _allMaterialList = [
      CookingMaterialItem(id: 'tomato', nameKo: '토마토', image: 'assets/images/ingredient_tomato.png', isCultivable: true, level: 1, prices: [30, 45, 60, 120, 240]),
      CookingMaterialItem(id: 'wheat', nameKo: '밀', image: 'assets/images/ingredient_wheat.png', isCultivable: true, level: 2, prices: [285, 381, 475, 570, 1140]),
    ];
    _isMaterialLoading = false; _applyFilters();
  }

  void _onSortSelected(String sort) { setState(() => _selectedSort = sort); _applyFilters(); }

  void _applySearchItem(GlobalSearchItem item) {
    _pendingSearchItem = item;

    if (item.cookingTab == null) return;

    final normalizedId = _normalizeSearchTargetId(item.id);

    // 홈 검색으로 들어왔을 때 검색창은 비워둠
    _searchController.clear();
    _searchQuery = '';

    if (item.cookingTab == CookingTabType.material) {
      _tabController.animateTo(1);
    } else {
      _tabController.animateTo(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _applyFilters();

      setState(() {
        _highlightedId = normalizedId;
      });

      _scrollToTopForCookingTab(item.cookingTab ?? CookingTabType.recipe);

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (_highlightedId == normalizedId) {
          setState(() {
            _highlightedId = null;
          });
        }
      });
    });
  }

  Widget _buildFilterBarArea() {
    final filters = _currentFilters();

    return Padding(
      padding: EdgeInsets.zero,
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
                  children: filters.map((filter) => _buildFilterChip(filter)).toList(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: PopupMenuButton<String>(
              onSelected: _onSortSelected,
              itemBuilder: (context) => const [
                PopupMenuItem(value: '이름순', child: Text('이름순')),
                PopupMenuItem(value: '가격순', child: Text('가격순')),
                PopupMenuItem(value: '좋아요순', child: Text('좋아요순')),
              ],
              offset: const Offset(0, 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.white,
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedSort,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(
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

  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () { setState(() => _selectedFilter = label); _applyFilters(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFFFF8E7C).withOpacity(0.12) : Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? const Color(0xFFFF8E7C).withOpacity(0.4) : Colors.black.withOpacity(0.05), width: 1.2)),
        child: Text(label, style: TextStyle(color: isSelected ? const Color(0xFFFF8E7C) : const Color(0xFF64748B), fontSize: 12.5, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
      ),
    );
  }

  bool _isEventRecipe(Gourmet item) => item.nameKo.contains('(이벤트)');
  String _displayRecipeName(Gourmet item) => item.nameKo.replaceAll(' (이벤트)', '').replaceAll('(이벤트)', '').trim();

  void _clearSearchState() {
    _pendingSearchItem = null;

    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    if (!mounted) return;

    setState(() {
      _searchQuery = '';
      _highlightedId = null;
      _selectedFilter = '전체';
    });

    _applyFilters();
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'setting_screen.dart';
import 'models/global_search_item.dart';
import 'package:flutter/rendering.dart';
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

  final ScrollController _scrollController = ScrollController(); // 스크롤 제어용
  bool _showTopBtn = false;      // 맨 위로 버튼 표시 여부
  bool _isFilterVisible = true;  // 플로팅 필터바 표시 여부

  final Color snackAccent = const Color(0xFFFF8E7C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // [수정] 리스너가 인덱스 변화를 더 민감하게 감지하도록 함
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || true) { // 어떤 변화든 setState 호출
        setState(() {
          // 인덱스 변화에 따라 선택된 필터 초기화 등 필요 로직 수행
          // _selectedFilter = ... (필요시)
        });
      }
    });

    _scrollController.addListener(() {
      bool showBtn = _scrollController.offset > 100;
      if (showBtn != _showTopBtn) {
        setState(() => _showTopBtn = showBtn);
      }
      if (_scrollController.offset <= 5 && !_isFilterVisible) {
        setState(() => _isFilterVisible = true);
      }
    });

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
    _scrollController.dispose(); // [추가] 컨트롤러 해제
    super.dispose();
  }

  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double appBarHeight = topPadding + 168;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/bg_gradient.png', fit: BoxFit.cover)),

          // 1. 메인 콘텐츠
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: appBarHeight),
                // [추가] 앱바와 필터바 사이의 숨통 여백
                const SizedBox(height: 12),

                // [핵심] 스크롤 방향에 따라 높이가 0~54로 변하는 필터바 영역
                AnimatedBuilder(
                  animation: _tabController, // 탭 컨트롤러의 모든 변화를 실시간 감시
                  builder: (context, child) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      height: (_isFilterVisible || _scrollController.offset < 20) ? 48 : 0,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: (_isFilterVisible || _scrollController.offset < 20) ? 1.0 : 0.0,
                          child: _buildFilterAndSortHeader(
                            // 이제 리스너와 AnimatedBuilder 덕분에 실시간으로 반영됩니다.
                              _tabController.index == 0 ? '옷' : (_tabController.index == 1 ? '가구' : '업적')
                          ),
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

          // 2. 통합 앱바 (최상단 고정)
          Positioned(top: 0, left: 0, right: 0, child: _buildIntegratedAppBar(context, topPadding)),

          // 3. 맨 위로 가기 버튼
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
        onTap: () => _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutQuart
        ),
        child: Container(
          // 1. 크기 축소 (52 -> 42)
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            // 2. 색상 변경: 진한 코랄 대신 반투명한 화이트/웜그레이 톤으로 변경
            color: Colors.white.withOpacity(0.85),
            shape: BoxShape.circle,
            // 3. 테두리 추가: 밝은 배경에서도 형태가 보이도록 미세한 선 추가
            border: Border.all(color: Colors.black.withOpacity(0.05), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08), // 그림자 농도 대폭 하향
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.keyboard_arrow_up_rounded,
            // 4. 아이콘 색상 및 크기 조절 (화이트 -> 차분한 슬레이트 그레이)
            color: const Color(0xFF64748B),
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildIntegratedAppBar(BuildContext context, double topPadding) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // 1. 하단 패딩을 20에서 12로 줄여 전체적인 앱바 점유 높이를 축소합니다.
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 12),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 버튼 영역 (홈 화면과 높이 일치 유지)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAppBarButton(icon: 'assets/icons/ic_menu.svg', onTap: widget.openDrawer),
                  _buildAppTitle(),
                  _buildAppBarButton(
                      icon: 'assets/icons/ic_settings.svg',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))
                  ),
                ],
              ),

              // 2. 버튼과 탭바 사이 간격을 16에서 4로 대폭 줄여 위로 올립니다.
              const SizedBox(height: 4),
              _buildTabBar(),

              // 3. 탭바와 검색바 사이 간격도 최소화 (8 -> 4)
              const SizedBox(height: 4),
              _buildIntegratedSearchBar(),
            ],
          ),
        ),
      ),
    );
  }

// 홈 화면과 통일된 스타일의 앱 버튼
  Widget _buildAppBarButton({required String icon, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC), // 홈 화면 bgColor 통일
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)
            ),
          ],
        ),
        child: SvgPicture.asset(
            icon,
            colorFilter: const ColorFilter.mode(Color(0xFF475569), BlendMode.srcIn)
        ),
      ),
    );
  }

// 홈 화면과 통일된 타이틀 디자인
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
              // [수정] 자간을 -0.6 -> 0.8로 변경하여 가독성 확보
              letterSpacing: 0.8,
              fontFamily: 'SF Pro'
          ),
        ),
        const SizedBox(height: 2),
        Container(
            width: 12,
            height: 3,
            decoration: BoxDecoration(
                color: const Color(0xFFFF8E7C),
                borderRadius: BorderRadius.circular(10)
            )
        ),
      ],
    );
  }

// 따뜻한 웜 그레이 검색바
  Widget _buildIntegratedSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF8E7C).withOpacity(0.28), width: 1.3),
      ),
      child: TextField(
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 14, color: Color(0xFF4A4543), fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          prefixIcon: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.search_rounded, size: 20, color: Color(0xFFFF8E7C)),
          ),
          hintText: '아이템을 검색해보세요.',
          hintStyle: const TextStyle(color: Color(0xFFA8A29E), fontSize: 14),
          contentPadding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
        ),
      ),
    );
  }

  Widget _buildOutfitContent() {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;

        // 최상단 근처거나 새로고침 중이면 필터바 노출 고정
        if (_scrollController.offset < 20 || _isRefreshing) {
          if (!_isFilterVisible) setState(() => _isFilterVisible = true);
          return false;
        }

        if (notification.scrollDelta! > 2 && _isFilterVisible) {
          setState(() => _isFilterVisible = false);
        } else if (notification.scrollDelta! < -2 && !_isFilterVisible) {
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
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          // index == 0일 때 필터바를 그리던 로직을 지우고 바로 카드부터 시작
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

// 필터와 정렬을 묶은 헤더 위젯 분리
  Widget _buildFilterAndSortHeader(String type) {
    List<String> filterList = [];

    // 타입에 따라 다른 필터 목록 생성
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
                  children: filterList.map((label) => _buildFilterChip(label)).toList(),
                ),
              ),
            ),
          ),

          // 정렬 버튼
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('고가순', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w700)),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: ShapeDecoration(
        color: const Color(0xFFFEFEFE).withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        shadows: [BoxShadow(color: Colors.black.withOpacity(0.08), spreadRadius: 1.0, blurRadius: 14, offset: const Offset(0, 0))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(left: 12, bottom: 12), child: Text(seriesTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333), fontFamily: 'SF Pro'))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildColorCard('분홍', 'assets/images/woods_pink.png', isFavorite: false),
              _buildColorCard('목가', 'assets/images/woods_wood.png', isFavorite: true),
              _buildColorCard('보라', 'assets/images/woods_purple.png', isFavorite: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorCard(String colorName, String imagePath, {required bool isFavorite}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: ShapeDecoration(color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), shadows: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(2, 2))]),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 24),
                Expanded(child: Text(colorName, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF505050), fontSize: 14, fontWeight: FontWeight.w500))),
                Icon(isFavorite ? Icons.favorite : Icons.favorite_border, size: 24, color: isFavorite ? const Color(0xFFFF8E7C) : const Color(0xFFD9D9D9)),
              ],
            ),
            const SizedBox(height: 8),
            Image.asset(imagePath, height: 150, fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox(height: 100, child: Icon(Icons.broken_image))),
            const SizedBox(height: 12),
            Container(width: double.infinity, height: 0.5, color: Colors.black.withOpacity(0.1), margin: const EdgeInsets.only(bottom: 8)),
            _buildSmallGridRow(),
            const SizedBox(height: 4),
            _buildSmallGridRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallGridRow() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (index) => Container(width: 20, height: 20, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: ShapeDecoration(color: const Color(0xC6FFF8E7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))))));
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: snackAccent,
      unselectedLabelColor: const Color(0xFF94A3B8),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(width: 4, color: snackAccent),
        insets: const EdgeInsets.symmetric(horizontal: -12),
      ),
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) return Colors.black.withOpacity(0.05);
        return Colors.transparent;
      }),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      // [수정] 두 스타일의 fontSize를 16으로 통일하여 크기 변화 제거
      labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'SF Pro'),
      unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'SF Pro'),
      tabs: const [
        Tab(height: 44, text: '옷'),
        Tab(height: 44, text: '가구'),
        Tab(height: 44, text: '업적'),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8E7C).withOpacity(0.12) : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF8E7C).withOpacity(0.4) : Colors.black.withOpacity(0.05),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFF8E7C) : const Color(0xFF64748B),
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

  // [수정] 가구 탭
  Widget _buildFurnitureContent() {
    return RefreshIndicator(
      onRefresh: () async {},
      color: snackAccent,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 180),
        children: const [
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: 80),
              child: Text("가구 도감 준비 중", style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

// [수정] 업적 도감 빌더
  Widget _buildAchievementContent() {
    return RefreshIndicator(
      key: const PageStorageKey('achievement_tab'),
      onRefresh: () async {},
      color: snackAccent,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 180), // 여백 통일
        children: [
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 80),
              child: Text("업적 도감 준비 중", style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
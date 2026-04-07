import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'setting_screen.dart';
import 'models/global_search_item.dart';

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

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this); // 기존 탭 개수로 맞춰

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSearchItem != null) {
        _pendingSearchItem = widget.initialSearchItem;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // ★ drawer 코드는 삭제됨 (MainWrapper가 관리)
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_gradient.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildCustomAppBar(context),
              _buildTabBar(),
              const SizedBox(height: 10),
              _buildSearchBar(hint: "아이템을 검색해보세요."),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
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
          // ★ 부모가 넘겨준 함수를 바로 실행
          IconButton(
              onPressed: widget.openDrawer,
              icon: SvgPicture.asset('assets/icons/ic_menu.svg', width: 24, height: 24)
          ),
          const Text(
              '도감',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'SF Pro')
          ),
          IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
              icon: SvgPicture.asset('assets/icons/ic_settings.svg', width: 24, height: 24)
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(width: double.infinity, height: 0.7, color: const Color(0xFFC4C4C4)),
        TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: const Color(0xFF898989),
          labelStyle: const TextStyle(fontSize: 16, fontFamily: 'SF Pro', fontWeight: FontWeight.w500),
          indicatorColor: Colors.black,
          indicatorWeight: 1.5,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorPadding: const EdgeInsets.symmetric(horizontal: -15),
          tabs: const [Tab(text: '옷'), Tab(text: '가구'), Tab(text: '업적')],
        ),
      ],
    );
  }

  Widget _buildOutfitContent() {
    return Column(
      children: [
        // ✅ 고정 필터바
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ShaderMask(
                  shaderCallback: (Rect rect) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.black, Colors.transparent],
                      stops: [0.90, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: SizedBox(
                    height: 48,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(left: 16, right: 20),
                      child: Row(
                        children: [
                          _buildFilterChip('몰린 옷가게'),
                          _buildFilterChip('금토리 전시회'),
                          _buildFilterChip('축제 패키지'),
                          _buildFilterChip('한정 상품'),
                          _buildFilterChip('이벤트 아이템'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {},
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        alignment: const Alignment(0, -0.07),
                        height: 48,
                        child: const Text(
                          '고가순',
                          style: TextStyle(
                            color: Color(0xFF616161),
                            fontSize: 12,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Color(0xFF616161),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        // ✅ 리스트만 스크롤
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {},
            color: const Color(0xFFFF8E7C),
            backgroundColor: Colors.white,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSeriesCard('숲의 주문 (1)'),
                const SizedBox(height: 16),
                _buildSeriesCard('숲의 주문 (2)'),
                const SizedBox(height: 16),
                _buildSeriesCard('숲의 주문 (3)'),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
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

  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedFilter == label;
    const Color selectedBgColor = Color(0xFFFFDED9);
    const Color selectedTextColor = Color(0xFF555655);
    final Color selectedBorderColor = const Color(0xFFFF7A65).withOpacity(0.2);
    const Color unselectedBgColor = Colors.white;
    final Color unselectedBorderColor = Colors.black.withOpacity(0.08);

    return Theme(
      data: Theme.of(context).copyWith(splashColor: Colors.transparent, highlightColor: Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (bool selected) => setState(() => _selectedFilter = label),
          labelStyle: TextStyle(color: isSelected ? selectedTextColor : const Color(0xFF333333), fontSize: 12, height: 1.0, fontFamily: 'SF Pro', fontWeight: isSelected ? FontWeight.bold : FontWeight.w400),
          backgroundColor: unselectedBgColor,
          selectedColor: selectedBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36), side: BorderSide(color: isSelected ? selectedBorderColor : unselectedBorderColor, width: 1.0)),
          visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: -2),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          showCheckmark: false,
        ),
      ),
    );
  }

  void _applySearchItem(GlobalSearchItem item) {
    // 🔥 기본: 검색 결과 저장
    _pendingSearchItem = item;

    // 🔥 1. 탭 이동 (item 이름 기준으로 분기)
    final title = item.title.toLowerCase();

    if (title.contains('옷') || title.contains('코디')) {
      _tabController.animateTo(0);
    } else if (title.contains('가구')) {
      _tabController.animateTo(1);
    } else if (title.contains('업적')) {
      _tabController.animateTo(2);
    }

    // 🔥 2. 필터 적용 (현재 구조에서 가능한 방식)
    setState(() {
      _selectedFilter = item.title;
    });

    // 🔥 3. 나중 확장용 (지금은 UI만이라 비워둠)
    // TODO:
    // - 실제 데이터 연결되면 여기서 리스트 필터링
    // - 또는 특정 카드 맨 위 이동
    // - 또는 상세 페이지 push
  }

  Widget _buildFurnitureContent() => const Center(child: Text("가구 도감 준비 중"));
  Widget _buildAchievementContent() => const Center(child: Text("업적 도감 준비 중"));

  Widget _buildSearchBar({String hint = "검색해보세요."}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 40,
        decoration: ShapeDecoration(color: const Color(0xFFFFFDFD), shape: RoundedRectangleBorder(side: const BorderSide(width: 1, color: Color(0x30FF7A65)), borderRadius: BorderRadius.circular(36)), shadows: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
        child: TextField(textAlignVertical: TextAlignVertical.center, decoration: InputDecoration(isDense: true, border: InputBorder.none, prefixIcon: Padding(padding: const EdgeInsets.all(10.0), child: SvgPicture.asset('assets/icons/ic_search.svg', colorFilter: const ColorFilter.mode(Color(0xFF898989), BlendMode.srcIn))), hintText: hint, hintStyle: const TextStyle(color: Color(0xFF898989), fontSize: 14))),
      ),
    );
  }
}


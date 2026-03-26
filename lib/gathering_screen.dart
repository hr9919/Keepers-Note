import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'setting_screen.dart';

class GatheringScreen extends StatefulWidget {
  // ★ 부모(MainWrapper)로부터 메뉴 열기 함수를 전달받습니다.
  final VoidCallback? openDrawer;
  const GatheringScreen({super.key, this.openDrawer});

  @override
  State<GatheringScreen> createState() => _GatheringScreenState();
}

class _GatheringScreenState extends State<GatheringScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = '강 물고기';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      // ★ 개별 Drawer는 삭제되었습니다. (MainWrapper에서 통합 관리)
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
              _buildSearchBar(hint: "채집물을 검색해보세요."),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGatheringListContent(), // 낚시 리스트
                    const Center(child: Text("새 관찰 준비 중")),
                    const Center(child: Text("곤충 채집 준비 중")),
                    const Center(child: Text("원예 준비 중")),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 앱바 (MainWrapper의 메뉴를 열도록 수정) ---
  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ★ 부모가 넘겨준 openDrawer 함수를 실행합니다.
          IconButton(
              onPressed: widget.openDrawer,
              icon: SvgPicture.asset('assets/icons/ic_menu.svg', width: 24, height: 24)
          ),
          const Text(
              '채집',
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

  // --- 상단 탭바 ---
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
          tabs: const [
            Tab(text: '낚시'),
            Tab(text: '새 관찰'),
            Tab(text: '곤충 채집'),
            Tab(text: '원예'),
          ],
        ),
      ],
    );
  }

  // --- 리스트 본문 ---
  Widget _buildGatheringListContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildFilterBarArea(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _buildGatheringCard(
                  name: '정어리',
                  level: '낚시 1레벨',
                  location: '바다',
                  price: '200원',
                  imagePath: 'assets/images/fish_sardine.png',
                  isFavorite: true,
                  icons: List.generate(2, (i) => _buildSmallIconItem('assets/icons/ic_bait.svg')),
                ),
                _buildGatheringCard(
                  name: '배스',
                  level: '낚시 1레벨',
                  location: '강',
                  price: '200원',
                  imagePath: 'assets/images/fish_bass.png',
                  isFavorite: false,
                  icons: List.generate(4, (i) => _buildSmallIconItem('assets/icons/ic_bait.svg')),
                ),
                _buildGatheringCard(
                  name: '갈치',
                  level: '낚시 1레벨',
                  location: '잔잔한 바다',
                  price: '500원',
                  imagePath: 'assets/images/fish_hairtail.png',
                  isFavorite: true,
                  icons: List.generate(4, (i) => _buildSmallIconItem('assets/icons/ic_bait.svg')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildGatheringCard({
    required String name,
    required String level,
    required String location,
    required String price,
    required String imagePath,
    required bool isFavorite,
    required List<Widget> icons,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadows: [BoxShadow(color: Colors.black.withOpacity(0.06), spreadRadius: 1.0, blurRadius: 14, offset: const Offset(0, 0))],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 88, height: 88,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.black.withOpacity(0.05))),
                child: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.asset(imagePath, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.help_outline, color: Colors.grey))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333), height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Wrap(spacing: 4, runSpacing: 4, children: [_buildSmallTag(level), if (location.isNotEmpty) _buildSmallTag(location)]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(isFavorite ? Icons.favorite : Icons.favorite_border, size: 24, color: isFavorite ? const Color(0xFFFF8E7C) : const Color(0xFFD9D9D9)),
                    ],
                  ),
                  Transform.translate(offset: const Offset(0, 14), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: icons))),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 34, height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFF7A65).withOpacity(0.5)), borderRadius: BorderRadius.circular(4)),
                        child: const Text('판매가', style: TextStyle(color: Color(0xFFFF7A65), fontSize: 9, fontWeight: FontWeight.bold, height: 1.0)),
                      ),
                      const SizedBox(width: 9),
                      Text(price, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333), height: 1.0)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallTag(String text) {
    bool isSpecial = text.contains('바다');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSpecial ? const Color(0xFFFFDED9) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSpecial ? const Color(0xFFFF7A65).withOpacity(0.2) : Colors.black.withOpacity(0.08)),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, color: isSpecial ? const Color(0xFF555655) : const Color(0xFF898989), fontWeight: isSpecial ? FontWeight.bold : FontWeight.w400)),
    );
  }

  Widget _buildFilterBarArea() {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(child: Padding(padding: const EdgeInsets.only(left: 16), child: SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, children: [_buildFilterChip('강 물고기'), _buildFilterChip('호수 물고기'), _buildFilterChip('바다 물고기')])))),
          Padding(padding: const EdgeInsets.only(right: 16, left: 8), child: Row(children: [const Text('고가순', style: TextStyle(color: Color(0xFF616161), fontSize: 12, fontWeight: FontWeight.w500)), const SizedBox(width: 2), const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF616161))])),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedFilter == label;
    return Theme(
      data: Theme.of(context).copyWith(splashColor: Colors.transparent, highlightColor: Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (bool selected) => setState(() => _selectedFilter = label),
          labelStyle: TextStyle(color: isSelected ? const Color(0xFF555655) : const Color(0xFF333333), fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w400),
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFFFDED9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36), side: BorderSide(color: isSelected ? const Color(0xFFFF7A65).withOpacity(0.2) : Colors.black.withOpacity(0.08))),
          visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: -2),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          showCheckmark: false,
        ),
      ),
    );
  }

  Widget _buildSmallIconItem(String imagePath) {
    return Container(
      width: 32, height: 32, margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(color: const Color(0xC6FFF8E7), borderRadius: BorderRadius.circular(4)),
      child: Center(child: Padding(padding: const EdgeInsets.all(4.0), child: SvgPicture.asset(imagePath, fit: BoxFit.contain))),
    );
  }

  Widget _buildSearchBar({required String hint}) {
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
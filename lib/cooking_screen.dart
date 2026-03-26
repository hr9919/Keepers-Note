import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'setting_screen.dart';

class CookingScreen extends StatefulWidget {
  // ★ 부모(MainWrapper)가 넘겨주는 메뉴 열기 함수를 받습니다.
  final VoidCallback? openDrawer;
  const CookingScreen({super.key, this.openDrawer});

  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = '일반 레시피';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      // ★ drawer 속성은 MainWrapper로 이동했으므로 삭제합니다.
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
              _buildSearchBar(hint: "요리 레시피를 검색해보세요."),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCookingListContent(),
                    _buildCookingListContent(),
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
          // ★ 부모로부터 받은 openDrawer 함수를 바로 사용합니다.
          IconButton(
              onPressed: widget.openDrawer,
              icon: SvgPicture.asset('assets/icons/ic_menu.svg', width: 24, height: 24)
          ),
          const Text('요리', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'SF Pro')),
          IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
              icon: SvgPicture.asset('assets/icons/ic_settings.svg', width: 24, height: 24)
          ),
        ],
      ),
    );
  }

  // --- 재료 아이콘 위젯 ---
  Widget _buildIngredientItem(String imagePath) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
          color: const Color(0xC6FFF8E7),
          borderRadius: BorderRadius.circular(4)
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 16, color: Colors.grey),
          ),
        ),
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
          tabs: const [Tab(text: '일상 요리'), Tab(text: '시즌 요리')],
        ),
      ],
    );
  }

  Widget _buildCookingListContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildFilterBarArea(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _buildCookingCard(
                  name: '베지 샐러드',
                  level: '요리 1레벨',
                  hiddenStatus: '히든 레시피 없음',
                  price: '200원',
                  imagePath: 'assets/images/food_veggie_salad.png',
                  isFavorite: true,
                  ingredients: List.generate(2, (i) => _buildIngredientItem('assets/images/icon_veg_any.png')),
                ),
                _buildCookingCard(
                  name: '믹스드 잼',
                  level: '요리 1레벨',
                  hiddenStatus: '히든 레시피 있음',
                  price: '200원',
                  imagePath: 'assets/images/jam_mixed.png',
                  isFavorite: false,
                  ingredients: List.generate(4, (i) => _buildIngredientItem('assets/images/icon_fruit_any.png')),
                ),
                _buildCookingCard(
                  name: '버섯 구이',
                  level: '요리 1레벨',
                  hiddenStatus: '히든 레시피 있음',
                  price: '200원',
                  imagePath: 'assets/images/food_grilled_mushroom.png',
                  isFavorite: false,
                  ingredients: List.generate(4, (i) => _buildIngredientItem('assets/images/icon_mushroom_any.png')),
                ),
                _buildCookingCard(
                  name: '버섯 파이',
                  level: '요리 1레벨',
                  hiddenStatus: '히든 레시피 있음',
                  price: '200원',
                  imagePath: 'assets/images/food_mushroom_pie.png',
                  isFavorite: true,
                  ingredients: [
                    ...List.generate(2, (i) => _buildIngredientItem('assets/images/icon_mushroom_any.png')),
                    _buildIngredientItem('assets/images/ingredient_wheat.png'),
                    _buildIngredientItem('assets/images/ingredient_egg.png'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildFilterBarArea() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildFilterChip('일반 레시피'),
                    _buildFilterChip('히든 레시피'),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  alignment: const Alignment(0, -0.07),
                  height: 48,
                  child: const Text('고가순', style: TextStyle(color: Color(0xFF616161), fontSize: 12, fontFamily: 'SF Pro', fontWeight: FontWeight.w500, height: 1.0)),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF616161)),
              ],
            ),
          ),
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
          labelStyle: TextStyle(color: isSelected ? const Color(0xFF555655) : const Color(0xFF333333), fontSize: 12, height: 1.0, fontFamily: 'SF Pro', fontWeight: isSelected ? FontWeight.bold : FontWeight.w400),
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFFFDED9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36), side: BorderSide(color: isSelected ? const Color(0xFFFF7A65).withOpacity(0.2) : Colors.black.withOpacity(0.08), width: 1.0)),
          visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: -2),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          showCheckmark: false,
        ),
      ),
    );
  }

  Widget _buildCookingCard({
    required String name,
    required String level,
    required String hiddenStatus,
    required String price,
    required String imagePath,
    required bool isFavorite,
    required List<Widget> ingredients,
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
                child: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.asset(imagePath, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.restaurant_menu, color: Colors.grey))),
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
                            Wrap(spacing: 4, runSpacing: 4, children: [_buildSmallTag(level), _buildSmallTag(hiddenStatus)]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(isFavorite ? Icons.favorite : Icons.favorite_border, size: 24, color: isFavorite ? const Color(0xFFFF8E7C) : const Color(0xFFD9D9D9)),
                    ],
                  ),
                  Transform.translate(offset: const Offset(0, 14), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ingredients))),
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
    bool isHiddenActive = text.contains('있음');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isHiddenActive ? const Color(0xFFFFDED9) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isHiddenActive ? const Color(0xFFFF7A65).withOpacity(0.2) : Colors.black.withOpacity(0.08)),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, color: isHiddenActive ? const Color(0xFF555655) : const Color(0xFF898989), fontWeight: isHiddenActive ? FontWeight.bold : FontWeight.w400)),
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
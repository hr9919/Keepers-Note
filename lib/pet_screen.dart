import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'setting_screen.dart';

class PetScreen extends StatefulWidget {
  // ★ 부모(MainWrapper)로부터 메뉴 열기 함수를 전달받습니다.
  final VoidCallback? openDrawer;
  const PetScreen({super.key, this.openDrawer});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 필터 선택 상태 관리
  String _selectedType = '단색 고양이';
  String _selectedColor = '흰색';

  // 드롭 업 메뉴 열림 상태 관리
  bool _isMenuOpen = false;

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
      // ★ 개별 Drawer는 삭제되었습니다. (MainWrapper에서 통합 관리)
      floatingActionButton: _buildFabWithMenu(),
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
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPetGridContent(), // 고양이 리스트
                    const Center(child: Text("강아지 페이지 준비 중")),
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
              '동물',
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

  // --- 기존 코드 유지 (FAB, 필터, 그리드 등) ---
  Widget _buildFabWithMenu() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isMenuOpen)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isMenuOpen ? 1.0 : 0.0,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 160,
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  shadows: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    _buildMenuItem('내 애완동물 관리', () => setState(() => _isMenuOpen = false)),
                    Container(height: 1, color: const Color(0xFFEEEEEE), margin: const EdgeInsets.symmetric(horizontal: 12)),
                    _buildMenuItem('새 애완동물 추가', () => setState(() => _isMenuOpen = false)),
                  ],
                ),
              ),
            ),
          FloatingActionButton(
            onPressed: () => setState(() => _isMenuOpen = !_isMenuOpen),
            backgroundColor: const Color(0xFFFF8E7C),
            shape: const CircleBorder(),
            elevation: 4,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _isMenuOpen ? 0.125 : 0,
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF636363), fontFamily: 'SF Pro')),
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
          indicatorPadding: const EdgeInsets.symmetric(horizontal: -20),
          tabs: const [Tab(text: '고양이'), Tab(text: '강아지')],
        ),
      ],
    );
  }

  Widget _buildPetGridContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTwoStepFilterArea(),
          const SizedBox(height: 16),
          _buildPetSectionTitle('올화이트'),
          _buildPetGrid(['assets/images/cat_white.png'], favoriteIndex: 0),
          const SizedBox(height: 24),
          _buildPetSectionTitle('올블랙'),
          _buildPetGrid(['assets/images/cat_black_1.png', 'assets/images/cat_black_2.png'], favoriteIndex: -1),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildTwoStepFilterArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _buildFilterRow('종류', ['단색 고양이', '얼룩 고양이', '샴 고양이'], true),
          const SizedBox(height: 4),
          _buildFilterRow('색', ['흰색', '검정색'], false),
        ],
      ),
    );
  }

  Widget _buildFilterRow(String label, List<String> items, bool isTypeFilter) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 40, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF555555), fontFamily: 'SF Pro'))),
        Expanded(
          child: SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) => _buildFilterChip(items[index], isTypeFilter: isTypeFilter),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, {required bool isTypeFilter}) {
    bool isSelected = isTypeFilter ? (_selectedType == label) : (_selectedColor == label);
    const Color typeBg = Color(0xFFFFDED9);
    const Color typeText = Color(0xFF555655);
    final Color typeBorder = const Color(0xFFFF7A65).withOpacity(0.2);
    const Color colorBg = Color(0xFFFFE2A5);
    const Color colorText = Color(0xFF555655);
    final Color colorBorder = const Color(0xFFFFCC5E).withOpacity(0.4);
    const Color unselectedBg = Colors.white;
    final Color unselectedBorder = Color(0xFFE0E0E0).withOpacity(0.5);

    return Theme(
      data: Theme.of(context).copyWith(splashColor: Colors.transparent, highlightColor: Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Padding(padding: EdgeInsets.only(bottom: isTypeFilter ? 0 : 2.0), child: Text(label)),
          selected: isSelected,
          onSelected: (bool selected) => setState(() { if (isTypeFilter) _selectedType = label; else _selectedColor = label; }),
          labelStyle: TextStyle(color: isSelected ? (isTypeFilter ? typeText : colorText) : const Color(0xFF636363), fontSize: 12, height: 1.0, fontFamily: 'SF Pro', fontWeight: isSelected ? FontWeight.bold : FontWeight.w400),
          backgroundColor: unselectedBg,
          selectedColor: isTypeFilter ? typeBg : colorBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36), side: BorderSide(color: isSelected ? (isTypeFilter ? typeBorder : colorBorder) : unselectedBorder, width: 1.0)),
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          showCheckmark: false,
        ),
      ),
    );
  }

  Widget _buildPetSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(left: 18, bottom: 12), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black, fontFamily: 'SF Pro')));
  }

  Widget _buildPetGrid(List<String> images, {int favoriteIndex = -1}) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
      itemCount: images.length,
      itemBuilder: (context, index) => _buildPetCard(imagePath: images[index], isFavorite: index == favoriteIndex),
    );
  }

  Widget _buildPetCard({required String imagePath, required bool isFavorite}) {
    return Container(
      decoration: ShapeDecoration(color: Colors.white.withOpacity(0.9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), shadows: [BoxShadow(color: Colors.black.withOpacity(0.06), spreadRadius: 1.0, blurRadius: 14, offset: const Offset(0, 0))]),
      child: Stack(
        children: [
          Padding(padding: const EdgeInsets.all(14.0), child: Center(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset(imagePath, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.pets, color: Colors.grey, size: 24))))),
          Positioned(top: 8, right: 8, child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, size: 24, color: isFavorite ? const Color(0xFFFF8E7C) : const Color(0xFFD9D9D9))),
        ],
      ),
    );
  }
}
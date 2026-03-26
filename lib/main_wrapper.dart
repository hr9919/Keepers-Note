import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'home_screen.dart';
import 'encyclopedia_screen.dart';
import 'cooking_screen.dart';
import 'gathering_screen.dart';
import 'pet_screen.dart';
import 'setting_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onMenuSelect(int index) {
    Navigator.pop(context);
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      HomeScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
      EncyclopediaScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
      CookingScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
      GatheringScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
      PetScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
    ];

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: _buildCommonDrawer(), // ★ 여기서 메뉴를 부릅니다.
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // --- 공통 햄버거 메뉴 디자인 ---
  Widget _buildCommonDrawer() {
    // ★ 시스템 바 높이를 가져옵니다.
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Drawer(
      child: Column(
        children: [
          // 1. 헤더 영역 (프로필, 배경, 수정버튼)
          Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(left: 20, top: 40, bottom: 20),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/profile_header_bg.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/profile.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text("해림 님", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white, fontFamily: 'SF Pro')),
                    Text("UID: 0000000", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9), fontFamily: 'SF Pro')),
                    Text("오늘도 타운에서 즐거운 시간 보내세요!", style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7), fontFamily: 'SF Pro')),
                  ],
                ),
              ),
              Positioned(
                bottom: 12, right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),

          // 2. 메뉴 아이템 리스트
          _buildDrawerItem(Icons.home_rounded, '홈', () => _onMenuSelect(0)),
          _buildDrawerItem(Icons.auto_stories_rounded, '아이템 도감', () => _onMenuSelect(1)),
          _buildDrawerItem(Icons.restaurant_menu_rounded, '요리 레시피', () => _onMenuSelect(2)),
          _buildDrawerItem(Icons.backpack_rounded, '채집 도감', () => _onMenuSelect(3)),
          _buildDrawerItem(Icons.pets_rounded, '동물 도감', () => _onMenuSelect(4)),

          const Spacer(),
          const Divider(height: 1),

          // 3. 설정 버튼
          _buildDrawerItem(Icons.settings_rounded, '설정', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
          }),

          // ★ 핵심: 시스템 바 높이만큼 바닥 여백 추가 (가려짐 방지)
          SizedBox(height: bottomPadding > 0 ? bottomPadding : 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF636363), size: 22),
      title: Text(title, style: const TextStyle(color: Color(0xFF636363), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'SF Pro')),
      onTap: onTap,
    );
  }

  // --- 하단 내비게이션 바 디자인 ---
  Widget _buildBottomNavigationBar() {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 10),
      decoration: const ShapeDecoration(
        color: Color(0xEAFFFDF9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
        shadows: [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -5))],
      ),
      child: Container(
        height: 85,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, 'home', '홈'),
            _buildNavItem(1, 'book', '도감'),
            _buildNavItem(2, 'cook', '요리'),
            _buildNavItem(3, 'fish', '채집'),
            _buildNavItem(4, 'pet', '동물'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String fileName, String label) {
    bool isSelected = _selectedIndex == index;
    String assetPath = isSelected ? 'assets/icons/ic_${fileName}_active.svg' : 'assets/icons/ic_$fileName.svg';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(40),
          border: isSelected ? Border.all(color: Colors.black.withOpacity(0.1), width: 0.8) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(assetPath, width: 24, height: 24, colorFilter: isSelected ? null : const ColorFilter.mode(Colors.black38, BlendMode.srcIn)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.black : Colors.black38, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontFamily: 'SF Pro')),
          ],
        ),
      ),
    );
  }
}
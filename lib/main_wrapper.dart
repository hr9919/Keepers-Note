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
  // ★ Scaffold 제어용 GlobalKey (Drawer 열기용)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // --- 메뉴에서 탭 이동을 시켜주는 함수 ---
  void _onMenuSelect(int index) {
    Navigator.pop(context); // 메뉴 닫기
    setState(() {
      _selectedIndex = index; // 해당 탭으로 변경
    });
  }

  @override
  Widget build(BuildContext context) {
    // 자식들에게 메뉴를 열 수 있는 함수를 전달합니다.
    final List<Widget> _pages = [
      HomeScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
      EncyclopediaScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
      CookingScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
      GatheringScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
      PetScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
    ];

    return Scaffold(
      key: _scaffoldKey, // ★ 키 연결
      extendBody: true,
      drawer: _buildCommonDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // --- 공통 햄버거 메뉴 디자인 (왼쪽 정렬 커스텀 레이아웃) ---
  Widget _buildCommonDrawer() {
    return Drawer(
      child: Column(
        children: [
          // ★ Stack을 사용하여 배경 위에 버튼을 올립니다.
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
                    // 1. 프로필 사진
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                        image: const DecorationImage(
                          image: AssetImage('assets/images/profile.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 2. 텍스트 영역
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "해림 님",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'SF Pro',
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "UID: 0000000",
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "오늘도 타운에서 즐거운 시간 보내세요!",
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ★ 3. 배경 오른쪽 아래 수정 버튼 추가
              Positioned(
                bottom: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // 메뉴 닫기
                    // ★ 나중에 여기서 프로필 수정 페이지로 이동하게 만듭니다.
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                    print("프로필 수정 버튼 클릭됨!");
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3), // 배경에 묻히지 않게 반투명 검정
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                    ),
                    child: const Icon(
                      Icons.edit_rounded, // 연필 모양 아이콘
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ... 이하 메뉴 아이템들은 기존과 동일하게 유지 ...
          _buildDrawerItem(Icons.home_rounded, '홈', () => _onMenuSelect(0)),
          _buildDrawerItem(Icons.auto_stories_rounded, '아이템 도감', () => _onMenuSelect(1)),
          _buildDrawerItem(Icons.restaurant_menu_rounded, '요리 레시피', () => _onMenuSelect(2)),
          _buildDrawerItem(Icons.backpack_rounded, '채집 도감', () => _onMenuSelect(3)),
          _buildDrawerItem(Icons.pets_rounded, '동물 도감', () => _onMenuSelect(4)),
          const Spacer(),
          const Divider(height: 1),
          _buildDrawerItem(Icons.settings_rounded, '설정', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
          }),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF636363), size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF636363),
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: 'SF Pro',
        ),
      ),
      onTap: onTap,
    );
  }

  // --- 하단 내비게이션 바 디자인 ---
  Widget _buildBottomNavigationBar() {
    return Container(
      width: double.infinity,
      height: 90,
      decoration: const ShapeDecoration(
        color: Color(0xEAFFFDF9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        shadows: [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -5))],
      ),
      child: SafeArea(
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
    String assetPath = isSelected
        ? 'assets/icons/ic_${fileName}_active.svg'
        : 'assets/icons/ic_$fileName.svg';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(40),
          border: isSelected ? Border.all(color: Colors.black.withOpacity(0.1), width: 0.8) : null,
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
                assetPath,
                width: 24,
                height: 24,
                colorFilter: isSelected ? null : const ColorFilter.mode(Colors.black38, BlendMode.srcIn)
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.black : Colors.black38,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'SF Pro',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
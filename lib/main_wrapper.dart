import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'home_screen.dart';
import 'encyclopedia_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0; // 현재 선택된 하단 내비게이션 인덱스

  // ★ 하단 내비게이션 바와 연결될 페이지 리스트
  final List<Widget> _pages = [
    const HomeScreen(),       // 0: 홈 (기존 코드를 Scaffold에서 Container/Column으로 빼서 가져오면 더 좋습니다)
    const EncyclopediaScreen(), // 1: 도감
    const Center(child: Text('요리 페이지')), // 2
    const Center(child: Text('채집 페이지')), // 3
    const Center(child: Text('동물 페이지')), // 4
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody를 true로 주어야 내비게이션 바 뒤로 배경이 비쳐 보입니다.
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // --- 하단 내비게이션 바 (해림 님이 만드신 스타일 그대로 유지) ---
  Widget _buildBottomNavigationBar() {
    return Container(
      width: double.infinity,
      height: 90,
      decoration: const ShapeDecoration(
        color: Color(0xEAFFFDF9), // 약간 투명한 베이지
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        shadows: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, -5),
          )
        ],
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
      onTap: () {
        setState(() {
          _selectedIndex = index; // ★ 여기서 페이지가 바뀝니다.
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(40),
          border: isSelected
              ? Border.all(color: Colors.black.withOpacity(0.1), width: 0.8)
              : null,
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
              // active 아이콘은 원본 색상 유지, 일반 아이콘은 회색 필터
              colorFilter: isSelected
                  ? null
                  : const ColorFilter.mode(Colors.black38, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.black : Colors.black38,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
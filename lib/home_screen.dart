import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'setting_screen.dart';

class HomeScreen extends StatelessWidget {
  // ★ 부모(MainWrapper)가 넘겨주는 메뉴 열기 함수를 받습니다.
  final VoidCallback? openDrawer;
  const HomeScreen({super.key, this.openDrawer});

  // 공통 카드 스타일 정의
  static const List<BoxShadow> _kCommonShadow = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 20,
      offset: Offset(0, 0),
      spreadRadius: 1,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      // ★ drawer 코드는 삭제됨 (MainWrapper가 통합 관리)
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
              _buildSearchBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildSectionTitle('날씨 정보'),
                      const SizedBox(height: 8),
                      _buildWeatherCard(),
                      const SizedBox(height: 32),
                      _buildTodoSection(),
                      const SizedBox(height: 32),
                      _buildMapSection(),
                      const SizedBox(height: 32),
                      _buildEventSection(),
                      const SizedBox(height: 120),
                    ],
                  ),
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
              onPressed: openDrawer,
              icon: SvgPicture.asset('assets/icons/ic_menu.svg', width: 24, height: 24)
          ),
          const Text(
              "Keeper's Note",
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

  // --- 검색창 ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 40,
        decoration: ShapeDecoration(
          color: const Color(0xFFFFFDFD),
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0x30FF7A65)),
            borderRadius: BorderRadius.circular(36),
          ),
          shadows: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: TextField(
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(10.0),
              child: SvgPicture.asset(
                'assets/icons/ic_search.svg',
                colorFilter: const ColorFilter.mode(Color(0xFF898989), BlendMode.srcIn),
              ),
            ),
            hintText: '아이템을 검색해보세요.',
            hintStyle: const TextStyle(color: Color(0xFF898989), fontSize: 14, fontFamily: 'SF Pro'),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  // --- 섹션 타이틀 ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'SF Pro', fontWeight: FontWeight.w600, height: 1.0),
      ),
    );
  }

  // --- 1. 날씨 카드 ---
  Widget _buildWeatherCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      height: 120,
      decoration: ShapeDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadows: _kCommonShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(alignment: Alignment.centerLeft, child: _buildWeatherTimeline()),
                const Center(child: Text('현재 날씨에는 특별한 이벤트가 없습니다.', style: TextStyle(fontSize: 11, fontFamily: 'SF Pro'))),
              ],
            ),
          ),
          const SizedBox(width: 20),
          _buildWeeklyColumn(),
        ],
      ),
    );
  }

  Widget _buildWeatherTimeline() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildTimeItem('현재 (아침)', true),
          _buildTimeItem('낮', false),
          _buildTimeItem('밤', false),
          _buildTimeItem('내일 새벽', false),
          _buildTimeItem('내일 아침', false),
        ],
      ),
    );
  }

  Widget _buildTimeItem(String label, bool isCurrent) {
    return Container(
      width: 50,
      margin: const EdgeInsets.only(right: 6),
      child: Column(
        children: [
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400, fontFamily: 'SF Pro')),
          const SizedBox(height: 6),
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.wb_sunny_rounded, size: 16, color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyColumn() {
    final days = [
      {'day': '수 (내일)', 'icon': true},
      {'day': '목', 'icon': true},
      {'day': '금', 'icon': true},
      {'day': '토', 'icon': true},
      {'day': '일', 'icon': false}
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: days.map((data) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(data['day'] as String, style: const TextStyle(fontSize: 9, fontFamily: 'SF Pro')),
            const SizedBox(width: 6),
            Icon(Icons.circle, size: 8, color: (data['icon'] as bool) ? Colors.black26 : Colors.transparent),
          ],
        ),
      )).toList(),
    );
  }

  // --- 2. 오늘의 할 일 섹션 ---
  Widget _buildTodoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('오늘의 할 일'),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.only(left: 25, top: 20, bottom: 20, right: 8),
          decoration: ShapeDecoration(
            color: Colors.white.withOpacity(0.85),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            shadows: _kCommonShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildTodoItem('가게 판매 품목 확인', true),
                    const SizedBox(height: 10),
                    _buildTodoItem('그자리 참나무 파밍', false),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodoItem(String task, bool isDone) {
    return Row(
      children: [
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: isDone ? const Color(0x2890CDFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(width: 1, color: const Color(0xFF90CDFF)),
          ),
          child: isDone ? const Icon(Icons.check, size: 12, color: Color(0xFF90CDFF)) : null,
        ),
        const SizedBox(width: 10),
        Text(task, style: TextStyle(fontSize: 14, fontFamily: 'SF Pro', decoration: isDone ? TextDecoration.lineThrough : null)),
      ],
    );
  }

  // --- 3. 지도 섹션 ---
  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('지도'),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            height: 227,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              shadows: _kCommonShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Positioned.fill(child: Image.asset('assets/images/map_preview.png', fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[200]))),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Image.asset('assets/icons/ic_maximize.png', width: 54, height: 54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- 4. 이벤트 섹션 ---
  Widget _buildEventSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('진행중인 이벤트'),
        const SizedBox(height: 12),
        SizedBox(
          height: 185,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEventCard('assets/images/event_1.png', 143, 144),
                const SizedBox(width: 12),
                _buildEventCard('assets/images/event_2.png', 143, 179),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(String assetPath, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 15, offset: Offset(0, 0), spreadRadius: 1)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Icon(Icons.image, color: Colors.grey)),
        ),
      ),
    );
  }
}
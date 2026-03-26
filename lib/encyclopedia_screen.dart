import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class EncyclopediaScreen extends StatefulWidget {
  const EncyclopediaScreen({super.key}); // 생성자에 const가 있어도 호출할 때 안 붙이면 됨!

  @override
  State<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends State<EncyclopediaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 배경 이미지를 위해 투명화
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
              _buildCustomAppBar(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOutfitContent(),
                    const Center(child: Text('가구 도감 준비 중')),
                    const Center(child: Text('업적 도감 준비 중')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: () {}, icon: SvgPicture.asset('assets/icons/ic_menu.svg', width: 24, height: 24)),
          const Text('도감', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          IconButton(onPressed: () {}, icon: SvgPicture.asset('assets/icons/ic_settings.svg', width: 24, height: 24)),
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildSearchBar(), // 이제 아래에 실제 코드가 들어갔어요!
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 15),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('숲의 주문', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          // 여기에 GridView 추가 예정!
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // --- HomeScreen에서 쓰던 검색창 코드 그대로 복구 ---
  Widget _buildSearchBar() {
    const Color mainColor = Color(0xFFFF7A65);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        height: 40,
        decoration: ShapeDecoration(
          color: const Color(0xFFFFFDFD),
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0x30FF7A65)),
            borderRadius: BorderRadius.circular(36),
          ),
          shadows: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
              spreadRadius: -1,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [mainColor.withOpacity(0.05), Colors.transparent],
                    stops: const [0.0, 0.2],
                  ),
                ),
              ),
            ),
            Center(
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
                  hintText: '옷을 검색해보세요.',
                  hintStyle: const TextStyle(color: Color(0xFF898989), fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
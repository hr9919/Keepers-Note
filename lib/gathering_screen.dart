import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import 'setting_screen.dart';

class FishItem {
  final String id;
  final String name;
  final String image;
  final String location;
  final String? timeOfDay;
  final int? level;

  FishItem({
    required this.id,
    required this.name,
    required this.image,
    required this.location,
    this.timeOfDay,
    this.level,
  });

  factory FishItem.fromJson(Map<String, dynamic> json) {
    return FishItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      timeOfDay: json['timeOfDay']?.toString(),
      level: json['level'] as int?,
    );
  }
}

class GatheringScreen extends StatefulWidget {
  final VoidCallback? openDrawer;

  const GatheringScreen({super.key, this.openDrawer});

  @override
  State<GatheringScreen> createState() => _GatheringScreenState();
}

class _GatheringScreenState extends State<GatheringScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = '전체';
  String _searchQuery = '';

  bool _isLoading = true;
  String? _errorMessage;

  List<FishItem> _fishList = [];
  List<FishItem> _visibleFishList = [];

  final String _fishApiUrl = 'http://161.33.30.40:8080/api/fish';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _fetchFish();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFish() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(_fishApiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));

        final fish = data
            .map((e) => FishItem.fromJson(e as Map<String, dynamic>))
            .toList();

        fish.sort((a, b) => _displayName(a).compareTo(_displayName(b)));

        setState(() {
          _fishList = fish;
          _isLoading = false;
        });

        _applyFilters();
      } else {
        setState(() {
          _errorMessage = '물고기 데이터를 불러오지 못했어요. (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '서버 연결에 실패했어요.\n$e';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _searchQuery = _searchController.text.trim().toLowerCase();
    _applyFilters();
  }

  void _onFilterSelected(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _applyFilters();
  }

  void _applyFilters() {
    List<FishItem> filtered = List.from(_fishList);

    if (_selectedFilter != '전체') {
      filtered = filtered.where((fish) {
        return _matchesFilter(fish, _selectedFilter);
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((fish) {
        final name = fish.name.toLowerCase();
        final id = fish.id.toLowerCase();
        final location = fish.location.toLowerCase();
        final time = (fish.timeOfDay ?? '').toLowerCase();

        return name.contains(_searchQuery) ||
            id.contains(_searchQuery) ||
            location.contains(_searchQuery) ||
            time.contains(_searchQuery);
      }).toList();
    }

    setState(() {
      _visibleFishList = filtered;
    });
  }

  bool _matchesFilter(FishItem fish, String filter) {
    final location = fish.location.toLowerCase();

    switch (filter) {
      case '강 물고기':
        return location.contains('river');
      case '호수 물고기':
        return location.contains('lake');
      case '바다 물고기':
        return location.contains('sea') ||
            location.contains('ocean') ||
            location.contains('fishing');
      default:
        return true;
    }
  }

  String _displayName(FishItem fish) {
    if (fish.name.trim().isNotEmpty) {
      return fish.name;
    }
    return fish.id;
  }

  String _imageAssetPath(String dbPath) {
    if (dbPath.startsWith('assets/')) return dbPath;
    return 'assets/$dbPath';
  }

  String _locationLabel(String location) {
    final lower = location.toLowerCase();

    if (lower.contains('river')) return '강';
    if (lower.contains('lake')) return '호수';
    if (lower.contains('sea') || lower.contains('ocean') || lower.contains('fishing')) {
      return '바다';
    }
    return location;
  }

  String _timeLabel(String? timeOfDay) {
    if (timeOfDay == null || timeOfDay.trim().isEmpty) {
      return '';
    }
    return timeOfDay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    _buildFishingTabContent(),
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

  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: widget.openDrawer,
            icon: SvgPicture.asset(
              'assets/icons/ic_menu.svg',
              width: 24,
              height: 24,
            ),
          ),
          const Text(
            '채집',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'SF Pro',
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            icon: SvgPicture.asset(
              'assets/icons/ic_settings.svg',
              width: 24,
              height: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: double.infinity,
          height: 0.7,
          color: const Color(0xFFC4C4C4),
        ),
        TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: const Color(0xFF898989),
          labelStyle: const TextStyle(
            fontSize: 16,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
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

  Widget _buildFishingTabContent() {
    return Column(
      children: [
        _buildFilterBarArea(),
        Expanded(
          child: _buildFishingListArea(),
        ),
      ],
    );
  }

  Widget _buildFishingListArea() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _fetchFish,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_visibleFishList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchFish,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text(
                '검색 결과가 없어요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFish,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              ..._visibleFishList.map(
                    (fish) => _buildGatheringCard(
                  name: _displayName(fish),
                  level: fish.level != null ? '낚시 ${fish.level}레벨' : '낚시',
                  timeInfo: _timeLabel(fish.timeOfDay),
                  price: '-',
                  imagePath: _imageAssetPath(fish.image),
                  isFavorite: false,
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGatheringCard({
    required String name,
    required String level,
    required String timeInfo,
    required String price,
    required String imagePath,
    required bool isFavorite,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 1.0,
            blurRadius: 14,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.05),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const Icon(
                      Icons.help_outline,
                      color: Colors.grey,
                    ),
                  ),
                ),
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
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                _buildSmallTag(level),
                                if (timeInfo.isNotEmpty)
                                  _buildSmallTag(timeInfo),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 24,
                        color: isFavorite
                            ? const Color(0xFFFF8E7C)
                            : const Color(0xFFD9D9D9),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 34,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFFF7A65).withOpacity(0.5),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '판매가',
                          style: TextStyle(
                            color: Color(0xFFFF7A65),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                          height: 1.0,
                        ),
                      ),
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
    final lower = text.toLowerCase();

    final isAllDay = lower.contains('all day');
    final isEveningOrNight =
        lower.contains('evening') || lower.contains('night');
    final isAfternoonOrMorning =
        lower.contains('afternoon') || lower.contains('morning');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAllDay
            ? const Color(0xFFFFDED9) // 🟧 주황
            : isEveningOrNight
            ? const Color(0xFFE6D9FF) // 🟣 연보라
            : isAfternoonOrMorning
            ? const Color(0xFFFFF3C7) // 🟡 노랑
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAllDay
              ? const Color(0xFFFF7A65).withOpacity(0.2)
              : isEveningOrNight
              ? const Color(0xFF9C7BFF).withOpacity(0.3)
              : isAfternoonOrMorning
              ? const Color(0xFFFFC94D).withOpacity(0.3)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: isAllDay
              ? const Color(0xFF555655)
              : isEveningOrNight
              ? const Color(0xFF5A3FD6) // 보라 텍스트
              : isAfternoonOrMorning
              ? const Color(0xFF8A6D00)
              : const Color(0xFF898989),
          fontWeight:
          (isAllDay || isEveningOrNight || isAfternoonOrMorning)
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildFilterBarArea() {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('전체'),
                    _buildFilterChip('강 물고기'),
                    _buildFilterChip('호수 물고기'),
                    _buildFilterChip('바다 물고기'),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16, left: 8),
            child: Row(
              children: [
                Text(
                  '이름순',
                  style: TextStyle(
                    color: Color(0xFF616161),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: Color(0xFF616161),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => _onFilterSelected(label),
          labelStyle: TextStyle(
            color: isSelected
                ? const Color(0xFF555655)
                : const Color(0xFF333333),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
          ),
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFFFDED9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(36),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFFFF7A65).withOpacity(0.2)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: -2),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          showCheckmark: false,
        ),
      ),
    );
  }

  Widget _buildSmallInfoItem(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: const Color(0xC6FFF8E7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF555555),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSearchBar({required String hint}) {
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
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(10.0),
              child: SvgPicture.asset(
                'assets/icons/ic_search.svg',
                colorFilter: const ColorFilter.mode(
                  Color(0xFF898989),
                  BlendMode.srcIn,
                ),
              ),
            ),
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF898989),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
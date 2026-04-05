import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'setting_screen.dart';

// 새 관찰 데이터 모델
class BirdItem {
  final String id;
  final String nameKo;
  final String image;
  final String location;
  final String availableTime;
  final String weather;
  final int level;
  final List<int> prices;

  BirdItem({
    required this.id, required this.nameKo, required this.image,
    required this.location, required this.availableTime, required this.weather,
    required this.level, required this.prices,
  });

  factory BirdItem.fromJson(Map<String, dynamic> json) {
    return BirdItem(
      id: json['id']?.toString() ?? '',
      // nameKo와 name_ko 모두 대응하도록 수정
      nameKo: json['nameKo'] ?? json['name_ko'] ?? '',
      image: json['image'] ?? '',
      location: json['location'] ?? '',
      availableTime: json['availableTime'] ?? json['available_time'] ?? '',
      weather: json['weather'] ?? '',
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      prices: [
        // price1, price2... 형식 대응
        int.tryParse(json['price1']?.toString() ?? json['price_1']?.toString() ?? '0') ?? 0,
        int.tryParse(json['price2']?.toString() ?? json['price_2']?.toString() ?? '0') ?? 0,
        int.tryParse(json['price3']?.toString() ?? json['price_3']?.toString() ?? '0') ?? 0,
        int.tryParse(json['price4']?.toString() ?? json['price_4']?.toString() ?? '0') ?? 0,
        int.tryParse(json['price5']?.toString() ?? json['price_5']?.toString() ?? '0') ?? 0,
      ],
    );
  }
}

// 원예 데이터 모델
class PlantItem {
  final String id;
  final String nameKo;
  final String image;
  final String location;
  final String availableTime;
  final String weather;
  final int level;
  final List<int> prices;

  PlantItem({
    required this.id, required this.nameKo, required this.image,
    required this.location, required this.availableTime, required this.weather,
    required this.level, required this.prices,
  });

  factory PlantItem.fromJson(Map<String, dynamic> json) {
    return PlantItem(
      id: json['id']?.toString() ?? '',
      nameKo: json['nameKo'] ?? json['name_ko'] ?? '',
      image: json['image'] ?? '',
      location: json['location'] ?? '',
      availableTime: json['availableTime'] ?? json['available_time'] ?? '',
      weather: json['weather'] ?? '',
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      prices: [
        int.tryParse(json['price1']?.toString() ?? json['price_1']?.toString() ?? '0') ?? 0,
        int.tryParse(json['price2']?.toString() ?? json['price_2']?.toString() ?? '0') ?? 0,
        int.tryParse(json['price3']?.toString() ?? json['price_3']?.toString() ?? '0') ?? 0,
        int.tryParse(json['price4']?.toString() ?? json['price_4']?.toString() ?? '0') ?? 0,
        int.tryParse(json['price5']?.toString() ?? json['price_5']?.toString() ?? '0') ?? 0,
      ],
    );
  }
}

class InsectItem {
  final String id;
  final String name;
  final String nameKo;
  final String image;
  final String location;
  final String availableTime;
  final int level;
  final List<int> prices;

  InsectItem({
    required this.id,
    required this.name,
    required this.nameKo,
    required this.image,
    required this.location,
    required this.availableTime,
    required this.level,
    required this.prices,
  });

  factory InsectItem.fromJson(Map<String, dynamic> json) {
    // 헬퍼 함수: price1 또는 price_1 모두 대응 가능하도록 설계
    int parsePrice(dynamic p1, dynamic p2) {
      return int.tryParse((p1 ?? p2 ?? '0').toString()) ?? 0;
    }

    return InsectItem(
      id: (json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      nameKo: json['name_ko'] ?? json['nameKo'] ?? '',
      image: json['image'] ?? '',
      location: json['location'] ?? '',
      availableTime: (json['available_time'] ?? json['availableTime'] ?? '').toString(),
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      prices: [
        parsePrice(json['price1'], json['price_1']),
        parsePrice(json['price2'], json['price_2']),
        parsePrice(json['price3'], json['price_3']),
        parsePrice(json['price4'], json['price_4']),
        parsePrice(json['price5'], json['price_5']),
      ],
    );
  }
}

class FishItem {
  final String id;
  final String name;
  final String? nameKo;
  final String image;
  final String location;
  final String? availableTime;
  final int? level;
  final int? price;
  final int? price1;
  final int? price2;
  final int? price3;
  final int? price4;
  final int? price5;
  final String weather; // 날씨 속성 추가

  FishItem({
    required this.id,
    required this.name,
    this.nameKo,
    required this.image,
    required this.location,
    this.availableTime,
    this.level,
    this.price,
    this.price1,
    this.price2,
    this.price3,
    this.price4,
    this.price5,
    required this.weather, // 날씨 속성
  });

  factory FishItem.fromJson(Map<String, dynamic> json) {
    return FishItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameKo: (json['name_ko'] ?? json['nameKo'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      availableTime: (
          json['available_time'] ??
              json['availableTime'] ??
              json['timeOfDay'] ??
              ''
      ).toString(),
      level: (json['level'] != null) ? int.tryParse(json['level'].toString()) : null,
      price: (json['price'] != null) ? int.tryParse(json['price'].toString()) : null,

      // 수정된 부분: 스네이크 케이스와 카멜 케이스 모두 대응
      price1: int.tryParse((json['price_1'] ?? json['price1'] ?? '').toString()),
      price2: int.tryParse((json['price_2'] ?? json['price2'] ?? '').toString()),
      price3: int.tryParse((json['price_3'] ?? json['price3'] ?? '').toString()),
      price4: int.tryParse((json['price_4'] ?? json['price4'] ?? '').toString()),
      price5: int.tryParse((json['price_5'] ?? json['price5'] ?? '').toString()),

      weather: (json['weather'] ?? 'Unknown').toString(),
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
  static const String _favoritesKey = 'favorite_fish_ids';

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = '전체';
  String _searchQuery = '';
  String _selectedSort = '이름순';

  String _formatPrice(int? price) {
    if (price == null) return '';
    // 숫자를 세 자리마다 콤마를 찍는 정규식입니다.
    return price.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  bool _isFishLoading = true;
  bool _isInsectLoading = true;
  bool _isBirdLoading = true; // API 연결 전이므로 false 기본값
  bool _isPlantLoading = true;
  String? _errorMessage;

  List<BirdItem> _birdList = [];
  List<BirdItem> _visibleBirdList = [];
  List<PlantItem> _plantList = [];
  List<PlantItem> _visiblePlantList = [];
  List<FishItem> _fishList = [];
  List<FishItem> _visibleFishList = [];
  List<InsectItem> _insectList = [];
  List<InsectItem> _visibleInsectList = [];
  Set<String> _favoriteIds = {};

  final String _fishApiUrl = 'http://161.33.30.40:8080/api/fish';
  final String _insectApiUrl = 'http://161.33.30.40:8080/api/insects';
  final String _birdApiUrl = 'http://161.33.30.40:8080/api/birds';
  final String _plantApiUrl = 'http://161.33.30.40:8080/api/gardening';

  // 물고기 이름을 반환하는 함수
  String _displayName(FishItem fish) {
    return fish.nameKo ?? fish.name;
  }

// 물고기 이미지 경로를 반환하는 함수
  String _imageAssetPath(String? image) {
    if (image == null || image.isEmpty) return 'assets/images/default.png';

    String fullPath = image.startsWith('assets/') ? image : 'assets/$image';

    // 확장자가 없는 경우 .webp 기본 추가
    if (!fullPath.toLowerCase().endsWith('.webp') &&
        !fullPath.toLowerCase().endsWith('.png') &&
        !fullPath.toLowerCase().endsWith('.jpg')) {
      fullPath = '$fullPath.webp';
    }

    return fullPath;
  }

// 1. 시간대 레이블 변환 함수: 숫자를 직관적인 한글로 변환
  String _timeLabel(String? time) {
    if (time == null || time.trim().isEmpty) return '';

    final raw = time.trim();
    final lower = raw.toLowerCase();
    final t = raw.replaceAll(' ', '');

    // 이미지 및 DB 숫자 범위 대응
    if (lower == 'all day' || t == '0~24' || t == '0-24') return '하루종일';
    if (t == '4~21' || t == '4-21') return '새벽~밤';
    if (t == '4~19' || t == '4-19') return '새벽~저녁';
    if (t == '0~18' || t == '0-18') return '밤~저녁';
    if (t == '6~18' || t == '6-18') return '아침~저녁';

    // 기본 단일 시간대
    if (t == '6~12' || lower == 'morning') return '아침';
    if (t == '12~18' || lower == 'afternoon') return '낮';
    if (t == '18~24' || lower == 'evening') return '저녁';
    if (t == '0~6' || lower == 'night') return '밤';

    return raw;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // ★ 탭이 바뀔 때마다 화면을 다시 그리도록 리스너 추가
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          // 탭이 바뀌면 기존 필터를 '전체'로 초기화해주는 것이 자연스럽습니다.
          _selectedFilter = '전체';
        });
        _applyFilters();
      }
    });

    _searchController.addListener(_onSearchChanged);
    _loadFavorites();

    // 데이터 로드 호출
    _fetchAllData();
  }

  void _fetchAllData() {
    _fetchFish();
    _fetchBirds();
    _fetchInsects();
    _fetchPlants();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_favoritesKey) ?? [];
    setState(() {
      _favoriteIds = stored.toSet();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favoriteIds.toList());
  }

  Future<void> _toggleFavorite(String fishId) async {
    setState(() {
      if (_favoriteIds.contains(fishId)) {
        _favoriteIds.remove(fishId);
      } else {
        _favoriteIds.add(fishId);
      }
    });
    await _saveFavorites();
    _applyFilters();
  }

  Future<void> _fetchFish() async {
    setState(() {
      _isFishLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(_fishApiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final fish = data.map((e) => FishItem.fromJson(e)).toList();

        setState(() {
          _fishList = fish;
          _isFishLoading = false;
        });
        _applyFilters();
      } else {
        setState(() {
          _errorMessage = '물고기 데이터를 불러오지 못했어요.';
          _isFishLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isFishLoading = false;
      });
    }
  }

  Future<void> _fetchBirds() async {
    setState(() {
      _isBirdLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http.get(Uri.parse(_birdApiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final birds = data.map((e) => BirdItem.fromJson(e as Map<String, dynamic>)).toList();
        setState(() {
          _birdList = birds;
          _isBirdLoading = false;
        });
        _applyFilters();
      } else {
        setState(() => _isBirdLoading = false);
      }
    } catch (e) {
      setState(() => _isBirdLoading = false);
    }
  }

  Future<void> _fetchPlants() async {
    setState(() {
      _isPlantLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http.get(Uri.parse(_plantApiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final plants = data.map((e) => PlantItem.fromJson(e as Map<String, dynamic>)).toList();
        setState(() {
          _plantList = plants;
          _isPlantLoading = false;
        });
        _applyFilters();
      } else {
        setState(() => _isPlantLoading = false);
      }
    } catch (e) {
      setState(() => _isPlantLoading = false);
    }
  }

  Future<void> _fetchInsects() async {
    setState(() => _isInsectLoading = true);
    try {
      final response = await http.get(Uri.parse(_insectApiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final insects = data.map((e) => InsectItem.fromJson(e)).toList();
        setState(() {
          _insectList = insects;
          _isInsectLoading = false;
        });
        _applyFilters();
      } else {
        setState(() => _isInsectLoading = false);
      }
    } catch (e) {
      setState(() => _isInsectLoading = false);
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

  void _onSortSelected(String sort) {
    setState(() {
      _selectedSort = sort;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchQuery.toLowerCase();
    final tabIndex = _tabController.index;

    setState(() {
      // 1. 물고기 필터링 (Tab 0)
      List<FishItem> filteredFish = List.from(_fishList);
      if (query.isNotEmpty) {
        filteredFish = filteredFish.where((item) =>
        (item.nameKo ?? '').contains(query) ||
            item.name.toLowerCase().contains(query)).toList();
      }
      if (_selectedFilter != '전체' && tabIndex == 0) {
        filteredFish = filteredFish.where((item) => _matchesFilter(item, _selectedFilter)).toList();
      }
      _sortFish(filteredFish);
      _visibleFishList = filteredFish;

      // 2. 새 관찰 필터링 (Tab 1)
      List<BirdItem> filteredBirds = List.from(_birdList);
      if (query.isNotEmpty) {
        filteredBirds = filteredBirds.where((item) => item.nameKo.contains(query)).toList();
      }
      if (_selectedFilter != '전체' && tabIndex == 1) {
        filteredBirds = filteredBirds.where((item) => item.location.contains(_selectedFilter)).toList();
      }
      _sortBirds(filteredBirds); // 새 정렬 추가
      _visibleBirdList = filteredBirds;

      // 3. 곤충 채집 필터링 (Tab 2)
      List<InsectItem> filteredInsects = List.from(_insectList);
      if (query.isNotEmpty) {
        filteredInsects = filteredInsects.where((item) =>
        item.nameKo.contains(query) ||
            item.name.toLowerCase().contains(query)).toList();
      }
      if (_selectedFilter != '전체' && tabIndex == 2) {
        filteredInsects = filteredInsects.where((item) => item.location.contains(_selectedFilter)).toList();
      }
      _sortInsects(filteredInsects);
      _visibleInsectList = filteredInsects;

      // 4. 원예 필터링 (Tab 3)
      List<PlantItem> filteredPlants = List.from(_plantList);
      if (query.isNotEmpty) {
        filteredPlants = filteredPlants.where((item) => item.nameKo.contains(query)).toList();
      }
      if (_selectedFilter != '전체' && tabIndex == 3) {
        filteredPlants = filteredPlants.where((item) =>
        item.location.contains(_selectedFilter) ||
            item.availableTime.contains(_selectedFilter)).toList();
      }
      _sortPlants(filteredPlants); // 원예 정렬 추가
      _visiblePlantList = filteredPlants;
    });
  }

  // 곤충 전용 정렬 함수
  void _sortInsects(List<InsectItem> list) {
    switch (_selectedSort) {
      case '가격순':
        list.sort((a, b) {
          // prices 리스트 중 가장 높은 가격 기준
          final aMax = a.prices.reduce((curr, next) => curr > next ? curr : next);
          final bMax = b.prices.reduce((curr, next) => curr > next ? curr : next);
          return bMax.compareTo(aMax);
        });
        break;
      case '좋아요순':
        list.sort((a, b) {
          final aFav = _favoriteIds.contains(a.id) ? 1 : 0;
          final bFav = _favoriteIds.contains(b.id) ? 1 : 0;
          return bFav.compareTo(aFav);
        });
        break;
      default:
        list.sort((a, b) => a.nameKo.compareTo(b.nameKo));
    }
  }

  void _sortFish(List<FishItem> list) {
    switch (_selectedSort) {
      case '가격순':
        list.sort((a, b) {
          final aPrice = a.price1 ?? a.price ?? 0;
          final bPrice = b.price1 ?? b.price ?? 0;
          final priceCompare = bPrice.compareTo(aPrice);
          if (priceCompare != 0) return priceCompare;
          return _displayName(a).compareTo(_displayName(b));
        });
        break;
      case '좋아요순':
        list.sort((a, b) {
          final aFav = _favoriteIds.contains(a.id) ? 1 : 0;
          final bFav = _favoriteIds.contains(b.id) ? 1 : 0;
          final favCompare = bFav.compareTo(aFav);
          if (favCompare != 0) return favCompare;
          return _displayName(a).compareTo(_displayName(b));
        });
        break;
      case '이름순':
      default:
        list.sort((a, b) => _displayName(a).compareTo(_displayName(b)));
    }
  }

  void _sortBirds(List<BirdItem> list) {
    _genericSort(list, (item) => item.nameKo, (item) => item.prices, (item) => item.id);
  }

  void _sortPlants(List<PlantItem> list) {
    _genericSort(list, (item) => item.nameKo, (item) => item.prices, (item) => item.id);
  }

// 중복 코드를 줄이기 위한 공통 정렬 로직
  void _genericSort<T>(List<T> list, String Function(T) getName, List<int> Function(T) getPrices, String Function(T) getId) {
    switch (_selectedSort) {
      case '가격순':
        list.sort((a, b) {
          final aMax = getPrices(a).isEmpty ? 0 : getPrices(a).reduce((curr, next) => curr > next ? curr : next);
          final bMax = getPrices(b).isEmpty ? 0 : getPrices(b).reduce((curr, next) => curr > next ? curr : next);
          return bMax.compareTo(aMax);
        });
        break;
      case '좋아요순':
        list.sort((a, b) {
          final aFav = _favoriteIds.contains(getId(a)) ? 1 : 0;
          final bFav = _favoriteIds.contains(getId(b)) ? 1 : 0;
          return bFav.compareTo(aFav);
        });
        break;
      default:
        list.sort((a, b) => getName(a).compareTo(getName(b)));
    }
  }

  bool _matchesFilter(FishItem fish, String filter) {
    // 위치를 소문자로 변환하여 비교
    final location = fish.location.toLowerCase();
    final weather = fish.weather.toLowerCase();

    // 각 위치 카테고리 별로 체크
    final isRiver = location.contains('river') ||
        location.contains('강') ||
        location.contains('하천');

    final isLake = location.contains('lake') ||
        location.contains('호수') ||
        location.contains('연못');

    final isSea = location.contains('sea') ||
        location.contains('ocean') ||
        location.contains('fishing') ||
        location.contains('바다') ||
        location.contains('해역') ||
        location.contains('바다낚시') ||
        location.contains('동해') ||
        location.contains('구해') ||
        location.contains('고래바다') ||
        location.contains('잔잔한 바다');

    // 날씨 필터링을 추가하려면 여기서 추가 가능합니다.
    final isAllDayWeather = weather.contains('all day');
    final isMorningWeather = weather.contains('morning');
    final isEveningWeather = weather.contains('evening');

    // 필터 종류에 따른 물고기 필터링
    switch (filter) {
      case '강 물고기':  // '강 물고기' 필터일 경우
        return isRiver;
      case '호수 물고기':  // '호수 물고기' 필터일 경우
        return isLake;
      case '바다 물고기':  // '바다 물고기' 필터일 경우
        return isSea;
      case '하루종일 날씨':  // '하루종일 날씨' 필터일 경우
        return isAllDayWeather;
      case '아침 날씨':  // '아침 날씨' 필터일 경우
        return isMorningWeather;
      case '저녁 날씨':  // '저녁 날씨' 필터일 경우
        return isEveningWeather;
      default:
        return true;  // 필터가 설정되지 않은 경우 모든 물고기 반환
    }
  }

  String _pricePreview(FishItem fish) {
    final prices = [
      fish.price1,
      fish.price2,
      fish.price3,
      fish.price4,
      fish.price5,
    ].whereType<int>().toList();

    if (prices.isEmpty) {
      if (fish.price != null) return '${_formatPrice(fish.price)}원';
      return '-';
    }

    final minPrice = prices.first;
    final maxPrice = prices.last;

    if (minPrice == maxPrice) {
      return '${_formatPrice(minPrice)}원';
    } else {
      // 예: 500원 ~ 2,500원
      return '${_formatPrice(minPrice)}원 ~ ${_formatPrice(maxPrice)}원';
    }
  }

  List<PopupMenuEntry<String>> _buildPriceMenuItems(FishItem fish) {
    final items = <PopupMenuEntry<String>>[];

    void addPriceItem(String label, int? value) {
      if (value != null) {
        items.add(
          PopupMenuItem<String>(
            value: label,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 20),
                Text(
                  '${_formatPrice(value)}원', // 여기에도 포맷팅과 '원' 추가
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 가격 필드를 추가하는 부분
    addPriceItem('1성', fish.price1);
    addPriceItem('2성', fish.price2);
    addPriceItem('3성', fish.price3);
    addPriceItem('4성', fish.price4);
    addPriceItem('5성', fish.price5);

    if (items.isEmpty) {
      items.add(
        const PopupMenuItem<String>(
          value: 'empty',
          enabled: false,
          child: Text('가격 정보 없음'),
        ),
      );
    }

    return items;
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
                    _buildFishingTabContent(), // 낚시
                    _buildBirdTabContent(),    // 새 관찰 (추가/수정)
                    _buildInsectTabContent(),  // 곤충 채집
                    _buildPlantTabContent(),   // 원예 (추가/수정)
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

  // --- 새 관찰 탭 전체 구성 ---
  Widget _buildBirdTabContent() {
    return Column(
      children: [
        _buildFilterBarArea(), // 필터링 칩과 정렬 버튼 표시
        Expanded(
          child: _buildDynamicTabContent(
              _isBirdLoading,
              _visibleBirdList,
              _buildBirdCard
          ),
        ),
      ],
    );
  }

  // 공통 리스트 빌더 함수 (새, 원예 등에서 사용)
  // 공통 리스트 빌더 함수 수정
  Widget _buildDynamicTabContent<T>(bool isLoading, List<T> list, Widget Function(T) buildCard) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async { _fetchAllData(); },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: const [
            SizedBox(height: 180),
            Center(child: Text('검색 결과가 없어요.', style: TextStyle(fontSize: 14, color: Color(0xFF666666)))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async { _fetchAllData(); },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: list.length + 1, // ★ 마지막에 여백 공간을 위해 +1 해줍니다.
        itemBuilder: (context, index) {
          // ★ 마지막 인덱스일 때 하단 메뉴바만큼의 여백(SizedBox)을 반환합니다.
          if (index == list.length) {
            return const SizedBox(height: 120); // 물고기 탭과 동일한 높이의 여백
          }
          return buildCard(list[index]);
        },
      ),
    );
  }

// --- 원예 탭 전체 구성 ---
  Widget _buildPlantTabContent() {
    return Column(
      children: [
        _buildFilterBarArea(), // 필터링 칩과 정렬 버튼 표시
        Expanded(
          child: _buildDynamicTabContent(
              _isPlantLoading,
              _visiblePlantList,
              _buildPlantCard
          ),
        ),
      ],
    );
  }

  Widget _buildFishingTabContent() {
    return Column(
      children: [
        _buildFilterBarArea(),
        Expanded(child: _buildFishingListArea()),
      ],
    );
  }

  Widget _buildFishingListArea() {
    if (_isFishLoading) {
      return const Center(child: CircularProgressIndicator());
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
                  fish: fish,
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsectTabContent() {
    return Column(
      children: [
        _buildFilterBarArea(),
        Expanded(
          child: _isInsectLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            onRefresh: _fetchInsects,
            child: _visibleInsectList.isEmpty
                ? ListView(
              children: const [
                SizedBox(height: 180),
                Center(child: Text('검색 결과가 없어요.', style: TextStyle(color: Color(0xFF666666)))),
              ],
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              // ★ 수정: 하단 여백을 위해 1개를 더 추가합니다.
              itemCount: _visibleInsectList.length + 1,
              itemBuilder: (context, index) {
                // ★ 수정: 마지막 인덱스일 때 투명한 여백 박스를 반환합니다.
                if (index == _visibleInsectList.length) {
                  return const SizedBox(height: 120);
                }
                return _buildInsectCard(_visibleInsectList[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGatheringCard({
    required FishItem fish,
  }) {
    final isFavorite = _favoriteIds.contains(fish.id);
    final priceText = _pricePreview(fish);

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
                child: Image.asset(
                  _imageAssetPath(fish.image),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFF5F5F5),
                      child: const Icon(
                        Icons.phishing,
                        size: 40,
                        color: Color(0xFFD9D9D9),
                      ),
                    );
                  },
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
                              _displayName(fish),
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
                                // 1. 레벨 칩
                                _buildSmallTag(
                                  fish.level != null ? '낚시 ${fish.level}레벨' : '낚시',
                                ),
                                // 2. 시간 칩 (아침, 밤, 하루종일 등)
                                if (_timeLabel(fish.availableTime).isNotEmpty)
                                  _buildSmallTag(_timeLabel(fish.availableTime)),

                                // 3. 위치 칩 추가 (예: 강, 바다 등)
                                if (fish.location.isNotEmpty)
                                  _buildSmallTag(fish.location, isLocation: true),

                                // 4. 날씨 칩 추가 (예: 맑음, 비 등)
                                if (fish.weather != 'Unknown' && fish.weather.isNotEmpty)
                                  _buildSmallTag(fish.weather, isWeather: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () => _toggleFavorite(fish.id),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 24,
                            color: isFavorite
                                ? const Color(0xFFFF8E7C)
                                : const Color(0xFFD9D9D9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PopupMenuButton<String>(
                        itemBuilder: (context) => _buildPriceMenuItems(fish),
                        offset: const Offset(0, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4), // 터치 영역 확보
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                constraints: const BoxConstraints(minWidth: 46),
                                height: 20,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFFF7A65).withOpacity(0.5),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
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
                              const SizedBox(width: 8),
                              Text(
                                priceText, // 여기서 수정된 _pricePreview 결과값이 들어갑니다.
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                  height: 1.0,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildPriceTagLabel() {
  return Container(
    constraints: const BoxConstraints(minWidth: 46),
    height: 20,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      border: Border.all(
        color: const Color(0xFFFF7A65).withOpacity(0.5),
      ),
      borderRadius: BorderRadius.circular(6),
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
  );
}

// 새 관찰 카드
  // 새 관찰 카드 수정본
  Widget _buildBirdCard(BirdItem bird) {
    final isFavorite = _favoriteIds.contains(bird.id);
    // 가격 텍스트 계산
    final minPrice = bird.prices.isNotEmpty ? bird.prices.reduce((a, b) => a < b ? a : b) : 0;
    final maxPrice = bird.prices.isNotEmpty ? bird.prices.reduce((a, b) => a > b ? a : b) : 0;
    final priceText = minPrice == maxPrice ? '${_formatPrice(minPrice)}원' : '${_formatPrice(minPrice)}원 ~ ${_formatPrice(maxPrice)}원';

    return _buildBaseContainer(
      child: Row(
        children: [
          _buildCardImage(bird.image, Icons.flutter_dash),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardTitle(bird.nameKo, bird.id), // 여기서 bird.nameKo가 표시됩니다.
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4, runSpacing: 4,
                  children: [
                    _buildSmallTag('관찰 ${bird.level}레벨'),
                    if (bird.availableTime.isNotEmpty) _buildSmallTag(bird.availableTime),
                    _buildSmallTag(bird.location, isLocation: true),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      itemBuilder: (context) => List.generate(bird.prices.length, (i) =>
                          PopupMenuItem(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${i + 1}성', style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 20),
                                Text('${_formatPrice(bird.prices[i])}원', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ],
                            ),
                          )
                      ),
                      child: Row(
                        children: [
                          _buildPriceTagLabel(),
                          const SizedBox(width: 8),
                          Text(priceText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF616161)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// 원예 카드 수정
  Widget _buildPlantCard(PlantItem plant) {
    final isFavorite = _favoriteIds.contains(plant.id);

    // prices 리스트에서 최소/최대 가격 계산
    final minPrice = plant.prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = plant.prices.reduce((a, b) => a > b ? a : b);
    final priceText = minPrice == maxPrice
        ? '${_formatPrice(minPrice)}원'
        : '${_formatPrice(minPrice)}원 ~ ${_formatPrice(maxPrice)}원';

    return _buildBaseContainer(
      child: Row(
        children: [
          _buildCardImage(plant.image, Icons.local_florist),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardTitle(plant.nameKo, plant.id),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4, runSpacing: 4,
                  children: [
                    _buildSmallTag('원예 ${plant.level}레벨'),
                    if (plant.availableTime.isNotEmpty) _buildSmallTag(plant.availableTime),
                    _buildSmallTag(plant.location, isLocation: true),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 곤충처럼 5단계 가격을 볼 수 있게 PopupMenuButton 적용
                    PopupMenuButton<String>(
                      itemBuilder: (context) => List.generate(plant.prices.length, (i) =>
                          PopupMenuItem(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${i + 1}성', style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 20),
                                Text('${_formatPrice(plant.prices[i])}원',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ],
                            ),
                          )
                      ),
                      child: Row(
                        children: [
                          _buildPriceTagLabel(),
                          const SizedBox(width: 8),
                          Text(priceText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF616161)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsectCard(InsectItem insect) {
    final isFavorite = _favoriteIds.contains(insect.id);

    // 가격 표시 (최소~최대)
    final minPrice = insect.prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = insect.prices.reduce((a, b) => a > b ? a : b);
    final priceText = minPrice == maxPrice
        ? '${_formatPrice(minPrice)}원'
        : '${_formatPrice(minPrice)}원 ~ ${_formatPrice(maxPrice)}원';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Image.asset(
                _imageAssetPath(insect.image), // path 대신 fish.image 사용
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Color(0xFFF5F5F5),
                  child: Icon(
                    Icons.bug_report, // errorIcon 대신 물고기 아이콘 직접 지정
                    size: 40,
                    color: Color(0xFFD9D9D9),
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
                    children: [
                      Expanded(
                        child: Text(
                          insect.nameKo,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                        ),
                      ),
                      InkWell(
                        onTap: () => _toggleFavorite(insect.id),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? const Color(0xFFFF8E7C) : const Color(0xFFD9D9D9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4, runSpacing: 4,
                    children: [
                      _buildSmallTag('채집 ${insect.level}레벨'),
                      if (insect.availableTime.isNotEmpty) _buildSmallTag(insect.availableTime),
                      if (insect.location.isNotEmpty) _buildSmallTag(insect.location, isLocation: true),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PopupMenuButton<String>(
                        itemBuilder: (context) => List.generate(insect.prices.length, (i) =>
                            PopupMenuItem(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${i + 1}성', style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 20),
                                  Text('${_formatPrice(insect.prices[i])}원',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                ],
                              ),
                            )
                        ),
                        child: Row(
                          children: [
                            _buildPriceTagLabel(),
                            const SizedBox(width: 8),
                            Text(priceText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF616161)),
                          ],
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

  // 카드 공통 컨테이너
  Widget _buildBaseContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadows: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14)],
      ),
      child: IntrinsicHeight(child: child),
    );
  }

// 카드 내 이미지 박스
  Widget _buildCardImage(String? path, IconData errorIcon) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Image.asset(
        _imageAssetPath(path),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            Icon(errorIcon, size: 40, color: const Color(0xFFD9D9D9)),
      ),
    );
  }

// 카드 내 제목 및 좋아요 버튼
  Widget _buildCardTitle(String name, String id) {
    final isFavorite = _favoriteIds.contains(id);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
        InkWell(
          onTap: () => _toggleFavorite(id),
          child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? const Color(0xFFFF8E7C) : const Color(0xFFD9D9D9)),
        ),
      ],
    );
  }

  // 2. 칩 위젯 생성 함수 (장소 색상 추가 및 쏠림 해결)
  Widget _buildSmallTag(String text, {bool isLocation = false, bool isWeather = false}) {
    final rawText = text.trim();
    final lowerText = rawText.toLowerCase();

    // 기본값 (예외 상황 대비)
    Color bg = const Color(0xFFF5F5F5);
    Color border = const Color(0xFFE0E0E0);
    Color textColor = const Color(0xFF757575);

    int level = 0;

    // A. 낚시 레벨 (1레벨: 회색 / 2~9레벨: 무지개 단색 / 10레벨~: 소프트 그라데이션)
    if (rawText.contains('레벨')) {
      level = int.tryParse(rawText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

      if (level == 1) {
        bg = const Color(0xFFEEEEEE); border = const Color(0xFFBDBDBD); textColor = const Color(0xFF616161);
      } else if (level == 2) { bg = const Color(0xFFFFEBEE); border = const Color(0xFFFFCDD2); textColor = const Color(0xFFC62828); }
      else if (level == 3) { bg = const Color(0xFFFFF3E0); border = const Color(0xFFFFE0B2); textColor = const Color(0xFFE65100); }
      else if (level == 4) { bg = const Color(0xFFFFFDE7); border = const Color(0xFFFFF9C4); textColor = const Color(0xFFF57F17); }
      else if (level == 5) { bg = const Color(0xFFE8F5E9); border = const Color(0xFFC8E6C9); textColor = const Color(0xFF2E7D32); }
      else if (level == 6) { bg = const Color(0xFFE1F5FE); border = const Color(0xFFB3E5FC); textColor = const Color(0xFF0277BD); }
      else if (level == 7) { bg = const Color(0xFFE8EAF6); border = const Color(0xFFC5CAE9); textColor = const Color(0xFF1A237E); }
      else if (level == 8) { bg = const Color(0xFFF3E5F5); border = const Color(0xFFE1BEE7); textColor = const Color(0xFF7B1FA2); }
      else if (level == 9) { bg = const Color(0xFFFCE4EC); border = const Color(0xFFF8BBD0); textColor = const Color(0xFFC2185B); }
      else { // 10레벨 이상 마스터
        textColor = const Color(0xFF424242);
        border = const Color(0xFFBDBDBD).withOpacity(0.5);
      }
    }
    // B. 시간대 (연분홍/주황 계열 - 따뜻한 느낌)
    else if (rawText == '하루종일' || rawText.contains('~') || lowerText.contains('day') || lowerText.contains('time')) {
      bg = const Color(0xFFFFEDE1);
      border = const Color(0xFFFFCCBC);
      textColor = const Color(0xFFD84315);
    }
    // C. 날씨 (맑음: 노랑 / 비: 파랑 / 흐림: 민트)
    else if (isWeather) {
      if (lowerText.contains('sun') || rawText.contains('맑음')) {
        bg = const Color(0xFFFFF9C4); border = const Color(0xFFFFF176); textColor = const Color(0xFFF57F17);
      } else if (lowerText.contains('rain') || rawText.contains('비')) {
        bg = const Color(0xFFE1F5FE); border = const Color(0xFF81D4FA); textColor = const Color(0xFF01579B);
      } else {
        bg = const Color(0xFFE0F2F1); border = const Color(0xFF80CBC4); textColor = const Color(0xFF00695C);
      }
    }
    // D. 장소 (강: 청록 / 호수·산수: 남색 / 바다·구해: 진파랑)
    else if (isLocation) {
      if (rawText.contains('강') || lowerText.contains('river')) {
        bg = const Color(0xFFE0F7FA); border = const Color(0xFF80DEEA); textColor = const Color(0xFF006064);
      } else if (rawText.contains('호수') || rawText.contains('산수') || lowerText.contains('lake')) {
        bg = const Color(0xFFE8EAF6); border = const Color(0xFF9FA8DA); textColor = const Color(0xFF1A237E);
      } else if (rawText.contains('바다') || rawText.contains('구해') || lowerText.contains('sea')) {
        bg = const Color(0xFFE3F2FD); border = const Color(0xFF64B5F6); textColor = const Color(0xFF0D47A1);
      }
    }

    final bool isMasterLevel = rawText.contains('레벨') && level >= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: isMasterLevel
            ? const LinearGradient(
          colors: [Color(0xFFFFD1D1), Color(0xFFFFF4D1), Color(0xFFD1FFDA), Color(0xFFD1E3FF), Color(0xFFE5D1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: isMasterLevel ? null : bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withOpacity(0.5), width: 0.8),
      ),
      child: Transform.translate(
        offset: const Offset(0, -0.5), // 미세한 수직 중앙 조정
        child: Text(
          rawText,
          style: TextStyle(
            fontSize: 9.5,
            color: textColor,
            fontWeight: (isMasterLevel || isLocation) ? FontWeight.w700 : FontWeight.w600,
            height: 1.0,
            fontFamily: 'SF Pro',
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBarArea() {
    List<String> filters = ['전체'];

    switch (_tabController.index) {
      case 0: filters.addAll(['강 물고기', '호수 물고기', '바다 물고기']); break;
      case 1: filters.addAll(['도시', '숲', '물가', '고래산']); break; // 새 위치
      case 2: filters.addAll(['도시', '곤충 유인', '꽃밭', '온천 산', '숲']); break;
      case 3: filters.addAll(['꽃', '농작물', '나무']); break; // 원예 타입
    }

  return IntrinsicHeight(
    child: Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: SizedBox(
              height: 48,
              child: ListView.builder( // 2. ListView.builder로 동적 생성
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                itemBuilder: (context, index) {
                  return _buildFilterChip(filters[index]);
                },
              ),
            ),
          ),
        ),
        // 정렬 버튼 (이 부분은 모든 탭 공통이므로 유지)
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 8),
          child: PopupMenuButton<String>(
            onSelected: _onSortSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(value: '이름순', child: Text('이름순')),
              PopupMenuItem(value: '가격순', child: Text('가격순')),
              PopupMenuItem(value: '좋아요순', child: Text('좋아요순')),
            ],
            offset: const Offset(0, 30),
            child: Row(
              children: [
                Text(
                  _selectedSort,
                  style: const TextStyle(
                    color: Color(0xFF616161),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
            // ★ 도감 탭과 동일하게 height: 1.0과 SF Pro 폰트를 적용합니다.
            height: 1.0,
            fontFamily: 'SF Pro',
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
          // ★ 아래 속성들이 도감 탭의 정렬 비결입니다.
          visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: -2),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          showCheckmark: false,
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
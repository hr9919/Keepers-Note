import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'setting_screen.dart';

import 'models/global_search_item.dart';

class BirdItem {
  final String id;
  final String name;
  final String nameKo;
  final String image;
  final String location;
  final String availableTime;
  final String weather;
  final int level;
  final List<int> prices;

  BirdItem({
    required this.id,
    required this.name,
    required this.nameKo,
    required this.image,
    required this.location,
    required this.availableTime,
    required this.weather,
    required this.level,
    required this.prices,
  });

  factory BirdItem.fromJson(Map<String, dynamic> json) {
    int parsePrice(dynamic p1, dynamic p2) {
      return int.tryParse((p1 ?? p2 ?? 0).toString()) ?? 0;
    }

    return BirdItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameKo: (json['nameKo'] ?? json['name_ko'] ?? json['name'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      availableTime: (json['availableTime'] ?? json['available_time'] ?? '').toString(),
      weather: (json['weather'] ?? '').toString(),
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

class PlantItem {
  final String id;
  final String name;
  final String nameKo;
  final String image;
  final String location;
  final String availableTime;
  final String weather;
  final int level;
  final List<int> prices;

  PlantItem({
    required this.id,
    required this.name,
    required this.nameKo,
    required this.image,
    required this.location,
    required this.availableTime,
    required this.weather,
    required this.level,
    required this.prices,
  });

  factory PlantItem.fromJson(Map<String, dynamic> json) {
    int parsePrice(dynamic p1, dynamic p2) {
      return int.tryParse((p1 ?? p2 ?? 0).toString()) ?? 0;
    }

    return PlantItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameKo: (json['nameKo'] ?? json['name_ko'] ?? json['name'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      availableTime: (json['availableTime'] ?? json['available_time'] ?? '').toString(),
      weather: (json['weather'] ?? '').toString(),
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
      name: (json['name'] ?? '').toString(),
      nameKo: (json['name_ko'] ?? json['nameKo'] ?? json['name'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
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
    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      return int.tryParse(value.toString());
    }

    return FishItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameKo: (json['name_ko'] ?? json['nameKo'] ?? json['name'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      availableTime: (
          json['available_time'] ??
              json['availableTime'] ??
              json['timeOfDay'] ??
              ''
      ).toString(),
      level: parseNullableInt(json['level']),
      price: parseNullableInt(json['price']),
      price1: parseNullableInt(json['price_1'] ?? json['price1']),
      price2: parseNullableInt(json['price_2'] ?? json['price2']),
      price3: parseNullableInt(json['price_3'] ?? json['price3']),
      price4: parseNullableInt(json['price_4'] ?? json['price4']),
      price5: parseNullableInt(json['price_5'] ?? json['price5']),
      weather: (json['weather'] ?? 'Unknown').toString(),
    );
  }
}

class GatheringScreen extends StatefulWidget {
  final VoidCallback? openDrawer;
  final GlobalSearchItem? initialSearchItem;
  final int resetSearchSignal;

  const GatheringScreen({
    super.key,
    this.openDrawer,
    this.initialSearchItem,
    this.resetSearchSignal = 0,
  });

  @override
  State<GatheringScreen> createState() => _GatheringScreenState();
}

class _GatheringScreenState extends State<GatheringScreen>
    with SingleTickerProviderStateMixin {
  static const String _favoritesKey = 'favorite_gathering_ids';

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = '전체';
  String _searchQuery = '';
  String _selectedSort = '이름순';

  bool _showTopBtn = false;
  bool _isFilterVisible = true;

  String? _highlightedId;
  GlobalSearchItem? _pendingSearchItem;

  final ScrollController _fishScrollController = ScrollController();
  final ScrollController _birdScrollController = ScrollController();
  final ScrollController _insectScrollController = ScrollController();
  final ScrollController _plantScrollController = ScrollController();

  bool _isFishLoading = true;
  bool _isInsectLoading = true;
  bool _isBirdLoading = true;
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

  ScrollController _getCurrentController() {
    final index = _tabController.index.clamp(0, 3);
    if (index == 0) return _fishScrollController;
    if (index == 1) return _birdScrollController;
    if (index == 2) return _insectScrollController;
    return _plantScrollController;
  }

  List<String> _getCurrentFilterList() {
    final index = _tabController.index;
    if (index == 0) return ['전체', '강 물고기', '호수 물고기', '바다 물고기'];
    if (index == 1) return ['전체', '숲', '호수', '바다', '도시근교'];
    if (index == 2) return ['전체', '숲', '들판', '호수', '바다'];
    return ['전체', '꽃밭', '숲', '농장', '온실'];
  }

  void _attachScrollListener(ScrollController controller) {
    controller.addListener(() {
      if (!mounted || !controller.hasClients) return;

      final offset = controller.offset;
      final bool showBtn = offset > 100;

      if (showBtn != _showTopBtn) {
        setState(() => _showTopBtn = showBtn);
      }

      // 맨 위 근처에 왔을 때만 필터바 복구
      if (offset <= 5 && !_isFilterVisible) {
        setState(() => _isFilterVisible = true);
      }
    });
  }

  String _normalizeGatheringTargetId(String rawId) {
    if (rawId.startsWith('fish_')) {
      return rawId.replaceFirst('fish_', '');
    }
    if (rawId.startsWith('bird_')) {
      return rawId.replaceFirst('bird_', '');
    }
    if (rawId.startsWith('insect_')) {
      return rawId.replaceFirst('insect_', '');
    }
    if (rawId.startsWith('plant_')) {
      return rawId.replaceFirst('plant_', '');
    }
    return rawId;
  }

  String _formatPrice(int? price) {
    if (price == null) return '';
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  String _displayName(FishItem fish) {
    final ko = fish.nameKo?.trim() ?? '';
    return ko.isNotEmpty ? ko : fish.name;
  }

  int _maxPrice(List<int> prices) {
    if (prices.isEmpty) return 0;
    return prices.reduce((a, b) => a > b ? a : b);
  }

  String _imageAssetPath(String? image) {
    if (image == null || image.isEmpty) return 'assets/images/default.png';

    String fullPath = image.startsWith('assets/') ? image : 'assets/$image';

    if (!fullPath.toLowerCase().endsWith('.webp') &&
        !fullPath.toLowerCase().endsWith('.png') &&
        !fullPath.toLowerCase().endsWith('.jpg')) {
      fullPath = '$fullPath.webp';
    }

    return fullPath;
  }

  String _timeLabel(String? time) {
    if (time == null || time.trim().isEmpty) return '';

    final raw = time.trim();
    final lower = raw.toLowerCase();
    final t = raw.replaceAll(' ', '');

    if (lower == 'all day' || t == '0~24' || t == '0-24') return '하루종일';
    if (t == '4~21' || t == '4-21') return '새벽~밤';
    if (t == '4~19' || t == '4-19') return '새벽~저녁';
    if (t == '0~18' || t == '0-18') return '밤~저녁';
    if (t == '6~18' || t == '6-18') return '아침~저녁';

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

    _attachScrollListener(_fishScrollController);
    _attachScrollListener(_birdScrollController);
    _attachScrollListener(_insectScrollController);
    _attachScrollListener(_plantScrollController);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedFilter = '전체';
        });
        _applyFilters();
      }
    });

    _searchController.addListener(_onSearchChanged);

    _loadFavorites();
    _fetchAllData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialSearchItem != null) {
        _pendingSearchItem = widget.initialSearchItem;
        _applySearchItem(widget.initialSearchItem!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant GatheringScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialSearchItem != null &&
        widget.initialSearchItem != oldWidget.initialSearchItem) {
      _pendingSearchItem = widget.initialSearchItem;
      _applySearchItem(widget.initialSearchItem!);
      return;
    }

    if (widget.resetSearchSignal != oldWidget.resetSearchSignal) {
      _clearSearchState();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();

    _fishScrollController.dispose();
    _birdScrollController.dispose();
    _insectScrollController.dispose();
    _plantScrollController.dispose();

    super.dispose();
  }

  void _fetchAllData() {
    _fetchFish();
    _fetchBirds();
    _fetchInsects();
    _fetchPlants();
  }

  void _scrollToTopForTab(GatheringTabType tab) {
    ScrollController? controller;

    switch (tab) {
      case GatheringTabType.fish:
        controller = _fishScrollController;
        break;
      case GatheringTabType.bird:
        controller = _birdScrollController;
        break;
      case GatheringTabType.insect:
        controller = _insectScrollController;
        break;
      case GatheringTabType.plant:
        controller = _plantScrollController;
        break;
      default:
        return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller == null || !controller.hasClients) return;

      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _applySearchItem(GlobalSearchItem item) {
    _pendingSearchItem = item;

    if (item.gatheringTab == null) return;

    final normalizedId = _normalizeGatheringTargetId(item.id);

    _searchController.clear();
    _searchQuery = '';

    switch (item.gatheringTab!) {
      case GatheringTabType.fish:
        _tabController.animateTo(0);
        break;
      case GatheringTabType.bird:
        _tabController.animateTo(1);
        break;
      case GatheringTabType.insect:
        _tabController.animateTo(2);
        break;
      case GatheringTabType.plant:
        _tabController.animateTo(3);
        break;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _applyFilters();

      setState(() {
        _highlightedId = normalizedId;
      });

      _scrollToTopForTab(item.gatheringTab!);

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          if (_highlightedId == normalizedId) {
            _highlightedId = null;
          }
          _pendingSearchItem = null;
        });
      });
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final stored = prefs.getStringList(_favoritesKey) ?? [];
    setState(() {
      _favoriteIds = stored.toSet();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favoriteIds.toList());
  }

  Future<void> _toggleFavorite(String itemId) async {
    setState(() {
      if (_favoriteIds.contains(itemId)) {
        _favoriteIds.remove(itemId);
      } else {
        _favoriteIds.add(itemId);
      }
    });

    await _saveFavorites();
    if (!mounted) return;

    _applyFilters();
  }

  bool _isFavorite(String itemId) => _favoriteIds.contains(itemId);

  Future<void> _fetchFish() async {
    if (mounted) {
      setState(() {
        _isFishLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await http.get(Uri.parse(_fishApiUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final fish = data
            .map((e) => FishItem.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _fishList = fish;
          _isFishLoading = false;
        });
        _applyFilters();
      } else {
        setState(() {
          _errorMessage = '물고기 데이터를 불러오지 못했어요. (${response.statusCode})';
          _isFishLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '물고기 데이터를 불러오는 중 오류가 발생했어요.';
        _isFishLoading = false;
      });
    }
  }

  Future<void> _fetchBirds() async {
    if (mounted) {
      setState(() {
        _isBirdLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await http.get(Uri.parse(_birdApiUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final birds = data
            .map((e) => BirdItem.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _birdList = birds;
          _isBirdLoading = false;
        });
        _applyFilters();
      } else {
        setState(() {
          _errorMessage = '새 데이터를 불러오지 못했어요. (${response.statusCode})';
          _isBirdLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '새 데이터를 불러오는 중 오류가 발생했어요.';
        _isBirdLoading = false;
      });
    }
  }

  Future<void> _fetchInsects() async {
    if (mounted) {
      setState(() {
        _isInsectLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await http.get(Uri.parse(_insectApiUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final insects = data
            .map((e) => InsectItem.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _insectList = insects;
          _isInsectLoading = false;
        });
        _applyFilters();
      } else {
        setState(() {
          _errorMessage = '곤충 데이터를 불러오지 못했어요. (${response.statusCode})';
          _isInsectLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '곤충 데이터를 불러오는 중 오류가 발생했어요.';
        _isInsectLoading = false;
      });
    }
  }

  Future<void> _fetchPlants() async {
    if (mounted) {
      setState(() {
        _isPlantLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await http.get(Uri.parse(_plantApiUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final plants = data
            .map((e) => PlantItem.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _plantList = plants;
          _isPlantLoading = false;
        });
        _applyFilters();
      } else {
        setState(() {
          _errorMessage = '원예 데이터를 불러오지 못했어요. (${response.statusCode})';
          _isPlantLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '원예 데이터를 불러오는 중 오류가 발생했어요.';
        _isPlantLoading = false;
      });
    }
  }

  bool _containsAny(String source, List<String> keywords) {
    final value = source.toLowerCase().replaceAll(' ', '');
    return keywords.any((k) => value.contains(k.toLowerCase().replaceAll(' ', '')));
  }

  bool _matchesFishFilter(FishItem fish, String filter) {
    final location = fish.location.toLowerCase();
    final weather = fish.weather.toLowerCase();

    final isRiver = _containsAny(location, ['river', '강', '하천']);
    final isLake = _containsAny(location, ['lake', '호수', '연못']);
    final isSea = _containsAny(location, [
      'sea', 'ocean', 'fishing', '바다', '해역', '바다낚시', '동해', '구해', '고래바다', '잔잔한바다'
    ]);

    switch (filter) {
      case '강 물고기':
        return isRiver;
      case '호수 물고기':
        return isLake;
      case '바다 물고기':
        return isSea;
      case '맑음':
      case '비':
      case '눈':
        return weather.contains(filter.toLowerCase());
      default:
        return true;
    }
  }

  bool _matchesBirdFilter(BirdItem bird, String filter) {
    final location = bird.location.toLowerCase();

    switch (filter) {
      case '숲':
        return _containsAny(location, ['숲', 'forest']);
      case '호수':
        return _containsAny(location, ['호수', 'lake', '연못']);
      case '바다':
        return _containsAny(location, ['바다', 'sea', 'ocean', '해변', '해안']);
      case '도시근교':
        return _containsAny(location, ['도시근교', '도시', '마을', '광장', '근교', 'town', 'city']);
      default:
        return true;
    }
  }

  bool _matchesInsectFilter(InsectItem insect, String filter) {
    final location = insect.location.toLowerCase();

    switch (filter) {
      case '숲':
        return _containsAny(location, ['숲', 'forest']);
      case '들판':
        return _containsAny(location, ['들판', '초원', '평원', 'field', 'grass']);
      case '호수':
        return _containsAny(location, ['호수', 'lake', '연못']);
      case '바다':
        return _containsAny(location, ['바다', 'sea', 'ocean', '해변', '해안']);
      default:
        return true;
    }
  }

  bool _matchesPlantFilter(PlantItem plant, String filter) {
    final location = plant.location.toLowerCase();

    switch (filter) {
      case '꽃밭':
        return _containsAny(location, ['꽃밭', 'flower', 'garden']);
      case '숲':
        return _containsAny(location, ['숲', 'forest']);
      case '농장':
        return _containsAny(location, ['농장', 'farm', '밭']);
      case '온실':
        return _containsAny(location, ['온실', 'greenhouse']);
      default:
        return true;
    }
  }

  String _displayBirdName(BirdItem bird) {
    final ko = bird.nameKo.trim();
    return ko.isNotEmpty ? ko : bird.name;
  }

  String _displayPlantName(PlantItem plant) {
    final ko = plant.nameKo.trim();
    return ko.isNotEmpty ? ko : plant.name;
  }

  String _displayInsectName(InsectItem insect) {
    final ko = insect.nameKo.trim();
    return ko.isNotEmpty ? ko : insect.name;
  }

  void _clearSearchState() {
    _pendingSearchItem = null;

    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    if (!mounted) return;

    setState(() {
      _searchQuery = '';
      _highlightedId = null;
      _selectedFilter = '전체';
    });

    _applyFilters();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
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
    final query = _searchQuery.trim().toLowerCase();
    final tabIndex = _tabController.index;

    List<FishItem> filteredFish = List.from(_fishList);
    if (query.isNotEmpty) {
      filteredFish = filteredFish.where((item) {
        final ko = (item.nameKo ?? '').toLowerCase();
        final en = item.name.toLowerCase();
        return ko.contains(query) || en.contains(query);
      }).toList();
    }
    if (tabIndex == 0 && _selectedFilter != '전체') {
      filteredFish = filteredFish
          .where((item) => _matchesFishFilter(item, _selectedFilter))
          .toList();
    }
    _sortFish(filteredFish);

    List<BirdItem> filteredBirds = List.from(_birdList);
    if (query.isNotEmpty) {
      filteredBirds = filteredBirds.where((item) {
        final ko = item.nameKo.toLowerCase();
        final en = item.name.toLowerCase();
        return ko.contains(query) || en.contains(query);
      }).toList();
    }
    if (tabIndex == 1 && _selectedFilter != '전체') {
      filteredBirds = filteredBirds
          .where((item) => _matchesBirdFilter(item, _selectedFilter))
          .toList();
    }
    _sortBirds(filteredBirds);

    List<InsectItem> filteredInsects = List.from(_insectList);
    if (query.isNotEmpty) {
      filteredInsects = filteredInsects.where((item) {
        final ko = item.nameKo.toLowerCase();
        final en = item.name.toLowerCase();
        return ko.contains(query) || en.contains(query);
      }).toList();
    }
    if (tabIndex == 2 && _selectedFilter != '전체') {
      filteredInsects = filteredInsects
          .where((item) => _matchesInsectFilter(item, _selectedFilter))
          .toList();
    }
    _sortInsects(filteredInsects);

    List<PlantItem> filteredPlants = List.from(_plantList);
    if (query.isNotEmpty) {
      filteredPlants = filteredPlants.where((item) {
        final ko = item.nameKo.toLowerCase();
        final en = item.name.toLowerCase();
        return ko.contains(query) || en.contains(query);
      }).toList();
    }
    if (tabIndex == 3 && _selectedFilter != '전체') {
      filteredPlants = filteredPlants
          .where((item) => _matchesPlantFilter(item, _selectedFilter))
          .toList();
    }
    _sortPlants(filteredPlants);

    if (_pendingSearchItem != null && _pendingSearchItem!.gatheringTab != null) {
      final item = _pendingSearchItem!;
      final normalizedId = _normalizeGatheringTargetId(item.id);

      switch (item.gatheringTab!) {
        case GatheringTabType.fish:
          _moveToTopInList<FishItem>(
            filteredFish,
                (e) => e.id.trim() == normalizedId.trim(),
          );
          break;
        case GatheringTabType.bird:
          _moveToTopInList<BirdItem>(
            filteredBirds,
                (e) => e.id.trim() == normalizedId.trim(),
          );
          break;
        case GatheringTabType.insect:
          _moveToTopInList<InsectItem>(
            filteredInsects,
                (e) => e.id.trim() == normalizedId.trim(),
          );
          break;
        case GatheringTabType.plant:
          _moveToTopInList<PlantItem>(
            filteredPlants,
                (e) => e.id.trim() == normalizedId.trim(),
          );
          break;
        default:
          break;
      }
    }

    if (!mounted) return;

    setState(() {
      _visibleFishList = filteredFish;
      _visibleBirdList = filteredBirds;
      _visibleInsectList = filteredInsects;
      _visiblePlantList = filteredPlants;
    });
  }

  void _sortFish(List<FishItem> list) {
    switch (_selectedSort) {
      case '가격순':
        list.sort((a, b) {
          final aPrice = a.price5 ?? a.price4 ?? a.price3 ?? a.price2 ?? a.price1 ?? a.price ?? 0;
          final bPrice = b.price5 ?? b.price4 ?? b.price3 ?? b.price2 ?? b.price1 ?? b.price ?? 0;
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
    switch (_selectedSort) {
      case '가격순':
        list.sort((a, b) {
          final compare = _maxPrice(b.prices).compareTo(_maxPrice(a.prices));
          if (compare != 0) return compare;
          return _displayBirdName(a).compareTo(_displayBirdName(b));
        });
        break;

      case '좋아요순':
        list.sort((a, b) {
          final aFav = _favoriteIds.contains(a.id) ? 1 : 0;
          final bFav = _favoriteIds.contains(b.id) ? 1 : 0;
          final favCompare = bFav.compareTo(aFav);
          if (favCompare != 0) return favCompare;
          return _displayBirdName(a).compareTo(_displayBirdName(b));
        });
        break;

      case '이름순':
      default:
        list.sort((a, b) => _displayBirdName(a).compareTo(_displayBirdName(b)));
    }
  }

  void _sortInsects(List<InsectItem> list) {
    switch (_selectedSort) {
      case '가격순':
        list.sort((a, b) {
          final compare = _maxPrice(b.prices).compareTo(_maxPrice(a.prices));
          if (compare != 0) return compare;
          return _displayInsectName(a).compareTo(_displayInsectName(b));
        });
        break;

      case '좋아요순':
        list.sort((a, b) {
          final aFav = _favoriteIds.contains(a.id) ? 1 : 0;
          final bFav = _favoriteIds.contains(b.id) ? 1 : 0;
          final favCompare = bFav.compareTo(aFav);
          if (favCompare != 0) return favCompare;
          return _displayInsectName(a).compareTo(_displayInsectName(b));
        });
        break;

      case '이름순':
      default:
        list.sort((a, b) => _displayInsectName(a).compareTo(_displayInsectName(b)));
    }
  }

  void _sortPlants(List<PlantItem> list) {
    switch (_selectedSort) {
      case '가격순':
        list.sort((a, b) {
          final compare = _maxPrice(b.prices).compareTo(_maxPrice(a.prices));
          if (compare != 0) return compare;
          return _displayPlantName(a).compareTo(_displayPlantName(b));
        });
        break;

      case '좋아요순':
        list.sort((a, b) {
          final aFav = _favoriteIds.contains(a.id) ? 1 : 0;
          final bFav = _favoriteIds.contains(b.id) ? 1 : 0;
          final favCompare = bFav.compareTo(aFav);
          if (favCompare != 0) return favCompare;
          return _displayPlantName(a).compareTo(_displayPlantName(b));
        });
        break;

      case '이름순':
      default:
        list.sort((a, b) => _displayPlantName(a).compareTo(_displayPlantName(b)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double appBarHeight = topPadding + 156;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_gradient.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: appBarHeight),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                    final controller = _getCurrentController();
                    final offset = controller.hasClients ? controller.offset : 0.0;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      height: (_isFilterVisible || offset < 20) ? 48 : 0,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: (_isFilterVisible || offset < 20) ? 1.0 : 0.0,
                          child: _buildFilterBarArea(),
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildFishingTabContent(),
                      _buildBirdTabContent(),
                      _buildInsectTabContent(),
                      _buildPlantTabContent(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildIntegratedAppBar(context, topPadding),
          ),
          Positioned(
            right: 20,
            bottom: 140,
            child: _buildScrollToTopButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBarArea() {
    final filters = _getCurrentFilterList();

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: filters.map((filter) => _buildFilterChip(filter)).toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: PopupMenuButton<String>(
            onSelected: _onSortSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(value: '이름순', child: Text('이름순')),
              PopupMenuItem(value: '가격순', child: Text('가격순')),
              PopupMenuItem(value: '좋아요순', child: Text('좋아요순')),
            ],
            child: Row(
              children: [
                Text(
                  _selectedSort,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final bool isSelected = _selectedFilter == label;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = label);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF8E7C).withOpacity(0.12)
              : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF8E7C).withOpacity(0.4)
                : Colors.black.withOpacity(0.05),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFFFF8E7C)
                : const Color(0xFF64748B),
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildGatheringCardShell({
    required bool isHighlighted,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ShapeDecoration(
        color: isHighlighted
            ? const Color(0xFFFFF4D8)
            : Colors.white.withOpacity(0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isHighlighted
                ? const Color(0xFFFFB27A).withOpacity(0.6)
                : const Color(0xFFFF8E7C).withOpacity(0.12),
            width: 1,
          ),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildBirdTabContent() {
    return _buildDynamicTabContent<BirdItem>(
      _isBirdLoading,
      _visibleBirdList,
      _buildBirdCard,
      controller: _birdScrollController,
    );
  }

  Widget _buildPlantTabContent() {
    return _buildDynamicTabContent<PlantItem>(
      _isPlantLoading,
      _visiblePlantList,
      _buildPlantCard,
      controller: _plantScrollController,
    );
  }

  Widget _buildFishingTabContent() {
    return _buildDynamicTabContent<FishItem>(
      _isFishLoading,
      _visibleFishList,
      _buildFishCard,
      controller: _fishScrollController,
    );
  }

  Widget _buildInsectTabContent() {
    return _buildDynamicTabContent<InsectItem>(
      _isInsectLoading,
      _visibleInsectList,
      _buildInsectCard,
      controller: _insectScrollController,
    );
  }

  Widget _buildDynamicTabContent<T>(
      bool isLoading,
      List<T> list,
      Widget Function(T) buildCard, {
        ScrollController? controller,
      }) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        if (controller == null || !controller.hasClients) return false;

        if (controller.offset < 20) {
          if (!_isFilterVisible) {
            setState(() => _isFilterVisible = true);
          }
          return false;
        }

        final delta = notification.scrollDelta ?? 0;

        if (delta > 2 && _isFilterVisible) {
          setState(() => _isFilterVisible = false);
        } else if (delta < -2 && !_isFilterVisible) {
          setState(() => _isFilterVisible = true);
        }

        return false;
      },
      child: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF8E7C),
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          _fetchAllData();
        },
        color: const Color(0xFFFF8E7C),
        backgroundColor: Colors.white,
        child: list.isEmpty
            ? ListView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 180),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(
                _errorMessage?.isNotEmpty == true
                    ? _errorMessage!
                    : '검색 결과가 없어요.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
            ),
          ],
        )
            : ListView.builder(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 180),
          itemCount: list.length,
          itemBuilder: (context, index) => buildCard(list[index]),
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

  Widget _buildPriceButton(List<int> prices) {
    final validPrices = prices.where((e) => e > 0).toList();

    final pricePreview = validPrices.isEmpty
        ? '-'
        : (validPrices.first == validPrices.last
        ? '${_formatPrice(validPrices.first)}원'
        : '${_formatPrice(validPrices.first)}원 ~ ${_formatPrice(validPrices.last)}원');

    return GestureDetector(
      onTap: () => _showPriceBottomSheet(prices),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF8E7C).withOpacity(0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EE),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                '판매가',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF7A65),
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              pricePreview,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D3436),
                height: 1.0,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBirdCard(BirdItem bird) {
    final bool isHighlighted = _highlightedId == bird.id;

    return _buildGatheringCardShell(
      isHighlighted: isHighlighted,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCardImage(bird.image, Icons.flutter_dash),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCardTitle(_displayBirdName(bird), bird.id),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildSmallTag('관찰 ${bird.level}레벨'),
                        if (bird.availableTime.isNotEmpty)
                          _buildSmallTag(bird.availableTime),
                        if (bird.location.isNotEmpty)
                          _buildSmallTag(bird.location, isLocation: true),
                      ],
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildPriceButton(bird.prices),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlantCard(PlantItem plant) {
    final bool isHighlighted = _highlightedId == plant.id;

    return _buildGatheringCardShell(
      isHighlighted: isHighlighted,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCardImage(plant.image, Icons.local_florist),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCardTitle(_displayPlantName(plant), plant.id),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildSmallTag('채집 ${plant.level}레벨'),
                        if (plant.availableTime.isNotEmpty)
                          _buildSmallTag(plant.availableTime),
                        if (plant.location.isNotEmpty)
                          _buildSmallTag(plant.location, isLocation: true),
                      ],
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildPriceButton(plant.prices),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildFishCard(FishItem fish) {
    final bool isHighlighted = _highlightedId == fish.id;
    final fishPrices = [
      fish.price1 ?? 0,
      fish.price2 ?? 0,
      fish.price3 ?? 0,
      fish.price4 ?? 0,
      fish.price5 ?? 0,
    ];

    return _buildGatheringCardShell(
      isHighlighted: isHighlighted,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCardImage(fish.image, Icons.set_meal_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCardTitle(_displayName(fish), fish.id),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (fish.level != null)
                          _buildSmallTag('낚시 ${fish.level}레벨'),
                        if (_timeLabel(fish.availableTime).isNotEmpty)
                          _buildSmallTag(_timeLabel(fish.availableTime)),
                        if (fish.location.isNotEmpty)
                          _buildSmallTag(fish.location, isLocation: true),
                        if (fish.weather != 'Unknown' && fish.weather.isNotEmpty)
                          _buildSmallTag(fish.weather),
                      ],
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildPriceButton(fishPrices),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsectCard(InsectItem insect) {
    final bool isHighlighted = _highlightedId == insect.id;

    return _buildGatheringCardShell(
      isHighlighted: isHighlighted,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCardImage(insect.image, Icons.bug_report),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCardTitle(_displayInsectName(insect), insect.id),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildSmallTag('채집 ${insect.level}레벨'),
                        if (insect.availableTime.isNotEmpty)
                          _buildSmallTag(insect.availableTime),
                        if (insect.location.isNotEmpty)
                          _buildSmallTag(insect.location, isLocation: true),
                      ],
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildPriceButton(insect.prices),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 카드 공통 컨테이너
  Widget _buildBaseContainer({
    required Widget child,
    required String itemId, // ★ 추가
  }) {
    final isHighlighted =
        (_highlightedId?.trim() ?? '') == itemId.trim();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),

      key: ValueKey('${itemId}_$isHighlighted'),

      child: child,
    );
  }

// 카드 내 이미지 박스
  Widget _buildCardImage(String image, IconData fallbackIcon) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          _imageAssetPath(image),
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => Icon(
            fallbackIcon,
            color: Colors.grey,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildCardTitle(String text, String itemId) {
    final isFavorite = _favoriteIds.contains(itemId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _toggleFavorite(itemId),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
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
    );
  }

  // 2. 칩 위젯 생성 함수 (장소 색상 추가 및 쏠림 해결)
  Widget _buildSmallTag(String text,
      {bool isLocation = false, bool isWeather = false}) {
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
        bg = const Color(0xFFEEEEEE);
        border = const Color(0xFFBDBDBD);
        textColor = const Color(0xFF616161);
      } else if (level == 2) {
        bg = const Color(0xFFFFEBEE);
        border = const Color(0xFFFFCDD2);
        textColor = const Color(0xFFC62828);
      }
      else if (level == 3) {
        bg = const Color(0xFFFFF3E0);
        border = const Color(0xFFFFE0B2);
        textColor = const Color(0xFFE65100);
      }
      else if (level == 4) {
        bg = const Color(0xFFFFFDE7);
        border = const Color(0xFFFFF9C4);
        textColor = const Color(0xFFF57F17);
      }
      else if (level == 5) {
        bg = const Color(0xFFE8F5E9);
        border = const Color(0xFFC8E6C9);
        textColor = const Color(0xFF2E7D32);
      }
      else if (level == 6) {
        bg = const Color(0xFFE1F5FE);
        border = const Color(0xFFB3E5FC);
        textColor = const Color(0xFF0277BD);
      }
      else if (level == 7) {
        bg = const Color(0xFFE8EAF6);
        border = const Color(0xFFC5CAE9);
        textColor = const Color(0xFF1A237E);
      }
      else if (level == 8) {
        bg = const Color(0xFFF3E5F5);
        border = const Color(0xFFE1BEE7);
        textColor = const Color(0xFF7B1FA2);
      }
      else if (level == 9) {
        bg = const Color(0xFFFCE4EC);
        border = const Color(0xFFF8BBD0);
        textColor = const Color(0xFFC2185B);
      }
      else { // 10레벨 이상 마스터
        textColor = const Color(0xFF424242);
        border = const Color(0xFFBDBDBD).withOpacity(0.5);
      }
    }
    // B. 시간대 (연분홍/주황 계열 - 따뜻한 느낌)
    else if (rawText == '하루종일' || rawText.contains('~') ||
        lowerText.contains('day') || lowerText.contains('time')) {
      bg = const Color(0xFFFFEDE1);
      border = const Color(0xFFFFCCBC);
      textColor = const Color(0xFFD84315);
    }
    // C. 날씨 (맑음: 노랑 / 비: 파랑 / 흐림: 민트)
    else if (isWeather) {
      if (lowerText.contains('sun') || rawText.contains('맑음')) {
        bg = const Color(0xFFFFF9C4);
        border = const Color(0xFFFFF176);
        textColor = const Color(0xFFF57F17);
      } else if (lowerText.contains('rain') || rawText.contains('비')) {
        bg = const Color(0xFFE1F5FE);
        border = const Color(0xFF81D4FA);
        textColor = const Color(0xFF01579B);
      } else {
        bg = const Color(0xFFE0F2F1);
        border = const Color(0xFF80CBC4);
        textColor = const Color(0xFF00695C);
      }
    }
    // D. 장소 (강: 청록 / 호수·산수: 남색 / 바다·구해: 진파랑)
    else if (isLocation) {
      if (rawText.contains('강') || lowerText.contains('river')) {
        bg = const Color(0xFFE0F7FA);
        border = const Color(0xFF80DEEA);
        textColor = const Color(0xFF006064);
      } else if (rawText.contains('호수') || rawText.contains('산수') ||
          lowerText.contains('lake')) {
        bg = const Color(0xFFE8EAF6);
        border = const Color(0xFF9FA8DA);
        textColor = const Color(0xFF1A237E);
      } else if (rawText.contains('바다') || rawText.contains('구해') ||
          lowerText.contains('sea')) {
        bg = const Color(0xFFE3F2FD);
        border = const Color(0xFF64B5F6);
        textColor = const Color(0xFF0D47A1);
      }
    }

    final bool isMasterLevel = rawText.contains('레벨') && level >= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: isMasterLevel
            ? const LinearGradient(
          colors: [
            Color(0xFFFFD1D1),
            Color(0xFFFFF4D1),
            Color(0xFFD1FFDA),
            Color(0xFFD1E3FF),
            Color(0xFFE5D1FF)
          ],
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
            fontWeight: (isMasterLevel || isLocation)
                ? FontWeight.w700
                : FontWeight.w600,
            height: 1.0,
            fontFamily: 'SF Pro',
          ),
        ),
      ),
    );
  }

  Widget _buildIntegratedAppBar(BuildContext context, double topPadding) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.42, 1.0],
          colors: [
            const Color(0xFFFF8E7C).withOpacity(0.12),
            const Color(0xFFFFCFC7).withOpacity(0.05),
            const Color(0xFFFFFAF8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 8),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAppBarButton(
                    icon: 'assets/icons/ic_menu.svg',
                    onTap: widget.openDrawer,
                  ),
                  _buildAppTitle(),
                  _buildAppBarButton(
                    icon: 'assets/icons/ic_settings.svg',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildTabBar(),
              const SizedBox(height: 8),
              _buildIntegratedSearchBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 38,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.25),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashFactory: NoSplash.splashFactory,
        indicatorAnimation: TabIndicatorAnimation.elastic,
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.black.withOpacity(0.03);
          }
          return Colors.transparent;
        }),
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: const Color(0xFFFF8E7C),
        unselectedLabelColor: const Color(0xFF94A3B8),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          fontFamily: 'SF Pro',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'SF Pro',
        ),
        tabs: const [
          Tab(text: '낚시'),
          Tab(text: '새 관찰'),
          Tab(text: '곤충채집'),
          Tab(text: '자연채집'),
        ],
      ),
    );
  }

  Widget _buildAppBarButton({
    required String icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFA).withOpacity(0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF8E7C).withOpacity(0.07),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SvgPicture.asset(
          icon,
          colorFilter: const ColorFilter.mode(
            Color(0xFF5F6B7A),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '채집',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF2D3436),
            letterSpacing: 0.8,
            fontFamily: 'SF Pro',
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFFFF8E7C),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildGatheringTopTabBar() {
    return Container(
      height: 38,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.25),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashFactory: NoSplash.splashFactory,
        indicatorAnimation: TabIndicatorAnimation.elastic,
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.black.withOpacity(0.03);
          }
          return Colors.transparent;
        }),
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: const Color(0xFFFF8E7C),
        unselectedLabelColor: const Color(0xFF94A3B8),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          fontFamily: 'SF Pro',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'SF Pro',
        ),
        tabs: const [
          Tab(text: '낚시'),
          Tab(text: '새'),
          Tab(text: '곤충'),
          Tab(text: '원예'),
        ],
      ),
    );
  }

  Widget _buildIntegratedSearchBar() {
    String hintText = '이름을 검색해보세요.';
    switch (_tabController.index) {
      case 0:
        hintText = '물고기 이름을 검색해보세요.';
        break;
      case 1:
        hintText = '새 이름을 검색해보세요.';
        break;
      case 2:
        hintText = '곤충 이름을 검색해보세요.';
        break;
      case 3:
        hintText = '자연채집 이름을 검색해보세요.';
        break;
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF4A4543),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          prefixIcon: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFFFF8E7C),
            ),
          ),
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFFA8A29E),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _searchController.clear(),
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterAndSortHeader() {
    final filterList = _getCurrentFilterList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect rect) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.black, Colors.transparent],
                stops: [0.92, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 16, right: 20),
                  children: filterList.map((label) => _buildFilterChip(label)).toList(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final next = _selectedSort == '이름순'
                    ? '가격순'
                    : _selectedSort == '가격순'
                    ? '좋아요순'
                    : '이름순';
                _onSortSelected(next);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedSort,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return AnimatedScale(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      scale: _showTopBtn ? 1.0 : 0.0,
      child: GestureDetector(
        onTap: () => _getCurrentController().animateTo(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutQuart,
        ),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withOpacity(0.05),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.keyboard_arrow_up_rounded,
            color: Color(0xFF64748B),
            size: 26,
          ),
        ),
      ),
    );
  }

  Color _getStarBadgeColor(int star) {
    switch (star) {
      case 1:
        return const Color(0xFFE5E7EB);
      case 2:
        return const Color(0xFFFFE4E6);
      case 3:
        return const Color(0xFFFFEDD5);
      case 4:
        return const Color(0xFFFEF3C7);
      case 5:
        return const Color(0xFFDCFCE7);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  void _showPriceBottomSheet(List<int> prices) {
    final visiblePrices = <Map<String, dynamic>>[];

    for (int i = 0; i < prices.length; i++) {
      if (prices[i] > 0) {
        visiblePrices.add({
          'star': i + 1,
          'price': prices[i],
        });
      }
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.18),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.98),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFFFE1DA),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        size: 16,
                        color: Color(0xFFFF8E7C),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '성급별 판매가',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (visiblePrices.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        '가격 정보 없음',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  )
                else
                  ...visiblePrices.map((item) {
                    final int star = item['star'] as int;
                    final int price = item['price'] as int;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _getStarBadgeColor(star),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$star성',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3F3F46),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_formatPrice(price)}원',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2D3436),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _moveToTopInList<T>(List<T> list, bool Function(T e) match) {
    final index = list.indexWhere(match);
    if (index <= 0) return;
    final selected = list.removeAt(index);
    list.insert(0, selected);
  }


}
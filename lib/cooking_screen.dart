import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/global_search_item.dart';
import 'setting_screen.dart';

class Gourmet {
  final String id;
  final String nameKo;
  final List<String> ingredients;
  final int level;
  final String? image;
  final List<int> prices;

  Gourmet({
    required this.id,
    required this.nameKo,
    required this.ingredients,
    required this.level,
    this.image,
    required this.prices,
  });

  factory Gourmet.fromJson(Map<String, dynamic> json) {
    return Gourmet(
      id: json['id'].toString(),
      nameKo: json['nameKo'] ?? json['name_ko'] ?? '',
      ingredients: (json['ingredients'] as String? ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      image: json['image'],
      prices: [
        int.tryParse((json['price1'] ?? json['price_1'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price2'] ?? json['price_2'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price3'] ?? json['price_3'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price4'] ?? json['price_4'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price5'] ?? json['price_5'] ?? '0').toString()) ?? 0,
      ],
    );
  }
}

class CookingMaterialItem {
  final String id;
  final String nameKo;
  final String? image;
  final bool isCultivable;
  final int level;
  final List<int> prices;

  CookingMaterialItem({
    required this.id,
    required this.nameKo,
    this.image,
    required this.isCultivable,
    required this.level,
    required this.prices,
  });

  factory CookingMaterialItem.fromJson(Map<String, dynamic> json) {
    return CookingMaterialItem(
      id: json['id']?.toString() ?? '',
      nameKo: json['nameKo'] ?? json['name_ko'] ?? '',
      image: json['image'],
      isCultivable: (json['isCultivable'] ?? json['is_cultivable'] ?? 0) == 1,
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      prices: [
        int.tryParse((json['price1'] ?? json['price_1'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price2'] ?? json['price_2'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price3'] ?? json['price_3'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price4'] ?? json['price_4'] ?? '0').toString()) ?? 0,
        int.tryParse((json['price5'] ?? json['price_5'] ?? '0').toString()) ?? 0,
      ],
    );
  }
}

class CookingScreen extends StatefulWidget {
  final VoidCallback? openDrawer;
  final GlobalSearchItem? initialSearchItem;
  final int resetSearchSignal;

  const CookingScreen({
    super.key,
    this.openDrawer,
    this.initialSearchItem,
    this.resetSearchSignal = 0,
  });

  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen>
    with SingleTickerProviderStateMixin {
  static const String _favoritesKey = 'favorite_gourmet_ids';

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _recipeScrollController = ScrollController();
  final ScrollController _materialScrollController = ScrollController();

  String? _highlightedId;
  GlobalSearchItem? _pendingSearchItem;

  String _selectedFilter = '전체';
  String _searchQuery = '';
  String _selectedSort = '이름순';

  List<Gourmet> _allRecipeList = [];
  List<Gourmet> _visibleRecipeList = [];

  List<CookingMaterialItem> _allMaterialList = [];
  List<CookingMaterialItem> _visibleMaterialList = [];

  bool _isRecipeLoading = true;
  bool _isMaterialLoading = true;

  Set<String> _favoriteIds = {};

  final String _recipeApiUrl = 'http://161.33.30.40:8080/api/gourmet';
  // TODO: 백엔드 준비되면 연결
  // final String _materialApiUrl = 'http://161.33.30.40:8080/api/crop';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedFilter = '전체';
        });
        _applyFilters();
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
      _applyFilters();
    });

    _loadFavorites();
    _fetchRecipeData();
    _loadTemporaryMaterialData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSearchItem != null) {
        _pendingSearchItem = widget.initialSearchItem;
        _applySearchItem(widget.initialSearchItem!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant CookingScreen oldWidget) {
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
    _searchController.dispose();
    _recipeScrollController.dispose();
    _materialScrollController.dispose();
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

  Future<void> _toggleFavorite(String id) async {
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
    await _saveFavorites();
    _applyFilters();
  }

  Future<void> _fetchRecipeData() async {
    setState(() => _isRecipeLoading = true);
    try {
      final response = await http.get(Uri.parse(_recipeApiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        _allRecipeList = data.map((json) => Gourmet.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('요리 레시피 로드 실패: $e');
    }
    setState(() => _isRecipeLoading = false);
    _applyFilters();

    if (_pendingSearchItem != null) {
      _applySearchItem(_pendingSearchItem!);
    }
  }

  Future<void> _refreshMaterialData() async {
    _loadTemporaryMaterialData();
  }



  String _normalizeSearchTargetId(String rawId) {
    if (rawId.startsWith('gourmet_')) {
      return rawId.replaceFirst('gourmet_', '');
    }
    if (rawId.startsWith('material_')) {
      return rawId.replaceFirst('material_', '');
    }
    return rawId;
  }

  void _clearHighlightLater() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _highlightedId = null;
      });
    });
  }

  void _scrollToTopForCookingTab(CookingTabType tab) {
    final controller = tab == CookingTabType.material
        ? _materialScrollController
        : _recipeScrollController;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;

      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _moveSelectedItemToTop(GlobalSearchItem item) {
    if (item.cookingTab == null) return;

    final normalizedId = _normalizeSearchTargetId(item.id);

    void moveToTop<T>(List<T> list, bool Function(T e) match) {
      final index = list.indexWhere(match);
      if (index <= 0) return;
      final selected = list.removeAt(index);
      list.insert(0, selected);
    }

    switch (item.cookingTab!) {
      case CookingTabType.recipe:
        moveToTop<Gourmet>(
          _visibleRecipeList,
              (e) => e.id.toString() == normalizedId,
        );
        break;
      case CookingTabType.material:
        moveToTop<CookingMaterialItem>(
          _visibleMaterialList,
              (e) => e.id.toString() == normalizedId,
        );
        break;
    }
  }

  void _applySearchItem(GlobalSearchItem item) {
    _pendingSearchItem = item;

    final normalizedId = _normalizeSearchTargetId(item.id);

    // 🔥 검색 결과 클릭 시 검색창에는 아무 것도 넣지 않음
    _searchController.clear();
    _searchQuery = '';

    if (item.cookingTab == CookingTabType.material) {
      _tabController.animateTo(1);
    } else {
      _tabController.animateTo(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _applyFilters();
      _moveSelectedItemToTop(item);

      setState(() {
        _highlightedId = normalizedId;
      });

      _scrollToTopForCookingTab(item.cookingTab ?? CookingTabType.recipe);

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (_highlightedId == normalizedId) {
          setState(() {
            _highlightedId = null;
          });
        }
      });
    });
  }

  void _clearSearchState() {
    _pendingSearchItem = null;

    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    setState(() {
      _searchQuery = '';
      _highlightedId = null;
      _selectedFilter = '전체';
    });

    _applyFilters();
  }

  void _loadTemporaryMaterialData() {
    _allMaterialList = [
      CookingMaterialItem(
        id: 'tomato',
        nameKo: '토마토',
        image: 'assets/images/ingredient_tomato.png',
        isCultivable: true,
        level: 1,
        prices: [30, 45, 60, 120, 240],
      ),
      CookingMaterialItem(
        id: 'wheat',
        nameKo: '밀',
        image: 'assets/images/ingredient_wheat.png',
        isCultivable: true,
        level: 2,
        prices: [285, 381, 475, 570, 1140],
      ),
      CookingMaterialItem(
        id: 'lettuce',
        nameKo: '상추',
        image: 'assets/images/ingredient_lettuce.png',
        isCultivable: true,
        level: 3,
        prices: [435, 582, 726, 870, 1740],
      ),
      CookingMaterialItem(
        id: 'coffee-bean',
        nameKo: '커피콩',
        image: 'assets/images/ingredient_coffee_bean.png',
        isCultivable: false,
        level: 1,
        prices: [0, 0, 0, 0, 0],
      ),
      CookingMaterialItem(
        id: 'sugar-powder',
        nameKo: '슈가파우더',
        image: 'assets/images/ingredient_sugar_powder.png',
        isCultivable: false,
        level: 1,
        prices: [0, 0, 0, 0, 0],
      ),
      CookingMaterialItem(
        id: 'butter',
        nameKo: '버터',
        image: 'assets/images/ingredient_butter.png',
        isCultivable: false,
        level: 1,
        prices: [0, 0, 0, 0, 0],
      ),
    ];
    _isMaterialLoading = false;
    _applyFilters();

    if (_pendingSearchItem != null) {
      _applySearchItem(_pendingSearchItem!);
    }
  }

  void _onSortSelected(String sort) {
    setState(() {
      _selectedSort = sort;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();

    if (_tabController.index == 0) {
      List<Gourmet> temp = List.from(_allRecipeList);

      if (query.isNotEmpty) {
        final tokens = query
            .replaceAll('_', ' ')
            .split(RegExp(r'\s+'))
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList();

        temp = temp.where((item) {
          final nameKo = item.nameKo.trim().toLowerCase();
          final id = item.id.trim().replaceAll('_', ' ').toLowerCase();

          return tokens.any((token) {
            return nameKo.contains(token) || id.contains(token);
          });
        }).toList();
      }

      if (_selectedFilter == '일반 레시피') {
        temp = temp.where((item) => !_isEventRecipe(item)).toList();
      } else if (_selectedFilter == '히든 레시피') {
        temp = temp.where((item) => _isEventRecipe(item)).toList();
      }

      _sortRecipes(temp);

      setState(() {
        _visibleRecipeList = temp;

        if (_pendingSearchItem != null) {
          _moveSelectedItemToTop(_pendingSearchItem!);
        }
      });
    } else {
      List<CookingMaterialItem> temp = List.from(_allMaterialList);

      if (query.isNotEmpty) {
        final tokens = query
            .replaceAll('_', ' ')
            .split(RegExp(r'\s+'))
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList();

        temp = temp.where((item) {
          final nameKo = item.nameKo.trim().toLowerCase();
          final id = item.id.trim().replaceAll('_', ' ').toLowerCase();

          return tokens.any((token) {
            return nameKo.contains(token) || id.contains(token);
          });
        }).toList();
      }

      if (_selectedFilter == '작물') {
        temp = temp.where((item) => item.isCultivable).toList();
      } else if (_selectedFilter == '상점구매') {
        temp = temp.where((item) => !item.isCultivable).toList();
      }

      _sortMaterials(temp);

      setState(() {
        _visibleMaterialList = temp;

        if (_pendingSearchItem != null) {
          _moveSelectedItemToTop(_pendingSearchItem!);
        }
      });
    }
  }

  void _sortRecipes(List<Gourmet> list) {
    switch (_selectedSort) {
      case '가격순':
        list.sort((a, b) {
          final aPrice = a.prices.isNotEmpty ? a.prices.first : 0;
          final bPrice = b.prices.isNotEmpty ? b.prices.first : 0;
          final priceCompare = bPrice.compareTo(aPrice);
          if (priceCompare != 0) return priceCompare;
          return _displayRecipeName(a).compareTo(_displayRecipeName(b));
        });
        break;
      case '좋아요순':
        list.sort((a, b) {
          final aFav = _favoriteIds.contains(a.id) ? 1 : 0;
          final bFav = _favoriteIds.contains(b.id) ? 1 : 0;
          final favCompare = bFav.compareTo(aFav);
          if (favCompare != 0) return favCompare;
          return _displayRecipeName(a).compareTo(_displayRecipeName(b));
        });
        break;
      case '이름순':
      default:
        list.sort((a, b) => _displayRecipeName(a).compareTo(_displayRecipeName(b)));
    }
  }

  void _sortMaterials(List<CookingMaterialItem> list) {
    switch (_selectedSort) {
      case '가격순':
        list.sort((a, b) {
          final aPrice = a.prices.isNotEmpty ? a.prices.first : 0;
          final bPrice = b.prices.isNotEmpty ? b.prices.first : 0;
          final priceCompare = bPrice.compareTo(aPrice);
          if (priceCompare != 0) return priceCompare;
          return a.nameKo.compareTo(b.nameKo);
        });
        break;
      case '좋아요순':
        list.sort((a, b) {
          final aFav = _favoriteIds.contains(a.id) ? 1 : 0;
          final bFav = _favoriteIds.contains(b.id) ? 1 : 0;
          final favCompare = bFav.compareTo(aFav);
          if (favCompare != 0) return favCompare;
          return a.nameKo.compareTo(b.nameKo);
        });
        break;
      case '이름순':
      default:
        list.sort((a, b) => a.nameKo.compareTo(b.nameKo));
    }
  }

  List<String> _currentFilters() {
    if (_tabController.index == 0) {
      return const ['전체', '일반 레시피', '히든 레시피'];
    }
    return const ['전체', '작물', '상점구매'];
  }

  String _formatPrice(int? price) {
    if (price == null) return '';
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  String _pricePreview(List<int> prices) {
    final valid = prices.where((e) => e > 0).toList();
    if (valid.isEmpty) return '-';

    final minPrice = valid.first;
    final maxPrice = valid.last;

    if (minPrice == maxPrice) {
      return '${_formatPrice(minPrice)}원';
    }
    return '${_formatPrice(minPrice)}원 ~ ${_formatPrice(maxPrice)}원';
  }

  List<PopupMenuEntry<String>> _buildPriceMenuItems(List<int> prices) {
    final items = <PopupMenuEntry<String>>[];

    for (int i = 0; i < prices.length; i++) {
      final value = prices[i];
      if (value > 0) {
        items.add(
          PopupMenuItem<String>(
            value: '${i + 1}성',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${i + 1}성', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 20),
                Text(
                  '${_formatPrice(value)}원',
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

  bool _isEventRecipe(Gourmet item) {
    return item.nameKo.contains('(이벤트)');
  }

  String _displayRecipeName(Gourmet item) {
    return item.nameKo
        .replaceAll(' (이벤트)', '')
        .replaceAll('(이벤트)', '')
        .trim();
  }

  String _ingredientImagePath(String ingredientName) {
    const map = {
      '토마토': 'assets/images/ingredient_tomato.png',
      '감자': 'assets/images/ingredient_potato.png',
      '밀': 'assets/images/ingredient_wheat.png',
      '상추': 'assets/images/ingredient_lettuce.png',
      '당근': 'assets/images/ingredient_carrot.png',
      '옥수수': 'assets/images/ingredient_corn.png',
      '딸기': 'assets/images/ingredient_strawberry.png',
      '포도': 'assets/images/ingredient_grape.png',
      '가지': 'assets/images/ingredient_eggplant.png',
      '사과': 'assets/images/ingredient_apple.png',
      '오렌지': 'assets/images/ingredient_orange.png',
      '파인애플': 'assets/images/ingredient_pineapple.png',
      '블루베리': 'assets/images/ingredient_blueberry.png',
      '라즈베리': 'assets/images/ingredient_raspberry.png',
      '무': 'assets/images/ingredient_radish.png',
      '아보카도': 'assets/images/ingredient_avocado.png',
      '달걀': 'assets/images/ingredient_egg.png',
      '우유': 'assets/images/ingredient_milk.png',
      '치즈': 'assets/images/ingredient_cheese.png',
      '버터': 'assets/images/ingredient_butter.png',
      '고기': 'assets/images/ingredient_meat.png',
      '식용유': 'assets/images/ingredient_oil.png',
      '커피 콩': 'assets/images/ingredient_coffee_bean.png',
      '커피 원두': 'assets/images/ingredient_coffee_bean.png',
      '슈가파우더': 'assets/images/ingredient_sugar_powder.png',
      '보라 설탕': 'assets/images/ingredient_purple_sugar.png',
      '빨간 설탕': 'assets/images/ingredient_red_sugar.png',
      '주황 설탕': 'assets/images/ingredient_orange_sugar.png',
      '노란 설탕': 'assets/images/ingredient_yellow_sugar.png',
      '초록 설탕': 'assets/images/ingredient_green_sugar.png',
      '파란 설탕': 'assets/images/ingredient_sky_sugar.png',
      '남색 설탕': 'assets/images/ingredient_blue_sugar.png',
      '느타리버섯': 'assets/images/ingredient_oyster_mushroom.png',
      '표고버섯': 'assets/images/ingredient_shiitake.png',
      '양송이버섯': 'assets/images/ingredient_button_mushroom.png',
      '그물버섯': 'assets/images/ingredient_morel.png',
      '블랙 트러플': 'assets/images/ingredient_black_truffle.png',
      '아무 채소': 'assets/images/icon_veg_any.png',
      '아무 생선': 'assets/images/icon_fish_any.png',
      '아무 버섯': 'assets/images/icon_mushroom_any.png',
      '혼합 과일': 'assets/images/icon_fruit_any.png',
      '아무 과일': 'assets/images/icon_fruit_any.png',
      '아무 설탕': 'assets/images/icon_sugar_any.png',
      '아무 조개류': 'assets/images/icon_shellfish_any.png',
      '아무 랍스터': 'assets/images/icon_lobster_any.png',
      '아무 킹크랩': 'assets/images/icon_king_crab_any.png',
      '아무 커피': 'assets/images/icon_coffee_any.png',
      '아무 커피재료': 'assets/images/icon_coffee_any.png',
      '아무 얼음컵 커피': 'assets/images/icon_coffee_any.png',
      '아무 슈가파우더 팬케이크': 'assets/images/icon_pancake_any.png',
      '아무 잼재료': 'assets/images/icon_jam_any.png',
      '아무 음식': 'assets/images/icon_food_any.png',
      '아무 음료': 'assets/images/icon_drink_any.png',
    };

    return map[ingredientName] ?? 'assets/images/default.png';
  }

  Widget _buildIngredientItem(String imagePath) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: const Color(0xC6FFF8E7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) =>
            const Icon(Icons.broken_image, size: 16, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildIngredientIcons(List<String> ingredients) {
    final List<Widget> widgets = [];

    for (final raw in ingredients) {
      final text = raw.trim();
      if (text.isEmpty || text == '----') continue;

      final reg1 = RegExp(r'^(.*?)\s*\((\d+)\)$');
      final reg2 = RegExp(r'^(.*?)\s*x\s*(\d+)$');
      final reg3 = RegExp(r'^(.*?)\s*(\d+)개$');
      final reg4 = RegExp(r'^(.*?)\s*×\s*(\d+)$');

      String name = text;
      int count = 1;

      final m1 = reg1.firstMatch(text);
      final m2 = reg2.firstMatch(text);
      final m3 = reg3.firstMatch(text);
      final m4 = reg4.firstMatch(text);

      if (m1 != null) {
        name = m1.group(1)!.trim();
        count = int.tryParse(m1.group(2)!) ?? 1;
      } else if (m2 != null) {
        name = m2.group(1)!.trim();
        count = int.tryParse(m2.group(2)!) ?? 1;
      } else if (m3 != null) {
        name = m3.group(1)!.trim();
        count = int.tryParse(m3.group(2)!) ?? 1;
      } else if (m4 != null) {
        name = m4.group(1)!.trim();
        count = int.tryParse(m4.group(2)!) ?? 1;
      }

      final imagePath = _ingredientImagePath(name);

      for (int i = 0; i < count; i++) {
        widgets.add(_buildIngredientItem(imagePath));
      }
    }

    return widgets;
  }

  Widget _buildSmallTag(String text, {bool isEvent = false}) {
    final rawText = text.trim();

    // 기본값 (일반 태그 색상)
    Color bg = Colors.white;
    Color border = Colors.black.withOpacity(0.08);
    Color textColor = const Color(0xFF898989);

    bool isHiddenActive = text.contains('있음');

    // 히든 레시피 또는 이벤트 태그 처리
    if (isHiddenActive || isEvent) {
      bg = const Color(0xFFFFDED9);
      border = const Color(0xFFFF7A65).withOpacity(0.2);
      textColor = const Color(0xFF555655);
    }

    // ★ 레벨별 색상 로직 (GatheringScreen과 동일)
    int level = 0;
    if (rawText.contains('레벨')) {
      level = int.tryParse(rawText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

      if (level == 1) {
        bg = const Color(0xFFEEEEEE); border = const Color(0xFFBDBDBD); textColor = const Color(0xFF616161);
      } else if (level == 2) {
        bg = const Color(0xFFFFEBEE); border = const Color(0xFFFFCDD2); textColor = const Color(0xFFC62828);
      } else if (level == 3) {
        bg = const Color(0xFFFFF3E0); border = const Color(0xFFFFE0B2); textColor = const Color(0xFFE65100);
      } else if (level == 4) {
        bg = const Color(0xFFFFFDE7); border = const Color(0xFFFFF9C4); textColor = const Color(0xFFF57F17);
      } else if (level == 5) {
        bg = const Color(0xFFE8F5E9); border = const Color(0xFFC8E6C9); textColor = const Color(0xFF2E7D32);
      } else if (level == 6) {
        bg = const Color(0xFFE1F5FE); border = const Color(0xFFB3E5FC); textColor = const Color(0xFF0277BD);
      } else if (level == 7) {
        bg = const Color(0xFFE8EAF6); border = const Color(0xFFC5CAE9); textColor = const Color(0xFF1A237E);
      } else if (level == 8) {
        bg = const Color(0xFFF3E5F5); border = const Color(0xFFE1BEE7); textColor = const Color(0xFF7B1FA2);
      } else if (level == 9) {
        bg = const Color(0xFFFCE4EC); border = const Color(0xFFF8BBD0); textColor = const Color(0xFFC2185B);
      } else { // 10레벨 이상 마스터
        textColor = const Color(0xFF424242);
        border = const Color(0xFFBDBDBD).withOpacity(0.5);
      }
    }

    final bool isMasterLevel = rawText.contains('레벨') && level >= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        border: Border.all(color: border),
      ),
      child: Text(
        rawText,
        style: TextStyle(
          fontSize: 9,
          color: textColor,
          fontWeight: (isMasterLevel || isHiddenActive || isEvent) ? FontWeight.bold : FontWeight.w400,
          height: 1.0,
        ),
      ),
    );
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
              _buildSearchBar(
                hint: _tabController.index == 0
                    ? '요리 레시피를 검색해보세요.'
                    : '요리 재료를 검색해보세요.',
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRecipeTabContent(),
                    _buildMaterialTabContent(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeTabContent() {
    if (_isRecipeLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF8E7C)),
      );
    }

    if (_visibleRecipeList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchRecipeData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text(
                '검색 결과가 없어요.',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRecipeData,
      child: SingleChildScrollView(
        controller: _recipeScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          children: [
            _buildFilterBarArea(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  ..._visibleRecipeList.map((item) => _buildRecipeCard(item)),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialTabContent() {
    if (_isMaterialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF8E7C)),
      );
    }

    if (_visibleMaterialList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshMaterialData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text(
                '검색 결과가 없어요.',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshMaterialData,
      child: SingleChildScrollView(
        controller: _materialScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          children: [
            _buildFilterBarArea(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  ..._visibleMaterialList.map((item) => _buildMaterialCard(item)),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Gourmet item) {
    final isFavorite = _favoriteIds.contains(item.id);
    final priceText = _pricePreview(item.prices);
    final isHighlighted = _highlightedId == item.id.toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ShapeDecoration(
        color: isHighlighted
            ? const Color(0xFFFFF4D8)
            : Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isHighlighted
                ? const Color(0xFFFF9E58)
                : Colors.transparent,
            width: 1.6,
          ),
        ),
        shadows: [
          BoxShadow(
            color: isHighlighted
                ? const Color(0xFFFFC785).withOpacity(0.45)
                : Colors.black.withOpacity(0.06),
            spreadRadius: 1.0,
            blurRadius: isHighlighted ? 18 : 14,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: SizedBox(
        height: 148,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: item.image != null && item.image!.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/${item.image!}',
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.restaurant_menu,
                        color: Colors.grey,
                      ),
                    ),
                  )
                      : const Icon(
                    Icons.restaurant_menu,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayRecipeName(item),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    _buildSmallTag('요리 ${item.level}레벨'),
                                    if (_isEventRecipe(item))
                                      _buildSmallTag('이벤트', isEvent: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () => _toggleFavorite(item.id),
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
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _buildIngredientIcons(item.ingredients),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<String>(
                          itemBuilder: (context) =>
                              _buildPriceMenuItems(item.prices),
                          offset: const Offset(0, 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                constraints: const BoxConstraints(minWidth: 46),
                                height: 20,
                                alignment: Alignment.center,
                                padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFFF7A65)
                                        .withOpacity(0.5),
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
                                priceText,
                                style: const TextStyle(
                                  fontSize: 14,
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

  Widget _buildMaterialCard(CookingMaterialItem item) {
    final isFavorite = _favoriteIds.contains(item.id);
    final priceText = _pricePreview(item.prices);
    final isHighlighted = _highlightedId == item.id.toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ShapeDecoration(
        color: isHighlighted
            ? const Color(0xFFFFF4D8)
            : Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isHighlighted
                ? const Color(0xFFFF9E58)
                : Colors.transparent,
            width: 1.6,
          ),
        ),
        shadows: [
          BoxShadow(
            color: isHighlighted
                ? const Color(0xFFFFC785).withOpacity(0.45)
                : Colors.black.withOpacity(0.06),
            spreadRadius: 1.0,
            blurRadius: isHighlighted ? 18 : 14,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: item.image != null && item.image!.isNotEmpty
                        ? Image.asset(
                      item.image!,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.spa_outlined,
                        color: Colors.grey,
                      ),
                    )
                        : const Icon(
                      Icons.spa_outlined,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.nameKo,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    _buildSmallTag('요리 ${item.level}레벨'),
                                    _buildSmallTag(
                                      item.isCultivable ? '작물' : '상점구매',
                                      isEvent: !item.isCultivable,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () => _toggleFavorite(item.id),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          PopupMenuButton<String>(
                            itemBuilder: (context) =>
                                _buildPriceMenuItems(item.prices),
                            offset: const Offset(0, 28),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    constraints:
                                    const BoxConstraints(minWidth: 46),
                                    height: 20,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFFFF7A65)
                                            .withOpacity(0.5),
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
                                    priceText,
                                    style: const TextStyle(
                                      fontSize: 14,
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
            '요리',
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
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
            Tab(text: '요리 레시피'),
            Tab(text: '요리 재료'),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterBarArea() {
    final filters = _currentFilters();

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
                  children: filters.map((f) => _buildFilterChip(f)).toList(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: PopupMenuButton<String>(
              onSelected: _onSortSelected,
              itemBuilder: (context) => const [
                PopupMenuItem(value: '이름순', child: Text('이름순')),
                PopupMenuItem(value: '가격순', child: Text('가격순')),
                PopupMenuItem(value: '좋아요순', child: Text('좋아요순')),
              ],
              offset: const Offset(0, 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                  const Icon(Icons.keyboard_arrow_down,
                      size: 16, color: Color(0xFF616161)),
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
          onSelected: (bool selected) {
            setState(() {
              _selectedFilter = label;
            });
            _applyFilters();
          },
          labelStyle: TextStyle(
            color: isSelected
                ? const Color(0xFF555655)
                : const Color(0xFF333333),
            fontSize: 12,
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
              width: 1.0,
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
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              splashRadius: 16,
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
                _applyFilters();
              },
              icon: const Icon(
                Icons.close,
                size: 18,
                color: Color(0xFFB0B0B0),
              ),
            )
                : null,
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
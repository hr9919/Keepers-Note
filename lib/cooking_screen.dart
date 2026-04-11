import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/global_search_item.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'map_screen.dart';
import 'setting_screen.dart';
import 'dart:ui';

String _normalizeIngredientDisplayName(String raw) {
  final value = raw.trim().toLowerCase();

  const aliases = {
    'black truffle': '검은 트러플',
    'black_truffle': '검은 트러플',
    'black-truffle': '검은 트러플',
    '블랙 트러플': '검은 트러플',
    '블랙트러플': '검은 트러플',

    'blueberry': '블루베리',
    'apple': '사과',
    'orange': '오렌지',
    'pineapple': '파인애플',
    'avocado': '아보카도',
    'raspberry': '라즈베리',

    'shiitake': '표고버섯',
    '표고 버섯': '표고버섯',

    'button mushroom': '양송이버섯',
    'button_mushroom': '양송이버섯',
    'button-mushroom': '양송이버섯',
    'mousseron': '양송이버섯',
    '양송이 버섯': '양송이버섯',

    'oyster mushroom': '느타리버섯',
    'oyster_mushroom': '느타리버섯',
    'oyster-mushroom': '느타리버섯',
    '느타리 버섯': '느타리버섯',

    'penny bun': '그물버섯',
    'penny_bun': '그물버섯',
    'penny-bun': '그물버섯',
    'porcini': '그물버섯',
    'morel': '그물버섯',
    '그물 버섯': '그물버섯',

    'tomato sauce': '케첩',
    'tomato_sauce': '케첩',
    'tomato-sauce': '케첩',

    '토마토소스': '케첩',
    '토마토 소스': '케첩',

    '케찹': '케첩',

    'mushroom': '아무 버섯',
    '버섯': '아무 버섯',
  };

  return aliases[value] ?? raw;
}

String _ingredientFallbackAssetPath(String ingredientName) {
  final normalized = _normalizeIngredientDisplayName(ingredientName).trim();

  const map = {
    // 과일류
    '사과': 'assets/images/resources/apple.png',
    '블루베리': 'assets/images/resources/blueberry.png',
    '라즈베리': 'assets/images/resources/raspberry.png',
    '오렌지': 'assets/images/resources/orange.png',
    '파인애플': 'assets/images/resources/pineapple.png',
    '아보카도': 'assets/images/crops/avocado.webp',

    // 버섯류
    '검은 트러플': 'assets/images/resources/black-truffle.png',
    '표고버섯': 'assets/images/resources/shiitake.png',
    '양송이버섯': 'assets/images/resources/mousseron.png',
    '느타리버섯': 'assets/images/resources/oyster-mushroom.png',
    '그물버섯': 'assets/images/resources/porcini.png',
    '아무 버섯': 'assets/images/icon_mushroom_any.png',

    // 작물류
    '감자': 'assets/images/crops/potato.webp',
    '밀': 'assets/images/crops/wheat.webp',
    '상추': 'assets/images/crops/lettuce.webp',
    '당근': 'assets/images/crops/carrot.webp',
    '옥수수': 'assets/images/crops/corn.webp',
    '딸기': 'assets/images/crops/strawberry.webp',
    '포도': 'assets/images/crops/grape.webp',
    '가지': 'assets/images/crops/eggplant.webp',
    '토마토': 'assets/images/crops/tomato.webp',
    '양파': 'assets/images/crops/onion.webp',
    '호박': 'assets/images/crops/pumpkin.webp',
    '수박': 'assets/images/crops/watermelon.webp',
    '무': 'assets/images/crops/white-radish.webp',

    // 상점구매 / ingredients 폴더
    '버터': 'assets/images/ingredients/butter.webp',
    '치즈': 'assets/images/ingredients/cheese.webp',
    '커피 콩': 'assets/images/ingredients/coffee-beans.webp',
    '커피콩': 'assets/images/ingredients/coffee-beans.webp',
    '식용유': 'assets/images/ingredients/cooking-oil.webp',
    '요리용 기름': 'assets/images/ingredients/cooking-oil.webp',
    '달걀': 'assets/images/ingredients/egg.webp',
    '계란': 'assets/images/ingredients/egg.webp',
    '살균 달걀': 'assets/images/ingredients/pasteurized-egg.webp',
    '우유': 'assets/images/ingredients/milk.webp',
    '고기': 'assets/images/ingredients/meat.webp',
    '슈가파우더': 'assets/images/ingredients/frosted.webp',
    '설탕가루': 'assets/images/ingredients/frosted.webp',
    '프로스티드': 'assets/images/ingredients/frosted.webp',
    '말차가루': 'assets/images/ingredients/matcha-powder.webp',
    '말차 파우더': 'assets/images/ingredients/matcha-powder.webp',
    '쌀가루': 'assets/images/ingredients/rice-flour.webp',
    '살사소스': 'assets/images/ingredients/salsa-sauce.webp',
    '살사 소스': 'assets/images/ingredients/salsa-sauce.webp',
    '찻잎': 'assets/images/ingredients/tea-leaves.webp',
    '차잎': 'assets/images/ingredients/tea-leaves.webp',
    '티트리': 'assets/images/ingredients/tea-leaves.webp',

    // 색 사탕류
    '노란색 사탕': 'assets/images/ingredients/yellow-sugar.webp',
    '노랑 사탕': 'assets/images/ingredients/yellow-sugar.webp',
    '초록색 사탕': 'assets/images/ingredients/green-sugar.webp',
    '초록 사탕': 'assets/images/ingredients/green-sugar.webp',
    '파란색 사탕': 'assets/images/ingredients/blue-sugar.webp',
    '파랑 사탕': 'assets/images/ingredients/blue-sugar.webp',
    '남색 사탕': 'assets/images/ingredients/indigo-sugar.webp',
    '인디고 사탕': 'assets/images/ingredients/indigo-sugar.webp',
    '보라색 사탕': 'assets/images/ingredients/violet-sugar.webp',
    '보라 사탕': 'assets/images/ingredients/violet-sugar.webp',
    '주황색 사탕': 'assets/images/ingredients/orange-sugar.webp',
    '주황 사탕': 'assets/images/ingredients/orange-sugar.webp',
    '빨간색 사탕': 'assets/images/ingredients/red-sugar.webp',
    '빨강 사탕': 'assets/images/ingredients/red-sugar.webp',
    '빨간 콩': 'assets/images/ingredients/red-bean.webp',
    '레드빈': 'assets/images/ingredients/red-bean.webp',
    '봄날 카라멜 슈가': 'assets/images/ingredients/springday-brown-sugar.webp',

    // 완성 요리인데 다른 요리 재료로도 쓰이는 것들
    '케첩': 'assets/images/gourmet/ketchup.png',
    '마요': 'assets/images/gourmet/mayonnaise.png',
    '잼': 'assets/images/gourmet/jam.png',
    '토마토소스': 'assets/images/gourmet/tomato-sauce.png',
    '토마토 소스': 'assets/images/gourmet/tomato-sauce.png',

    // 범용 아이콘
    '아무 채소': 'assets/images/icon_veg_any.png',
    '아무 생선': 'assets/images/icon_fish_any.png',
    '혼합 과일': 'assets/images/icon_fruit_any.png',
    '아무 과일': 'assets/images/icon_fruit_any.png',
    '아무 설탕': 'assets/images/icon_sugar_any.png',
    '아무 조개류': 'assets/images/icon_shellfish_any.png',
    '아무 랍스터': 'assets/images/icon_lobster_any.png',
    '아무 킹크랩': 'assets/images/icon_king_crab_any.png',
    '아무 커피': 'assets/images/icon_coffee_any.png',
    '아무 음식': 'assets/images/icon_food_any.png',
    '아무 음료': 'assets/images/icon_drink_any.png',
  };

  return map[normalized] ?? 'assets/images/default.png';
}

String _resolveIngredientImagePath(String? imagePath) {
  if (imagePath == null || imagePath.trim().isEmpty) return '';

  final raw = imagePath.trim();

  if (raw.startsWith('assets/')) return raw;
  return 'assets/$raw';
}

Widget _buildIngredientImage({
  required String ingredientNameKo,
  String? imagePath,
  double padding = 4,
  double iconSize = 16,
}) {
  final resolvedPath = _resolveIngredientImagePath(imagePath);
  final fallbackPath = _ingredientFallbackAssetPath(ingredientNameKo);

  if (resolvedPath.isNotEmpty) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Image.asset(
        resolvedPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Padding(
            padding: EdgeInsets.all(padding),
            child: Image.asset(
              fallbackPath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.broken_image,
                size: iconSize,
                color: Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }

  return Padding(
    padding: EdgeInsets.all(padding),
    child: Image.asset(
      fallbackPath,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.broken_image,
        size: iconSize,
        color: Colors.grey,
      ),
    ),
  );
}

class RecipeIngredientDetail {
  final int ingredientRowId;
  final int sortOrder;
  final String ingredientNameKo;
  final int quantity;
  final String? targetType;
  final String? targetId;
  final bool isNavigable;
  final String? image;
  final bool isCultivable;
  final int level;
  final List<int> prices;

  RecipeIngredientDetail({
    required this.ingredientRowId,
    required this.sortOrder,
    required this.ingredientNameKo,
    required this.quantity,
    this.targetType,
    this.targetId,
    required this.isNavigable,
    this.image,
    required this.isCultivable,
    required this.level,
    required this.prices,
  });

  factory RecipeIngredientDetail.fromJson(Map<String, dynamic> json) {
    final rawName = (json['ingredientNameKo'] ?? '').toString();
    final displayName = _normalizeIngredientDisplayName(rawName);

    return RecipeIngredientDetail(
      ingredientRowId: int.tryParse(json['ingredientRowId']?.toString() ?? '0') ?? 0,
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '0') ?? 0,
      ingredientNameKo: displayName,
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      targetType: json['targetType']?.toString(),
      targetId: json['targetId']?.toString(),
      isNavigable: (json['isNavigable'] ?? false) == true,
      image: json['image']?.toString(),
      isCultivable: (json['isCultivable'] ?? false) == true,
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

class CookingMaterialDetail {
  final String id;
  final String nameKo;
  final String? image;
  final bool isCultivable;
  final int level;
  final List<int> prices;

  CookingMaterialDetail({
    required this.id,
    required this.nameKo,
    this.image,
    required this.isCultivable,
    required this.level,
    required this.prices,
  });

  factory CookingMaterialDetail.fromJson(Map<String, dynamic> json) {
    return CookingMaterialDetail(
      id: json['id']?.toString() ?? '',
      nameKo: (json['nameKo'] ?? json['name_ko'] ?? '').toString(),
      image: json['image']?.toString(),
      isCultivable: (json['isCultivable'] ?? json['is_cultivable'] ?? false) == true,
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

class RelatedRecipe {
  final String id;
  final String nameKo;
  final String? image;
  final int level;
  final List<int> prices;

  RelatedRecipe({
    required this.id,
    required this.nameKo,
    this.image,
    required this.level,
    required this.prices,
  });

  factory RelatedRecipe.fromJson(Map<String, dynamic> json) {
    return RelatedRecipe(
      id: json['id']?.toString() ?? '',
      nameKo: (json['nameKo'] ?? json['name_ko'] ?? '').toString(),
      image: json['image']?.toString(),
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

class RecipeIngredientSummary {
  final String? targetId;
  final String ingredientNameKo;
  final String? image;
  final int quantity;

  RecipeIngredientSummary({
    required this.targetId,
    required this.ingredientNameKo,
    this.image,
    required this.quantity,
  });

  factory RecipeIngredientSummary.fromJson(Map<String, dynamic> json) {
    final rawName = (json['ingredientNameKo'] ?? '').toString();

    return RecipeIngredientSummary(
      targetId: json['targetId']?.toString(),
      ingredientNameKo: _normalizeIngredientDisplayName(rawName),
      image: json['image']?.toString(),
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
    );
  }
}

class Gourmet {
  final String id;
  final String nameKo;
  final List<String> ingredients;
  final List<RecipeIngredientSummary> ingredientSummaries;
  final int level;
  final String? image;
  final List<int> prices;

  Gourmet({
    required this.id,
    required this.nameKo,
    required this.ingredients,
    required this.ingredientSummaries,
    required this.level,
    this.image,
    required this.prices,
  });

  factory Gourmet.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? summariesJson =
    json['ingredientSummaries'] as List<dynamic>?;

    return Gourmet(
      id: json['id'].toString(),
      nameKo: (json['nameKo'] ?? json['name_ko'] ?? '').toString(),
      ingredients: (json['ingredients'] as String? ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      ingredientSummaries: summariesJson == null
          ? []
          : summariesJson
          .map((e) => RecipeIngredientSummary.fromJson(
        e as Map<String, dynamic>,
      ))
          .toList(),
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      image: json['image']?.toString(),
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
    final dynamic raw = json['isCultivable'] ?? json['is_cultivable'];

    bool parsedCultivable;
    if (raw is bool) {
      parsedCultivable = raw;
    } else if (raw is num) {
      parsedCultivable = raw == 1;
    } else if (raw is String) {
      parsedCultivable = raw == '1' || raw.toLowerCase() == 'true';
    } else {
      parsedCultivable = false;
    }

    return CookingMaterialItem(
      id: json['id']?.toString() ?? '',
      nameKo: (json['nameKo'] ?? json['name_ko'] ?? '').toString(),
      image: json['image']?.toString(),
      isCultivable: parsedCultivable,
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

class _CookingScreenState extends State<CookingScreen> with SingleTickerProviderStateMixin {
  static const String _favoritesKey = 'favorite_gourmet_ids';

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _recipeScrollController = ScrollController();
  final ScrollController _materialScrollController = ScrollController();


  void _dismissSearchFocus() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

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
  bool _isFilterVisible = true;
  bool _showTopBtn = false;
  bool _isRefreshing = false;

  String? _mapFilterKeyForMaterial(String nameKo) {
    final normalized = _normalizeIngredientDisplayName(nameKo);

    const exactMap = {
      '사과': 'apple',
      '블루베리': 'blueberry',
      '라즈베리': 'raspberry',
      '오렌지': 'orange',
      '파인애플': 'pineapple',
      '아보카도': 'avocado',

      '검은 트러플': 'black-truffle',
      '표고버섯': 'shiitake',
      '양송이버섯': 'mousseron',
      '느타리버섯': 'oyster-mushroom',
      '그물버섯': 'porcini',
    };

    if (normalized == '아무 버섯') {
      return 'mushroom';
    }

    return exactMap[normalized];
  }

  Set<String> _favoriteIds = {};
  final Color snackAccent = const Color(0xFFFF8E7C);
  final String _recipeApiUrl = 'http://161.33.30.40:8080/api/gourmet';
  final String _materialApiUrl = 'http://161.33.30.40:8080/api/cooking/materials';
  final String _cookingApiBaseUrl = 'http://161.33.30.40:8080/api/cooking';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedFilter = '전체');
        _applyFilters();
      }
    });

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
      _applyFilters();
    });

    void _scrollListener(ScrollController controller) {
      if (!controller.hasClients) return;
      final bool showBtn = controller.offset > 100;
      if (showBtn != _showTopBtn) {
        setState(() => _showTopBtn = showBtn);
      }
      if (controller.offset <= 5 && !_isFilterVisible) {
        setState(() => _isFilterVisible = true);
      }
    }

    _recipeScrollController.addListener(() => _scrollListener(_recipeScrollController));
    _materialScrollController.addListener(() => _scrollListener(_materialScrollController));

    _attachScrollListener(_recipeScrollController);
    _attachScrollListener(_materialScrollController);

    _loadFavorites();
    _fetchRecipeData();
    _fetchMaterialData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSearchItem != null) {
        _applySearchItem(widget.initialSearchItem!);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _recipeScrollController.dispose();
    _materialScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    final bool showFilterInAppBar = _isFilterVisible;
    final double appBarHeight = topPadding +
        (showFilterInAppBar ? 214 : 170);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissSearchFocus,
        child: Stack(
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
                  SizedBox(height: appBarHeight - 22),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildRecipeTabContent(),
                        _buildMaterialTabContent(),
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
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              right: 20,
              bottom: keyboardInset > 0 ? 24 : 140,
              child: _buildScrollToTopButton(),
            ),
          ],
        ),
      ),
    );
  }

  ScrollController _getCurrentController() {
    if (_tabController.index == 0) return _recipeScrollController;
    return _materialScrollController;
  }

  // --- 통합 UI 함수 (도감 디자인) ---
  Widget _buildIntegratedAppBar(BuildContext context, double topPadding) {
    final bool showFilterInAppBar = _isFilterVisible;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF8E7C).withOpacity(0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFF8E7C).withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _buildAppBarButton(
                            icon: 'assets/icons/ic_menu.svg',
                            onTap: widget.openDrawer ?? () {},
                          ),
                          const Spacer(),
                          _buildAppTitle(),
                          const Spacer(),
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
                      const SizedBox(height: 10),
                      _buildTabBar(),
                      const SizedBox(height: 8),
                      _buildIntegratedSearchBar(),
                      if (showFilterInAppBar) ...[
                        const SizedBox(height: 10),
                        _buildFilterBarArea(),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 18,
                  right: 18,
                  child: IgnorePointer(
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8E7C).withOpacity(0.62),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return const Text(
      '요리',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2D3436),
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF3D8D1),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
        splashBorderRadius: BorderRadius.circular(18),
        indicatorAnimation: TabIndicatorAnimation.elastic,
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.black.withOpacity(0.03);
          }
          return Colors.transparent;
        }),
        indicator: BoxDecoration(
          color: const Color(0xFFFFF1EC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFFDDD4),
            width: 1,
          ),
        ),
        labelColor: const Color(0xFFFF8E7C),
        unselectedLabelColor: const Color(0xFF94A3B8),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          fontFamily: 'SF Pro',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'SF Pro',
        ),
        tabs: const [
          Tab(text: '레시피'),
          Tab(text: '재료'),
        ],
      ),
    );
  }

  Widget _buildIntegratedSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF1DED8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2D3436),
        ),
        decoration: InputDecoration(
          hintText: _tabController.index == 0
              ? '음식 이름을 검색해보세요.'
              : '요리 재료를 검색해보세요.',
          hintStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9AA4B2),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFFE58F7C),
            size: 24,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            splashRadius: 18,
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFFB0B8C4),
              size: 20,
            ),
            onPressed: () {
              _searchController.clear();
              _dismissSearchFocus();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 13,
          ),
        ),
        onTapOutside: (_) => _dismissSearchFocus(),
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return AnimatedScale(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      scale: _showTopBtn ? 1.0 : 0.0,
      child: GestureDetector(
        onTap: () => _getCurrentController().animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutQuart),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), shape: BoxShape.circle, border: Border.all(color: Colors.black.withOpacity(0.05), width: 0.8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
          child: const Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFF64748B), size: 26),
        ),
      ),
    );
  }

  Widget _buildAppBarButton({
    required String icon,
    required VoidCallback onTap,
  }) {
    final bool isMenu = icon.contains('menu');

    return Material(
      color: isMenu
          ? const Color(0xFFFFF3F0)
          : const Color(0xFFF2F7FF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMenu
                  ? const Color(0xFFFFE2DB)
                  : const Color(0xFFDCEBFF),
              width: 1,
            ),
          ),
          child: SvgPicture.asset(
            icon,
            width: 17,
            height: 17,
            colorFilter: ColorFilter.mode(
              isMenu
                  ? const Color(0xFFFF8E7C)
                  : const Color(0xFF4A90E2),
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }

  // --- 리스트 탭 콘텐츠 ---
  Widget _buildRecipeTabContent() {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        if (_recipeScrollController.offset < 20 || _isRefreshing) {
          if (!_isFilterVisible) setState(() => _isFilterVisible = true);
          return false;
        }
        if (notification.scrollDelta! > 2 && _isFilterVisible) setState(() => _isFilterVisible = false);
        else if (notification.scrollDelta! < -2 && !_isFilterVisible) setState(() => _isFilterVisible = true);
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async { setState(() => _isRefreshing = true); await _fetchRecipeData(); if (mounted) setState(() => _isRefreshing = false); },
        color: snackAccent,
        child: _isRecipeLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8E7C)))
            : ListView.builder(
          controller: _recipeScrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 180),
          itemCount: _visibleRecipeList.length,
          itemBuilder: (context, index) => _buildRecipeCard(_visibleRecipeList[index]),
        ),
      ),
    );
  }

  Widget _buildMaterialTabContent() {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        if (_materialScrollController.offset < 20 || _isRefreshing) {
          if (!_isFilterVisible) setState(() => _isFilterVisible = true);
          return false;
        }
        if (notification.scrollDelta! > 2 && _isFilterVisible) {
          setState(() => _isFilterVisible = false);
        } else if (notification.scrollDelta! < -2 && !_isFilterVisible) {
          setState(() => _isFilterVisible = true);
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isRefreshing = true);
          await _refreshMaterialData();
          if (mounted) setState(() => _isRefreshing = false);
        },
        color: snackAccent,
        child: _isMaterialLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF8E7C),
          ),
        )
            : _visibleMaterialList.isEmpty
            ? ListView(
          controller: _materialScrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 180),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFFFE2DB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EE),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: Color(0xFFFF8E7C),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _selectedFilter == '상점구매'
                        ? '상점 재료는 준비중이에요'
                        : '표시할 재료가 없어요',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedFilter == '상점구매'
                        ? '상점 재료 데이터가 추가되면 여기에서 볼 수 있어요.'
                        : '검색어나 필터를 다시 확인해보세요.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
            : ListView.builder(
          controller: _materialScrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 180),
          itemCount: _visibleMaterialList.length,
          itemBuilder: (context, index) =>
              _buildMaterialCard(_visibleMaterialList[index]),
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

  void _attachScrollListener(ScrollController controller) {
    double lastOffset = 0;

    controller.addListener(() {
      if (!mounted || !controller.hasClients) return;

      final offset = controller.offset;

      if (offset <= 8) {
        if (!_isFilterVisible) {
          setState(() => _isFilterVisible = true);
        }
        lastOffset = offset;
        return;
      }

      final delta = offset - lastOffset;

      if (delta > 4 && _isFilterVisible) {
        setState(() => _isFilterVisible = false);
      } else if (delta < -4 && !_isFilterVisible) {
        setState(() => _isFilterVisible = true);
      }

      lastOffset = offset;
    });
  }

  void _openMapForMaterialResource(String resourceFilterKey) {
    _dismissSearchFocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          openFilterOnStart: false,
          initialEnabledResourceKeys: {resourceFilterKey},
          initialShowAllNpcs: false,
          initialShowAllAnimals: false,
        ),
      ),
    );
  }

  void _showPriceBottomSheet(List<int> prices) {
    _dismissKeyboard();

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
      builder: (dialogContext) {
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
                      onTap: () {
                        _dismissKeyboard();
                        Navigator.pop(dialogContext);
                      },
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
    ).then((_) {
      if (!mounted) return;
      _dismissKeyboard();
    });
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

  // 2. [교정] 레시피 카드 내 판매가 위치 (채집 탭 레이아웃 이식)
  Widget _buildRecipeCard(Gourmet item) {
    final isFavorite = _favoriteIds.contains(item.id);
    final isHighlighted = _highlightedId == item.id;
    final recipeImagePath = _resolveIngredientImagePath(item.image);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: isHighlighted
              ? const Color(0xFFFFF4D8)
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: const Color(0xFFFF8E7C).withOpacity(0.08),
            highlightColor: const Color(0xFFFF8E7C).withOpacity(0.04),
            onTap: () => _openRecipeDetail(item),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isHighlighted
                      ? const Color(0xFFFFB27A).withOpacity(0.6)
                      : const Color(0xFFFF8E7C).withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFAF8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF8E7C).withOpacity(0.15),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: recipeImagePath.isNotEmpty
                            ? Image.asset(
                          recipeImagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.restaurant_menu,
                            color: Colors.grey,
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
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 116),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2, right: 8),
                                    child: AutoSizeText(
                                      _displayRecipeName(item),
                                      maxLines: 2,
                                      minFontSize: 12,
                                      stepGranularity: 0.5,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF333333),
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleFavorite(item.id),
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: 24,
                                      color: isFavorite
                                          ? const Color(0xFFFF8E7C)
                                          : const Color(0xFFD9D9D9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 5,
                                    runSpacing: 4,
                                    children: [
                                      _buildSmallTag('요리 ${item.level}레벨'),
                                      if (_isEventRecipe(item))
                                        _buildSmallTag('이벤트', isEvent: true),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Padding(
                                  padding: EdgeInsets.only(right: 2),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 22,
                                    color: Color(0xFFB8C2CC),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 34,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: item.ingredientSummaries.isNotEmpty
                                      ? _buildIngredientSummaryIcons(
                                    item.ingredientSummaries,
                                  )
                                      : _buildIngredientIcons(item.ingredients),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _buildPriceButton(item.prices),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPurchasePriceButton(int price) {
    final String priceText =
    price > 0 ? '${_formatPrice(price)}원' : '-';

    return Container(
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
              '구매가',
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
            priceText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3436),
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(CookingMaterialItem item) {
    final isFavorite = _favoriteIds.contains(item.id);
    final isHighlighted = _highlightedId == item.id;

    final bool isShopItem = _isShopMaterial(item);
    final String typeLabel = isShopItem ? '상점구매' : '작물';
    final int purchasePrice = _shopPurchasePrice(item.prices);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: isHighlighted
              ? const Color(0xFFFFF4D8)
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: const Color(0xFFFF8E7C).withOpacity(0.08),
            highlightColor: const Color(0xFFFF8E7C).withOpacity(0.04),
            onTap: () => _openMaterialDetail(item),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isHighlighted
                      ? const Color(0xFFFFB27A).withOpacity(0.55)
                      : const Color(0xFFFF8E7C).withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
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
                          child: _buildIngredientImage(
                            ingredientNameKo: item.nameKo,
                            imagePath: item.image,
                            padding: 8,
                            iconSize: 28,
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
                                    child: Text(
                                      item.nameKo,
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
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => _toggleFavorite(item.id),
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: 24,
                                      color: isFavorite
                                          ? const Color(0xFFFF8E7C)
                                          : const Color(0xFFD9D9D9),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Padding(
                                  padding: EdgeInsets.only(top: 2, right: 2),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 21,
                                    color: Color(0xFFB8C2CC),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (!isShopItem)
                                  _buildSmallTag('원예 ${item.level}레벨'),
                                _buildSmallTag(typeLabel, isEvent: isShopItem),
                              ],
                            ),
                            const Spacer(),
                            Align(
                              alignment: Alignment.centerRight,
                              child: isShopItem
                                  ? _buildPurchasePriceButton(purchasePrice)
                                  : _buildPriceButton(item.prices),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();

    if (_tabController.index == 0) {
      List<Gourmet> filtered = List<Gourmet>.from(_allRecipeList);

      if (query.isNotEmpty) {
        filtered = filtered.where((item) {
          final nameKo = item.nameKo.toLowerCase();
          final id = item.id.toLowerCase();
          final ingredients =
          item.ingredients.map((e) => e.toLowerCase()).join(' ');
          return nameKo.contains(query) ||
              id.contains(query) ||
              ingredients.contains(query);
        }).toList();
      }

      if (_selectedFilter != '전체') {
        if (_selectedFilter == '이벤트') {
          filtered = filtered.where((item) => _isEventRecipe(item)).toList();
        }
      }

      switch (_selectedSort) {
        case '가격순':
          filtered.sort((a, b) {
            final aPrice = a.prices.where((e) => e > 0).isEmpty
                ? 0
                : a.prices.where((e) => e > 0).first;
            final bPrice = b.prices.where((e) => e > 0).isEmpty
                ? 0
                : b.prices.where((e) => e > 0).first;
            return aPrice.compareTo(bPrice);
          });
          break;
        case '좋아요순':
          filtered.sort((a, b) {
            final aFav = _favoriteIds.contains(a.id) ? 1 : 0;
            final bFav = _favoriteIds.contains(b.id) ? 1 : 0;
            return bFav.compareTo(aFav);
          });
          break;
        case '이름순':
        default:
          filtered.sort((a, b) => a.nameKo.compareTo(b.nameKo));
          break;
      }

      if (!mounted) return;
      setState(() {
        _visibleRecipeList = filtered;
      });
      return;
    }

    List<CookingMaterialItem> filtered =
    List<CookingMaterialItem>.from(_allMaterialList);

    if (query.isNotEmpty) {
      filtered = filtered.where((item) {
        final nameKo = item.nameKo.toLowerCase();
        final id = item.id.toLowerCase();
        return nameKo.contains(query) || id.contains(query);
      }).toList();
    }

    if (_selectedFilter == '작물') {
      filtered = filtered.where((item) => item.isCultivable).toList();
    } else if (_selectedFilter == '상점구매') {
      filtered = filtered.where((item) => !item.isCultivable).toList();
    }

    switch (_selectedSort) {
      case '가격순':
        filtered.sort((a, b) {
          final aPrice = a.prices.where((e) => e > 0).isEmpty
              ? 0
              : a.prices.where((e) => e > 0).first;
          final bPrice = b.prices.where((e) => e > 0).isEmpty
              ? 0
              : b.prices.where((e) => e > 0).first;
          return aPrice.compareTo(bPrice);
        });
        break;
      case '좋아요순':
        filtered.sort((a, b) {
          final aFav = _favoriteIds.contains(a.id) ? 1 : 0;
          final bFav = _favoriteIds.contains(b.id) ? 1 : 0;
          return bFav.compareTo(aFav);
        });
        break;
      case '이름순':
      default:
        filtered.sort((a, b) => a.nameKo.compareTo(b.nameKo));
        break;
    }

    if (!mounted) return;
    setState(() {
      _visibleMaterialList = filtered;
    });
  }



  // --- 공통 카드 헬퍼 (레벨별 컬러 복구) ---
  String _ingredientImagePath(String ingredientName) {
    const map = {
      '토마토': 'assets/images/ingredient_tomato.png', '감자': 'assets/images/ingredient_potato.png', '밀': 'assets/images/ingredient_wheat.png',
      '상추': 'assets/images/ingredient_lettuce.png', '당근': 'assets/images/ingredient_carrot.png', '옥수수': 'assets/images/ingredient_corn.png',
      '딸기': 'assets/images/ingredient_strawberry.png', '포도': 'assets/images/ingredient_grape.png', '가지': 'assets/images/ingredient_eggplant.png',
      '사과': 'assets/images/ingredient_apple.png', '오렌지': 'assets/images/ingredient_orange.png', '파인애플': 'assets/images/ingredient_pineapple.png',
      '블루베리': 'assets/images/ingredient_blueberry.png', '라즈베리': 'assets/images/ingredient_raspberry.png', '무': 'assets/images/ingredient_radish.png',
      '아보카도': 'assets/images/ingredient_avocado.png', '달걀': 'assets/images/ingredient_egg.png', '우유': 'assets/images/ingredient_milk.png',
      '치즈': 'assets/images/ingredient_cheese.png', '버터': 'assets/images/ingredient_butter.png', '고기': 'assets/images/ingredient_meat.png',
      '식용유': 'assets/images/ingredient_oil.png', '커피 콩': 'assets/images/ingredient_coffee_bean.png', '슈가파우더': 'assets/images/ingredient_sugar_powder.png',
      '아무 채소': 'assets/images/icon_veg_any.png', '아무 생선': 'assets/images/icon_fish_any.png', '아무 버섯': 'assets/images/icon_mushroom_any.png',
      '혼합 과일': 'assets/images/icon_fruit_any.png', '아무 과일': 'assets/images/icon_fruit_any.png', '아무 설탕': 'assets/images/icon_sugar_any.png',
      '아무 조개류': 'assets/images/icon_shellfish_any.png', '아무 랍스터': 'assets/images/icon_lobster_any.png', '아무 킹크랩': 'assets/images/icon_king_crab_any.png',
      '아무 커피': 'assets/images/icon_coffee_any.png', '아무 음식': 'assets/images/icon_food_any.png', '아무 음료': 'assets/images/icon_drink_any.png',
    };
    return map[ingredientName] ?? 'assets/images/default.png';
  }

  List<Widget> _buildIngredientIcons(List<String> ingredients) {
    final List<Widget> widgets = [];
    for (final raw in ingredients) {
      final text = raw.trim();
      if (text.isEmpty || text == '----') continue;
      final reg = RegExp(r'^(.*?)\s*[\(x×]?\s*(\d+)?\)?$');
      final match = reg.firstMatch(text);
      String name = text; int count = 1;
      if (match != null) { name = match.group(1)!.trim(); count = int.tryParse(match.group(2) ?? '1') ?? 1; }
      final imagePath = _ingredientImagePath(name);
      for (int i = 0; i < count; i++) {
        widgets.add(Container(
          width: 32, height: 32, margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: const Color(0xC6FFF8E7), borderRadius: BorderRadius.circular(4)),
          child: Center(child: Padding(padding: const EdgeInsets.all(4.0), child: Image.asset(imagePath, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 16, color: Colors.grey)))),
        ));
      }
    }
    return widgets;
  }

  List<Widget> _buildIngredientSummaryIcons(
      List<RecipeIngredientSummary> ingredients,
      ) {
    final List<Widget> widgets = [];

    for (final ingredient in ingredients) {
      final count = ingredient.quantity <= 0 ? 1 : ingredient.quantity;

      for (int i = 0; i < count; i++) {
        widgets.add(
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: const Color(0xC6FFF8E7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: _buildIngredientImage(
                ingredientNameKo: ingredient.ingredientNameKo,
                imagePath: ingredient.image,
                padding: 4,
                iconSize: 16,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildSmallTag(String text, {bool isEvent = false}) {
    final rawText = text.trim();
    final lowerText = rawText.toLowerCase();

    // 기본값 (회색)
    Color bg = const Color(0xFFF5F5F5);
    Color border = const Color(0xFFE0E0E0);
    Color textColor = const Color(0xFF757575);

    bool isHiddenActive = text.contains('있음');

    // 1. 이벤트 또는 히든 레시피 태그 (주황/분홍 톤)
    if (isHiddenActive || isEvent) {
      bg = const Color(0xFFFFEDE1);
      border = const Color(0xFFFFCCBC);
      textColor = const Color(0xFFD84315);
    }

    // 2. ★ 요리 레벨별 무지개 색상 로직 (채집 코드 규격 이식)
    if (rawText.contains('레벨')) {
      int level = int.tryParse(rawText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

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

    final bool isMasterLevel = rawText.contains('레벨') && (int.tryParse(rawText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) >= 10;

    return Container(
      // [교정] 채집 화면과 동일한 콤팩트 패딩 (가로 7, 세로 2.5)
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
        // [교정] 폰트 크기와 수직 정렬을 채집 화면 기준으로 통일
        offset: const Offset(0, -0.5),
        child: Text(
          rawText,
          style: TextStyle(
            fontSize: 9.5, // 9 -> 9.5로 미세 조정
            color: textColor,
            fontWeight: (isMasterLevel || isHiddenActive || isEvent) ? FontWeight.w700 : FontWeight.w600,
            height: 1.0,
            fontFamily: 'SF Pro',
          ),
        ),
      ),
    );
  }

  bool _isShopMaterial(CookingMaterialItem item) => !item.isCultivable;

  int _shopPurchasePrice(List<int> prices) {
    for (final price in prices) {
      if (price > 0) return price;
    }
    return 0;
  }

  String _formatPrice(int? price) {
    if (price == null) return '0';
    return price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  List<PopupMenuEntry<String>> _buildPriceMenuItems(List<int> prices) {
    final items = <PopupMenuEntry<String>>[];

    for (int i = 0; i < prices.length; i++) {
      final value = prices[i];
      if (value > 0) {
        items.add(
          PopupMenuItem<String>(
            enabled: false, // 클릭할 필요 없는 정보용이므로 비활성화(색상은 유지)
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // 성급 표시 (별 아이콘 + 텍스트)
                  Icon(Icons.star_rounded, size: 16, color: Colors.orange[400]),
                  const SizedBox(width: 4),
                  Text(
                    '${i + 1}성',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        fontFamily: 'SF Pro'
                    ),
                  ),
                  const Spacer(),
                  // 가격 텍스트
                  Text(
                    '${_formatPrice(value)}원',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF2D3436),
                        fontFamily: 'SF Pro'
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        // 마지막 아이템이 아니면 얇은 구분선 추가
        if (i < prices.where((e) => e > 0).length - 1) {
          items.add(const PopupMenuDivider(height: 1));
        }
      }
    }

    if (items.isEmpty) {
      items.add(
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('가격 정보 없음', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ),
      );
    }

    return items;
  }

  // --- 데이터 및 필터 로직 ---
  Future<void> _openMaterialDetail(CookingMaterialItem item) async {
    await _openMaterialDetailById(item.id);
  }

  Future<void> _openMaterialDetailById(String materialId) async {
    try {
      final detailRes = await http.get(
        Uri.parse('$_cookingApiBaseUrl/materials/$materialId'),
      );
      final recipesRes = await http.get(
        Uri.parse('$_cookingApiBaseUrl/materials/$materialId/recipes'),
      );

      if (detailRes.statusCode != 200 || recipesRes.statusCode != 200) {
        debugPrint(
          '재료 상세 조회 실패: detail=${detailRes.statusCode}, recipes=${recipesRes.statusCode}',
        );
        return;
      }

      final detail = CookingMaterialDetail.fromJson(
        jsonDecode(utf8.decode(detailRes.bodyBytes)),
      );

      final List<dynamic> recipesJson =
      jsonDecode(utf8.decode(recipesRes.bodyBytes));

      final relatedRecipes = recipesJson
          .map((e) => RelatedRecipe.fromJson(e))
          .toList();

      final String? mapFilterKey = _mapFilterKeyForMaterial(detail.nameKo);
      final bool isMapGatherable = mapFilterKey != null;

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CookingMaterialDetailPage(
            material: detail,
            relatedRecipes: relatedRecipes,
            isMapGatherable: isMapGatherable,
            onOpenMap: mapFilterKey == null
                ? null
                : () {
              Navigator.pop(context);
              _openMapForMaterialResource(mapFilterKey);
            },
            onRecipeTap: (recipeId) {
              Navigator.pop(context);

              final matched = relatedRecipes.where((e) => e.id == recipeId);
              final String? displayName =
              matched.isNotEmpty ? matched.first.nameKo : null;

              _jumpToRecipeById(
                recipeId,
                displayName: displayName,
              );
            },
            onRecipeOpenDetail: (recipeId) async {
              Navigator.pop(context);
              final matched = _allRecipeList.where((e) => e.id == recipeId);
              if (matched.isNotEmpty) {
                await _openRecipeDetail(matched.first);
              }
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('재료 상세 로드 실패: $e');
    }
  }

  Future<void> _openRecipeDetail(Gourmet item) async {
    try {
      final response = await http.get(
        Uri.parse('$_cookingApiBaseUrl/recipes/${item.id}/ingredients'),
      );

      if (response.statusCode != 200) {
        debugPrint('레시피 상세 조회 실패: ${response.statusCode}');
        return;
      }

      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      final ingredients = data
          .map((e) => RecipeIngredientDetail.fromJson(e))
          .toList();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CookingRecipeDetailPage(
            recipe: item,
            ingredients: ingredients,
            onIngredientTap: (ingredientId) {
              final matched = ingredients.where((e) => e.targetId == ingredientId);
              if (matched.isEmpty) return;

              final ingredient = matched.first;

              if (!mounted) return;
              Navigator.pop(context);

              final String? mapFilterKey =
              _mapFilterKeyForMaterial(ingredient.ingredientNameKo);

              if (mapFilterKey != null) {
                _openMapForMaterialResource(mapFilterKey);
                return;
              }

              if (ingredient.targetId != null && ingredient.targetId!.isNotEmpty) {
                _jumpToMaterialById(
                  ingredient.targetId!,
                  displayName: ingredient.ingredientNameKo,
                );
              }
            },
            onMaterialOpenDetail: (ingredientId) async {
              if (!mounted) return;
              Navigator.pop(context);
              await _openMaterialDetailById(ingredientId);
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('레시피 상세 로드 실패: $e');
    }
  }

  Future<void> _refreshMaterialData() async {
    await _fetchMaterialData();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_favoritesKey) ?? [];
    setState(() => _favoriteIds = stored.toSet());
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favoriteIds.toList());
  }

  Future<void> _toggleFavorite(String id) async {
    setState(() { if (_favoriteIds.contains(id)) _favoriteIds.remove(id); else _favoriteIds.add(id); });
    await _saveFavorites(); _applyFilters();
  }

  Future<void> _fetchRecipeData() async {
    setState(() => _isRecipeLoading = true);
    try {
      final response = await http.get(Uri.parse(_recipeApiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        _allRecipeList = data.map((json) => Gourmet.fromJson(json)).toList();
      }
    } catch (e) { debugPrint('로드 실패: $e'); }
    setState(() => _isRecipeLoading = false); _applyFilters();
  }

  Future<void> _fetchMaterialData() async {
    setState(() => _isMaterialLoading = true);

    try {
      final response = await http.get(Uri.parse(_materialApiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        _allMaterialList = data
            .map((json) => CookingMaterialItem.fromJson(json))
            .toList();
      }
    } catch (e) {
      debugPrint('요리 재료 로드 실패: $e');
    }

    if (!mounted) return;
    setState(() => _isMaterialLoading = false);
    _applyFilters();

    if (_pendingSearchItem != null) {
      _applySearchItem(_pendingSearchItem!);
    }
  }

  void _jumpToRecipeById(String recipeId, {String? displayName}) {
    _pendingSearchItem = null;

    final query = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : recipeId;

    _searchController.text = query;
    _searchQuery = query.toLowerCase();

    _tabController.animateTo(0);
    _applyFilters();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _highlightedId = recipeId;
      });

      _scrollToTopForCookingTab(CookingTabType.recipe);

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (_highlightedId == recipeId) {
          setState(() => _highlightedId = null);
        }
      });
    });
  }

  void _jumpToMaterialById(String materialId, {String? displayName}) {
    _pendingSearchItem = null;

    final query = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : materialId;

    _searchController.text = query;
    _searchQuery = query.toLowerCase();

    _tabController.animateTo(1);
    _applyFilters();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _highlightedId = materialId;
      });

      _scrollToTopForCookingTab(CookingTabType.material);

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (_highlightedId == materialId) {
          setState(() => _highlightedId = null);
        }
      });
    });
  }

  void _sortRecipes(List<Gourmet> list) {
    if (_selectedSort == '가격순') list.sort((a, b) => b.prices.first.compareTo(a.prices.first));
    else if (_selectedSort == '좋아요순') list.sort((a, b) => (_favoriteIds.contains(b.id) ? 1 : 0).compareTo(_favoriteIds.contains(a.id) ? 1 : 0));
    else list.sort((a, b) => a.nameKo.compareTo(b.nameKo));
  }

  void _sortMaterials(List<CookingMaterialItem> list) {
    if (_selectedSort == '가격순') list.sort((a, b) => b.prices.first.compareTo(a.prices.first));
    else if (_selectedSort == '좋아요순') list.sort((a, b) => (_favoriteIds.contains(b.id) ? 1 : 0).compareTo(_favoriteIds.contains(a.id) ? 1 : 0));
    else list.sort((a, b) => a.nameKo.compareTo(b.nameKo));
  }

  List<String> _currentFilters() => _tabController.index == 0
      ? const ['전체', '일반 레시피', '히든 레시피']
      : const ['전체', '작물', '상점구매', '버섯', '물고기', '곤충', '기타'];

  void _onSortSelected(String sort) { setState(() => _selectedSort = sort); _applyFilters(); }

  void _applySearchItem(GlobalSearchItem item) {
    _pendingSearchItem = item;

    if (item.cookingTab == null) return;

    final normalizedId = _normalizeSearchTargetId(item.id);

    _searchController.clear();
    _searchQuery = '';

    if (item.cookingTab == CookingTabType.material) {
      _tabController.animateTo(1);

      if (item.cookingMaterialCategory != null) {
        switch (item.cookingMaterialCategory!) {
          case CookingMaterialCategoryType.crop:
            _selectedFilter = '작물';
            break;
          case CookingMaterialCategoryType.store:
            _selectedFilter = '상점구매';
            break;
          case CookingMaterialCategoryType.mushroom:
            _selectedFilter = '버섯';
            break;
          case CookingMaterialCategoryType.fish:
            _selectedFilter = '물고기';
            break;
          case CookingMaterialCategoryType.insect:
            _selectedFilter = '곤충';
            break;
          case CookingMaterialCategoryType.etc:
            _selectedFilter = '기타';
            break;
        }
      }
    } else {
      _tabController.animateTo(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _applyFilters();

      setState(() {
        _highlightedId = normalizedId;
      });

      _scrollToTopForCookingTab(item.cookingTab!);

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;

        if (_highlightedId == normalizedId) {
          setState(() {
            _highlightedId = null;
          });
        }

        _pendingSearchItem = null;
      });
    });
  }

  Widget _buildFilterBarArea() {
    final filters = _currentFilters();

    if (!filters.contains(_selectedFilter) && filters.isNotEmpty) {
      _selectedFilter = filters.first;
    }

    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 4, right: 16),
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return _buildFilterChip(filters[index]);
              },
            ),
          ),
          const SizedBox(width: 10),
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<String>(
              onSelected: _onSortSelected,
              color: Colors.white,
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(
                  color: Color(0xFFE9EEF4),
                  width: 1,
                ),
              ),
              itemBuilder: (context) => [
                _buildSortPopupItem('이름순'),
                _buildSortPopupItem('가격순'),
                _buildSortPopupItem('좋아요순'),
              ],
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: null,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 4,
                    right: 4,
                    top: 7,
                    bottom: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedSort,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildSortPopupItem(String value) {
    final bool isSelected = _selectedSort == value;

    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected
                    ? const Color(0xFFFF8E7C)
                    : const Color(0xFF5B5652),
              ),
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_rounded,
              size: 16,
              color: Color(0xFFFF8E7C),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool isSelected = _selectedFilter == label;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (_selectedFilter == label) return;
          setState(() {
            _selectedFilter = label;
          });
          _applyFilters();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFF1EC)
                : Colors.white.withOpacity(0.76),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFFDDD4)
                  : const Color(0xFFE9EEF4),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: const Color(0xFFFF8E7C).withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.8,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFFFF8E7C)
                    : const Color(0xFF667085),
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isEventRecipe(Gourmet item) => item.nameKo.contains('(이벤트)');
  String _displayRecipeName(Gourmet item) => item.nameKo.replaceAll(' (이벤트)', '').replaceAll('(이벤트)', '').trim();

  void _dismissKeyboard() {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
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
}

class CookingRecipeDetailPage extends StatelessWidget {
  final Gourmet recipe;
  final List<RecipeIngredientDetail> ingredients;
  final ValueChanged<String> onIngredientTap;
  final ValueChanged<String> onMaterialOpenDetail;

  const CookingRecipeDetailPage({
    super.key,
    required this.recipe,
    required this.ingredients,
    required this.onIngredientTap,
    required this.onMaterialOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double horizontalPadding = 32;
    final double chipSpacing = 10 * 3;
    final double cardWidth =
        (screenWidth - horizontalPadding - chipSpacing) / 4;

    final String displayName = _displayRecipeName(recipe);
    final String heroImagePath = _resolveRecipeHeroImage(recipe);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFAF8),
        elevation: 0,
        title: Text(
          displayName,
          style: const TextStyle(
            color: Color(0xFF2D3436),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2D3436)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFE2DB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6D8),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: heroImagePath.isNotEmpty
                          ? Image.asset(
                        heroImagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            _buildIngredientImage(
                              ingredientNameKo: displayName,
                              imagePath: null,
                              padding: 14,
                              iconSize: 56,
                            ),
                      )
                          : _buildIngredientImage(
                        ingredientNameKo: displayName,
                        imagePath: null,
                        padding: 14,
                        iconSize: 56,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(width: double.infinity),
                Text(
                  '레시피 · 요리 ${recipe.level}레벨',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF8E7C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '필요 재료',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ingredients.map((ingredient) {
              return GestureDetector(
                onTap: ingredient.isNavigable && ingredient.targetId != null
                    ? () => onIngredientTap(ingredient.targetId!)
                    : null,
                onLongPress: ingredient.isNavigable && ingredient.targetId != null
                    ? () => onMaterialOpenDetail(ingredient.targetId!)
                    : null,
                child: Container(
                  width: cardWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6D8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFE7A8)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildIngredientImage(
                            ingredientNameKo: ingredient.ingredientNameKo,
                            imagePath: ingredient.image,
                            padding: 6,
                            iconSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 34,
                        child: Center(
                          child: Text(
                            ingredient.ingredientNameKo,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2D3436),
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'x${ingredient.quantity}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C6F57),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          const Text(
            '탭하면 재료 목록으로 이동, 길게 누르면 재료 상세',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _displayRecipeName(Gourmet recipe) {
    final name = (recipe.nameKo ?? '').trim();

    // "(이벤트)" 제거
    return name.replaceAll('(이벤트)', '').trim();
  }

  String _resolveRecipeHeroImage(Gourmet recipe) {
    final raw = recipe.image ?? '';

    if (raw.isEmpty) {
      return 'assets/images/default.png';
    }

    // 이미 assets 경로면 그대로
    if (raw.startsWith('assets/')) {
      return raw;
    }

    // DB 경로 → assets 붙이기
    return 'assets/$raw';
  }
}

class CookingMaterialDetailPage extends StatelessWidget {
  final CookingMaterialDetail material;
  final List<RelatedRecipe> relatedRecipes;
  final bool isMapGatherable;
  final VoidCallback? onOpenMap;
  final ValueChanged<String> onRecipeTap;
  final ValueChanged<String> onRecipeOpenDetail;

  const CookingMaterialDetailPage({
    super.key,
    required this.material,
    required this.relatedRecipes,
    required this.isMapGatherable,
    required this.onOpenMap,
    required this.onRecipeTap,
    required this.onRecipeOpenDetail,
  });

  int _shopPurchasePrice(List<int> prices) {
    for (final price in prices) {
      if (price > 0) return price;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final int purchasePrice = _shopPurchasePrice(material.prices);
    final String purchasePriceText =
    purchasePrice > 0 ? '${purchasePrice}원' : '-';

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFAF8),
        elevation: 0,
        title: Text(
          material.nameKo,
          style: const TextStyle(
            color: Color(0xFF2D3436),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2D3436)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFE2DB)),
            ),
            child: Column(
              children: [
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6D8),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: _buildIngredientImage(
                      ingredientNameKo: material.nameKo,
                      imagePath: material.image,
                      padding: 14,
                      iconSize: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  material.nameKo,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),

                if (material.isCultivable)
                  Text(
                    '작물 · 원예 ${material.level}레벨',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF8E7C),
                    ),
                  )
                else
                  Column(
                    children: [
                      const Text(
                        '상점구매 재료',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF8E7C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3EE),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Text(
                                '구매가',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFF7A65),
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              purchasePriceText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2D3436),
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                if (isMapGatherable) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFE7A8)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.explore_outlined,
                          color: Color(0xFFFF8E7C),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '이 재료는 채집으로 획득 가능해요. 지도에서 위치를 확인할 수 있어요.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5B4A2F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onOpenMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('지도에서 위치 보기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8E7C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '이 재료로 만들 수 있는 요리',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 10),
          ...relatedRecipes.map((recipe) {
            final validPrices = recipe.prices.where((e) => e > 0).toList();
            final priceText = validPrices.isEmpty
                ? '-'
                : validPrices.first == validPrices.last
                ? '${validPrices.first}원'
                : '${validPrices.first}원 ~ ${validPrices.last}원';

            final recipeImagePath = _resolveIngredientImagePath(recipe.image);

            return GestureDetector(
              onTap: () => onRecipeTap(recipe.id),
              onLongPress: () => onRecipeOpenDetail(recipe.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFE2DB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6D8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: recipeImagePath.isNotEmpty
                            ? Image.asset(
                          recipeImagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.restaurant_menu_rounded),
                        )
                            : const Icon(Icons.restaurant_menu_rounded),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AutoSizeText(
                            recipe.nameKo,
                            maxLines: 1,
                            minFontSize: 10,
                            stepGranularity: 0.5,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2D3436),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '요리 ${recipe.level}레벨',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF8E7C),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            priceText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
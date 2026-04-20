import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/global_search_item.dart';

class GlobalSearchService {
  static const String _baseUrl = 'https://api.keepers-note.o-r.kr';

  static Future<List<GlobalSearchItem>> loadAllItems() async {
    final List<GlobalSearchItem> results = [];
    final Set<String> addedIds = {};

    try {
      await _loadFish(results, addedIds);
      await _loadInsects(results, addedIds);
      await _loadBirds(results, addedIds);
      await _loadPlants(results, addedIds);
      await _loadGourmetRecipes(results, addedIds);
      await _loadCookingMaterials(results, addedIds);
    } catch (e) {
      print('전체 검색 데이터 로드 실패: $e');
    }

    return results;
  }

  static List<GlobalSearchItem> filter(
      List<GlobalSearchItem> source,
      String query,
      ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final filtered = source.where((item) {
      return item.keyword.contains(q) || item.title.toLowerCase().contains(q);
    }).toList();

    filtered.sort((a, b) {
      final aTitle = a.title.toLowerCase();
      final bTitle = b.title.toLowerCase();

      final aStarts = aTitle.startsWith(q);
      final bStarts = bTitle.startsWith(q);
      if (aStarts != bStarts) return aStarts ? -1 : 1;

      final aExact = aTitle == q;
      final bExact = bTitle == q;
      if (aExact != bExact) return aExact ? -1 : 1;

      return a.title.length.compareTo(b.title.length);
    });

    return filtered.take(8).toList();
  }

  static Future<void> _loadFish(
      List<GlobalSearchItem> results,
      Set<String> addedIds,
      ) async {
    final res = await http.get(Uri.parse('$_baseUrl/api/fish'));
    if (res.statusCode != 200) return;

    final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
    for (final e in data) {
      final item = GlobalSearchItem(
        id: 'fish_${e['id']}',
        title: _displayName(e),
        subtitle: '채집 · 낚시',
        iconPath: _assetPath(e['image']),
        screen: SearchTargetScreen.gathering,
        gatheringTab: GatheringTabType.fish,
        keyword: _keywordOf(e),
      );
      _addIfNotExists(results, addedIds, item);
    }
  }

  static Future<void> _loadInsects(
      List<GlobalSearchItem> results,
      Set<String> addedIds,
      ) async {
    final res = await http.get(Uri.parse('$_baseUrl/api/insects'));
    if (res.statusCode != 200) return;

    final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
    for (final e in data) {
      final item = GlobalSearchItem(
        id: 'insect_${e['id']}',
        title: _displayName(e),
        subtitle: '채집 · 곤충 채집',
        iconPath: _assetPath(e['image']),
        screen: SearchTargetScreen.gathering,
        gatheringTab: GatheringTabType.insect,
        keyword: _keywordOf(e),
      );
      _addIfNotExists(results, addedIds, item);
    }
  }

  static Future<void> _loadBirds(
      List<GlobalSearchItem> results,
      Set<String> addedIds,
      ) async {
    final res = await http.get(Uri.parse('$_baseUrl/api/birds'));
    if (res.statusCode != 200) return;

    final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
    for (final e in data) {
      final item = GlobalSearchItem(
        id: 'bird_${e['id']}',
        title: _displayName(e),
        subtitle: '채집 · 새 관찰',
        iconPath: _assetPath(e['image']),
        screen: SearchTargetScreen.gathering,
        gatheringTab: GatheringTabType.bird,
        keyword: _keywordOf(e),
      );
      _addIfNotExists(results, addedIds, item);
    }
  }

  static Future<void> _loadPlants(
      List<GlobalSearchItem> results,
      Set<String> addedIds,
      ) async {
    final res = await http.get(Uri.parse('$_baseUrl/api/gardening'));
    if (res.statusCode != 200) return;

    final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
    for (final e in data) {
      final item = GlobalSearchItem(
        id: 'plant_${e['id']}',
        title: _displayName(e),
        subtitle: '채집 · 원예',
        iconPath: _assetPath(e['image']),
        screen: SearchTargetScreen.gathering,
        gatheringTab: GatheringTabType.plant,
        keyword: _keywordOf(e),
      );
      _addIfNotExists(results, addedIds, item);
    }
  }

  static Future<void> _loadGourmetRecipes(
      List<GlobalSearchItem> results,
      Set<String> addedIds,
      ) async {
    final res = await http.get(Uri.parse('$_baseUrl/api/gourmet'));
    if (res.statusCode != 200) return;

    final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));

    for (final e in data) {
      final rawName = (e['nameKo'] ?? e['name_ko'] ?? e['name'] ?? '')
          .toString()
          .trim();

      final displayName = rawName
          .replaceAll(' (이벤트)', '')
          .replaceAll('(이벤트)', '')
          .trim();

      final isEvent = rawName.contains('(이벤트)');

      final item = GlobalSearchItem(
        id: 'gourmet_${e['id']}',
        title: displayName,
        subtitle: isEvent ? '요리 · 레시피 · 이벤트' : '요리 · 레시피',
        iconPath: _recipeAssetPath(e['image']),
        screen: SearchTargetScreen.cooking,
        cookingTab: CookingTabType.recipe,
        keyword: '$displayName $rawName ${e['name'] ?? ''}'.toLowerCase(),
      );

      _addIfNotExists(results, addedIds, item);
    }
  }

  static Future<void> _loadCookingMaterials(
      List<GlobalSearchItem> results,
      Set<String> addedIds,
      ) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/cooking/materials'),
    );
    if (res.statusCode != 200) return;

    final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));

    for (final e in data) {
      final String idValue =
      (e['id'] ?? e['name'] ?? e['nameKo'] ?? e['name_ko'] ?? '')
          .toString();

      final String displayName = _displayName(e);
      final CookingMaterialCategoryType category =
      _inferMaterialCategory(displayName);

      final item = GlobalSearchItem(
        id: 'material_$idValue',
        title: displayName,
        subtitle: _materialSubtitle(category),
        iconPath: _assetPath(e['image']),
        screen: SearchTargetScreen.cooking,
        cookingTab: CookingTabType.material,
        cookingMaterialCategory: category,
        keyword: _keywordOf(e),
      );

      _addIfNotExists(results, addedIds, item);
    }
  }

  static CookingMaterialCategoryType _inferMaterialCategory(String name) {
    final normalized = name.trim().toLowerCase();

    const cropKeywords = [
      '감자',
      '밀',
      '상추',
      '당근',
      '옥수수',
      '딸기',
      '포도',
      '가지',
      '토마토',
      '아보카도',
      '사과',
      '블루베리',
      '라즈베리',
      '오렌지',
      '파인애플',
      'apple',
      'blueberry',
      'raspberry',
      'orange',
      'pineapple',
      'avocado',
      'potato',
      'wheat',
      'lettuce',
      'carrot',
      'corn',
      'strawberry',
      'grape',
      'eggplant',
      'tomato',
    ];

    const mushroomKeywords = [
      '버섯',
      '트러플',
      '표고',
      '양송이',
      '느타리',
      '그물버섯',
      'mushroom',
      'truffle',
      'shiitake',
      'mousseron',
      'oyster',
      'porcini',
      'penny bun',
      'black truffle',
    ];

    const fishKeywords = [
      '생선',
      '물고기',
      'fish',
    ];

    const insectKeywords = [
      '곤충',
      '벌레',
      'insect',
      'bug',
    ];

    const storeKeywords = [
      '달걀',
      '우유',
      '치즈',
      '버터',
      '고기',
      '식용유',
      '커피',
      '커피 콩',
      '슈가파우더',
      '설탕',
      'egg',
      'milk',
      'cheese',
      'butter',
      'meat',
      'oil',
      'coffee',
      'sugar',
      'sugar powder',
    ];

    bool containsAny(List<String> keywords) {
      return keywords.any((k) => normalized.contains(k));
    }

    if (containsAny(mushroomKeywords)) {
      return CookingMaterialCategoryType.mushroom;
    }
    if (containsAny(fishKeywords)) {
      return CookingMaterialCategoryType.fish;
    }
    if (containsAny(insectKeywords)) {
      return CookingMaterialCategoryType.insect;
    }
    if (containsAny(storeKeywords)) {
      return CookingMaterialCategoryType.store;
    }
    if (containsAny(cropKeywords)) {
      return CookingMaterialCategoryType.crop;
    }

    return CookingMaterialCategoryType.etc;
  }

  static String _materialSubtitle(CookingMaterialCategoryType category) {
    switch (category) {
      case CookingMaterialCategoryType.crop:
        return '요리 · 재료 · 작물';
      case CookingMaterialCategoryType.store:
        return '요리 · 재료 · 상점구매';
      case CookingMaterialCategoryType.mushroom:
        return '요리 · 재료 · 버섯';
      case CookingMaterialCategoryType.fish:
        return '요리 · 재료 · 물고기';
      case CookingMaterialCategoryType.insect:
        return '요리 · 재료 · 곤충';
      case CookingMaterialCategoryType.etc:
        return '요리 · 재료 · 기타';
    }
  }

  static void _addIfNotExists(
      List<GlobalSearchItem> results,
      Set<String> addedIds,
      GlobalSearchItem item,
      ) {
    if (addedIds.contains(item.id)) return;
    addedIds.add(item.id);
    results.add(item);
  }

  static String _displayName(Map<String, dynamic> e) {
    return (e['nameKo'] ?? e['name_ko'] ?? e['name'] ?? '')
        .toString()
        .trim();
  }

  static String _keywordOf(Map<String, dynamic> e) {
    final ko = (e['nameKo'] ?? e['name_ko'] ?? '').toString();
    final en = (e['name'] ?? '').toString();
    return '$ko $en'.toLowerCase();
  }

  static String _assetPath(dynamic image) {
    final raw = (image ?? '').toString().trim();
    if (raw.isEmpty) return 'assets/images/default.png';

    String fullPath = raw.startsWith('assets/') ? raw : 'assets/$raw';

    final lower = fullPath.toLowerCase();
    if (!lower.endsWith('.png') &&
        !lower.endsWith('.jpg') &&
        !lower.endsWith('.jpeg') &&
        !lower.endsWith('.webp')) {
      fullPath = '$fullPath.webp';
    }

    return fullPath;
  }

  static String _recipeAssetPath(dynamic image) {
    final raw = (image ?? '').toString().trim();
    if (raw.isEmpty) return 'assets/images/default.png';

    return raw.startsWith('assets/') ? raw : 'assets/$raw';
  }
}

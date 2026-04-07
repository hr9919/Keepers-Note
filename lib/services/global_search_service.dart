import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/global_search_item.dart';

class GlobalSearchService {
  static const String _baseUrl = 'http://161.33.30.40:8080';

  static Future<List<GlobalSearchItem>> loadAllItems() async {
    final List<GlobalSearchItem> results = [];

    try {
      final fishRes = await http.get(Uri.parse('$_baseUrl/api/fish'));
      if (fishRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(fishRes.bodyBytes));
        results.addAll(
          data.map((e) => GlobalSearchItem(
            id: 'fish_${e['id']}',
            title: e['nameKo'] ?? e['name'] ?? '',
            subtitle: '채집 · 낚시',
            iconPath: _assetPath(e['image']),
            screen: SearchTargetScreen.gathering,
            gatheringTab: GatheringTabType.fish,
            keyword: '${e['nameKo'] ?? ''} ${e['name'] ?? ''}'.toLowerCase(),
          )),
        );
      }

      final insectRes = await http.get(Uri.parse('$_baseUrl/api/insects'));
      if (insectRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(insectRes.bodyBytes));
        results.addAll(
          data.map((e) => GlobalSearchItem(
            id: 'insect_${e['id']}',
            title: e['nameKo'] ?? e['name'] ?? '',
            subtitle: '채집 · 곤충 채집',
            iconPath: _assetPath(e['image']),
            screen: SearchTargetScreen.gathering,
            gatheringTab: GatheringTabType.insect,
            keyword: '${e['nameKo'] ?? ''} ${e['name'] ?? ''}'.toLowerCase(),
          )),
        );
      }

      final birdRes = await http.get(Uri.parse('$_baseUrl/api/birds'));
      if (birdRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(birdRes.bodyBytes));
        results.addAll(
          data.map((e) => GlobalSearchItem(
            id: 'bird_${e['id']}',
            title: e['nameKo'] ?? e['name'] ?? '',
            subtitle: '채집 · 새 관찰',
            iconPath: _assetPath(e['image']),
            screen: SearchTargetScreen.gathering,
            gatheringTab: GatheringTabType.bird,
            keyword: '${e['nameKo'] ?? ''} ${e['name'] ?? ''}'.toLowerCase(),
          )),
        );
      }

      final plantRes = await http.get(Uri.parse('$_baseUrl/api/gardening'));
      if (plantRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(plantRes.bodyBytes));
        results.addAll(
          data.map((e) => GlobalSearchItem(
            id: 'plant_${e['id']}',
            title: e['nameKo'] ?? e['name'] ?? '',
            subtitle: '채집 · 원예',
            iconPath: _assetPath(e['image']),
            screen: SearchTargetScreen.gathering,
            gatheringTab: GatheringTabType.plant,
            keyword: '${e['nameKo'] ?? ''} ${e['name'] ?? ''}'.toLowerCase(),
          )),
        );
      }

      // 요리 레시피만 추가
      final gourmetRes = await http.get(Uri.parse('$_baseUrl/api/gourmet'));
      if (gourmetRes.statusCode == 200) {
        final List<dynamic> data =
        jsonDecode(utf8.decode(gourmetRes.bodyBytes));

        results.addAll(
          data.map((e) {
            final rawName = (e['nameKo'] ?? e['name_ko'] ?? e['name'] ?? '')
                .toString()
                .trim();

            final displayName = rawName
                .replaceAll(' (이벤트)', '')
                .replaceAll('(이벤트)', '')
                .trim();

            final isEvent = rawName.contains('(이벤트)');

            return GlobalSearchItem(
              id: 'gourmet_${e['id']}',
              title: displayName,
              subtitle: isEvent ? '요리 · 레시피 · 이벤트' : '요리 · 레시피',
              iconPath: _recipeAssetPath(e['image']),
              screen: SearchTargetScreen.cooking,
              cookingTab: CookingTabType.recipe,
              keyword:
              '$displayName $rawName ${e['name'] ?? ''}'.toLowerCase(),
            );
          }),
        );
      }

      // crop api 만들어지면 여기다가 요리 재료 추가
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

  static String _assetPath(String? image) {
    if (image == null || image.isEmpty) return 'assets/images/default.png';

    String fullPath = image.startsWith('assets/') ? image : 'assets/$image';

    if (!fullPath.endsWith('.png') &&
        !fullPath.endsWith('.jpg') &&
        !fullPath.endsWith('.jpeg') &&
        !fullPath.endsWith('.webp')) {
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
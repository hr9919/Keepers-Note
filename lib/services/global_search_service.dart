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
            id: e['id'],
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
            id: e['id'],
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
            id: e['id'],
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
            id: e['id'],
            title: e['nameKo'] ?? e['name'] ?? '',
            subtitle: '채집 · 원예',
            iconPath: _assetPath(e['image']),
            screen: SearchTargetScreen.gathering,
            gatheringTab: GatheringTabType.plant,
            keyword: '${e['nameKo'] ?? ''} ${e['name'] ?? ''}'.toLowerCase(),
          )),
        );
      }

      // cooking / encyclopedia / pet 도 같은 방식으로 추가
    } catch (_) {}

    return results;
  }

  static List<GlobalSearchItem> filter(
      List<GlobalSearchItem> source,
      String query,
      ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final filtered = source.where((item) {
      return item.keyword.contains(q);
    }).toList();

    filtered.sort((a, b) {
      final aStarts = a.title.toLowerCase().startsWith(q);
      final bStarts = b.title.toLowerCase().startsWith(q);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.title.length.compareTo(b.title.length);
    });

    return filtered.take(8).toList();
  }

  static String _assetPath(String? image) {
    if (image == null || image.isEmpty) return 'assets/images/default.png';
    String fullPath = image.startsWith('assets/') ? image : 'assets/$image';
    if (!fullPath.endsWith('.png') &&
        !fullPath.endsWith('.jpg') &&
        !fullPath.endsWith('.webp')) {
      fullPath = '$fullPath.webp';
    }
    return fullPath;
  }
}
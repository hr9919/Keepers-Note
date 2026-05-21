import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CollectionProgressState {
  final String itemKey;
  final String itemType;
  final String itemId;
  final bool liked;
  final int achievedStar;
  final bool masteryDone;

  const CollectionProgressState({
    required this.itemKey,
    required this.itemType,
    required this.itemId,
    required this.liked,
    required this.achievedStar,
    required this.masteryDone,
  });

  factory CollectionProgressState.fromJson(Map<String, dynamic> json) {
    final itemType = (json['itemType'] ?? json['item_type'] ?? 'common').toString();
    final itemId = (json['itemId'] ?? json['item_id'] ?? '').toString();
    final itemKey = (json['itemKey'] ?? json['item_key'] ?? '').toString().trim();

    return CollectionProgressState(
      itemType: itemType,
      itemId: itemId,
      itemKey: itemKey.isNotEmpty
          ? itemKey
          : (itemType == 'common' ? itemId : '$itemType:$itemId'),
      liked: _parseBool(json['liked']),
      achievedStar: _parseInt(json['achievedStar'] ?? json['achieved_star']).clamp(0, 5),
      masteryDone: _parseBool(json['masteryDone'] ?? json['mastery_done']),
    );
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    if (value is String) {
      final text = value.trim().toLowerCase();
      return text == 'true' || text == '1' || text == 'y';
    }
    return false;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class CollectionProgressService {
  CollectionProgressService._();

  static const String baseUrl = 'https://api.keepers-note.o-r.kr';
  static const String _masteryPrefix = 'mastery_done:';

  static Future<String?> _userId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null || userId.trim().isEmpty) return null;
    return userId.trim();
  }

  static Future<Map<String, CollectionProgressState>> fetchAll() async {
    final userId = await _userId();
    if (userId == null) return {};

    final uri = Uri.parse('$baseUrl/api/user-collection-progress')
        .replace(queryParameters: {'userId': userId});

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return {};

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) return {};

      final result = <String, CollectionProgressState>{};
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final state = CollectionProgressState.fromJson(item);
          if (state.itemKey.isNotEmpty) {
            result[state.itemKey] = state;
          }
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<CollectionProgressState?> fetchOne(String itemKey) async {
    final userId = await _userId();
    if (userId == null || itemKey.trim().isEmpty) return null;

    final uri = Uri.parse('$baseUrl/api/user-collection-progress/item')
        .replace(queryParameters: {
      'userId': userId,
      'itemKey': itemKey.trim(),
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return CollectionProgressState.fromJson(decoded);
      }
    } catch (_) {}

    return null;
  }

  static Future<void> update({
    required String itemKey,
    bool? liked,
    int? achievedStar,
    bool? masteryDone,
  }) async {
    final userId = await _userId();
    if (userId == null || itemKey.trim().isEmpty) return;

    final body = <String, dynamic>{
      'userId': int.tryParse(userId) ?? userId,
      'itemKey': itemKey.trim(),
      if (liked != null) 'liked': liked,
      if (achievedStar != null) 'achievedStar': achievedStar.clamp(0, 5),
      if (masteryDone != null) 'masteryDone': masteryDone,
    };

    try {
      await http.put(
        Uri.parse('$baseUrl/api/user-collection-progress/item'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(body),
      );
    } catch (_) {
      // 오프라인이어도 앱 로컬 상태는 이미 저장되어 있으므로 조용히 넘깁니다.
    }
  }

  static Future<void> saveFavorite(String itemKey, bool liked) async {
    await update(itemKey: itemKey, liked: liked);
  }

  static Future<void> saveAchievementStar(String itemKey, int star) async {
    await update(itemKey: itemKey, achievedStar: star.clamp(0, 5));
  }

  static Future<void> saveMasteryDone(String itemKey, bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_masteryPrefix$itemKey', done);
    await update(itemKey: itemKey, masteryDone: done);
  }

  static Future<bool> loadMasteryDone(String itemKey) async {
    final prefs = await SharedPreferences.getInstance();
    final localValue = prefs.getBool('$_masteryPrefix$itemKey');
    if (localValue != null) return localValue;

    final remote = await fetchOne(itemKey);
    final value = remote?.masteryDone ?? false;
    await prefs.setBool('$_masteryPrefix$itemKey', value);
    return value;
  }

  static Future<int> loadAchievementStar(
    String itemKey, {
    required String localStorageKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(localStorageKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final star = int.tryParse(decoded[itemKey]?.toString() ?? '') ?? 0;
          if (star >= 1 && star <= 5) return star;
        }
      } catch (_) {}
    }

    final remote = await fetchOne(itemKey);
    final star = remote?.achievedStar ?? 0;
    if (star > 0) {
      await saveAchievementStarLocal(
        itemKey,
        star,
        localStorageKey: localStorageKey,
        syncRemote: false,
      );
    }
    return star;
  }

  static Future<void> saveAchievementStarLocal(
    String itemKey,
    int star, {
    required String localStorageKey,
    bool syncRemote = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(localStorageKey);

    final Map<String, dynamic> data = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            data[key.toString()] = value;
          });
        }
      } catch (_) {}
    }

    if (star <= 0) {
      data.remove(itemKey);
    } else {
      data[itemKey] = star.clamp(1, 5);
    }

    await prefs.setString(localStorageKey, jsonEncode(data));
    if (syncRemote) {
      await saveAchievementStar(itemKey, star);
    }
  }


  static Future<void> syncSnapshot({
    required Set<String> favorites,
    required Map<String, int> stars,
    required Map<String, bool> mastery,
  }) async {
    final userId = await _userId();
    if (userId == null) return;

    final keys = <String>{}
      ..addAll(favorites)
      ..addAll(stars.keys)
      ..addAll(mastery.keys);

    if (keys.isEmpty) return;

    final items = keys.map((key) {
      return <String, dynamic>{
        'itemKey': key,
        if (favorites.contains(key)) 'liked': true,
        if ((stars[key] ?? 0) > 0) 'achievedStar': stars[key]!.clamp(1, 5),
        if (mastery[key] == true) 'masteryDone': true,
      };
    }).toList();

    final body = {
      'userId': int.tryParse(userId) ?? userId,
      'items': items,
    };

    try {
      await http.post(
        Uri.parse('$baseUrl/api/user-collection-progress/sync'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(body),
      );
    } catch (_) {}
  }

  static Future<void> mergeRemoteIntoLocal({
    required String favoritesKey,
    required String achievementStarsKey,
    required void Function(Set<String> favorites, Map<String, int> stars, Map<String, bool> mastery) onLoaded,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final localFavorites = (prefs.getStringList(favoritesKey) ?? []).toSet();

    final localStars = <String, int>{};
    final rawStars = prefs.getString(achievementStarsKey);
    if (rawStars != null && rawStars.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawStars);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final star = int.tryParse(value?.toString() ?? '') ?? 0;
            if (star >= 1 && star <= 5) {
              localStars[key.toString()] = star;
            }
          });
        }
      } catch (_) {}
    }

    final localMastery = <String, bool>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_masteryPrefix)) {
        localMastery[key.substring(_masteryPrefix.length)] = prefs.getBool(key) ?? false;
      }
    }

    final remote = await fetchAll();

    // 첫 계정 연동 시 기존 로컬 체크값을 서버로 1회 올립니다.
    if (remote.isEmpty && (localFavorites.isNotEmpty || localStars.isNotEmpty || localMastery.isNotEmpty)) {
      await syncSnapshot(
        favorites: localFavorites,
        stars: localStars,
        mastery: localMastery,
      );
    }

    for (final entry in remote.entries) {
      final key = entry.key;
      final state = entry.value;

      if (state.liked) {
        localFavorites.add(key);
      }
      if (state.achievedStar >= 1 && state.achievedStar <= 5) {
        localStars[key] = state.achievedStar;
      }
      if (state.masteryDone) {
        localMastery[key] = true;
      }
    }

    await prefs.setStringList(favoritesKey, localFavorites.toList());
    await prefs.setString(achievementStarsKey, jsonEncode(localStars));
    for (final entry in localMastery.entries) {
      await prefs.setBool('$_masteryPrefix${entry.key}', entry.value);
    }

    onLoaded(localFavorites, localStars, localMastery);
  }
}

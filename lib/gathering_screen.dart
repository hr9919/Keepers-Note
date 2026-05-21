import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'setting_screen.dart';
import 'services/collection_progress_service.dart';

import 'models/global_search_item.dart';

PreferredSizeWidget _keepersDetailGlassAppBar(
    BuildContext context, {
      required String title,
      String subtitle = '',
    }) {
  final topPadding = MediaQuery.of(context).padding.top;

  return PreferredSize(
    preferredSize: Size.fromHeight(topPadding + 66),
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(26),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(14, topPadding + 8, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(26),
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.76),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _keepersDetailRoundButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2D3436),
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9AA4B2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(width: 42, height: 42),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _keepersDetailRoundButton({
  required IconData icon,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.white.withOpacity(0.92),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFFE2DA),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 19,
          color: const Color(0xFF2D3436),
        ),
      ),
    ),
  );
}


int _parseIntFlexible(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = value.toString().replaceAll(RegExp(r'[^0-9-]'), '').trim();
  if (text.isEmpty) return fallback;
  return int.tryParse(text) ?? fallback;
}

String _parseTextFlexible(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _normalizeSeasonLabel(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == '-' || value.toLowerCase() == 'null') return '';

  final compact = value.replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '').toLowerCase();

  if (compact.contains('빙설') || compact.contains('snow') || compact.contains('ice')) {
    return '빙설 시즌';
  }
  if (compact.contains('꿈의명암') || compact.contains('명암') || compact.contains('dream')) {
    return '꿈의 명암';
  }

  return value;
}

String _parseSeasonTag(Map<String, dynamic> json) {
  return _normalizeSeasonLabel(
    _parseTextFlexible(json, const [
      'seasonTag',
      'season_tag',
      'pastSeason',
      'past_season',
      'seasonName',
      'season_name',
      'eventSeason',
      'event_season',
      'season',
    ]),
  );
}

String _compactSeasonSourceText(Iterable<String?> values) {
  return values
      .where((value) => value != null)
      .map((value) => value!.trim())
      .where((value) => value.isNotEmpty)
      .join(' ')
      .replaceAll(' ', '')
      .replaceAll('_', '')
      .replaceAll('-', '')
      .replaceAll('/', '')
      .toLowerCase();
}

String _inferPastSeasonLabelFromText(Iterable<String?> values) {
  final compact = _compactSeasonSourceText(values);
  if (compact.isEmpty) return '';

  // 빙설 시즌: 얼음 결정/겨울/슈가파우더/무/얼음컵 계열
  if (compact.contains('빙설') ||
      compact.contains('winter') ||
      compact.contains('frost') ||
      compact.contains('frostspore') ||
      compact.contains('whiteradish') ||
      compact.contains('icedcup') ||
      compact.contains('aurora') ||
      compact.contains('얼음결정') ||
      compact.contains('얼음컵') ||
      compact.contains('슈가파우더') ||
      compact.contains('살균달걀') ||
      compact.contains('오로라') ||
      compact.contains('무크림') ||
      compact.contains('갈은무') ||
      compact.contains('하얀무')) {
    return '빙설 시즌';
  }

  // 꿈의 명암: 감독/스크립터/정장 비둘기/봄날/로메인/관람/팝콘 계열
  if (compact.contains('꿈의명암') ||
      compact.contains('dream') ||
      compact.contains('director') ||
      compact.contains('script') ||
      compact.contains('suitdove') ||
      compact.contains('springday') ||
      compact.contains('springdag') ||
      compact.contains('romaine') ||
      compact.contains('celtuce') ||
      compact.contains('salsa') ||
      compact.contains('popcorn') ||
      compact.contains('movie') ||
      compact.contains('bucket') ||
      compact.contains('명암') ||
      compact.contains('감독') ||
      compact.contains('스크립터') ||
      compact.contains('봄날') ||
      compact.contains('카라멜슈가') ||
      compact.contains('로메인') ||
      compact.contains('살사') ||
      compact.contains('팝콘') ||
      compact.contains('관람') ||
      compact.contains('산우엉') ||
      compact.contains('산겨자') ||
      compact.contains('산마늘') ||
      compact.contains('고사리')) {
    return '꿈의 명암';
  }

  return '';
}

bool _hasEventTokenPrice(List<int> prices) {
  return prices.any((price) => price > 0);
}

bool _looksLikeEventOrPastSeasonText(Iterable<String?> values) {
  final compact = values
      .where((value) => value != null)
      .map((value) => value!.trim())
      .where((value) => value.isNotEmpty)
      .join(' ')
      .replaceAll(' ', '')
      .replaceAll('_', '')
      .replaceAll('-', '')
      .toLowerCase();

  if (compact.isEmpty) return false;

  return compact.contains('이벤트') ||
      compact.contains('사건') ||
      compact.contains('brick') ||
      compact.contains('브릭') ||
      compact.contains('빙설') ||
      compact.contains('snow') ||
      compact.contains('ice') ||
      compact.contains('꿈의명암') ||
      compact.contains('명암') ||
      compact.contains('dream') ||
      compact.contains('부활절') ||
      compact.contains('이스터');
}

bool _isEventOrPastSeasonItem({
  required List<int> eventTokenPrices,
  String seasonTag = '',
  Iterable<String?> textValues = const [],
}) {
  return _hasEventTokenPrice(eventTokenPrices) ||
      _normalizeSeasonLabel(seasonTag).isNotEmpty ||
      _inferPastSeasonLabelFromText(textValues).isNotEmpty ||
      _looksLikeEventOrPastSeasonText(textValues);
}

List<int> _parseEventTokenPrices(Map<String, dynamic> json) {
  return [
    _parseIntFlexible(json['eventTokenPrice1'] ?? json['event_token_price_1']),
    _parseIntFlexible(json['eventTokenPrice2'] ?? json['event_token_price_2']),
    _parseIntFlexible(json['eventTokenPrice3'] ?? json['event_token_price_3']),
    _parseIntFlexible(json['eventTokenPrice4'] ?? json['event_token_price_4']),
    _parseIntFlexible(json['eventTokenPrice5'] ?? json['event_token_price_5']),
  ];
}


String _formatOccurrenceSubInfo(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == '-') return '-';

  final weatherPatterns = <String>[
    '맑음/무지개',
    '해/무지개',
    '비/무지개',
    '눈/무지개',
    '흐림/무지개',
    '무지개',
    '맑음',
    '해',
    '비',
    '눈',
    '흐림',
    'rainy_rainbow',
    'sunny_rainbow',
    'rainbow',
    'rainy',
    'sunny',
  ];

  String weatherText = '';
  String timeText = value;

  for (final pattern in weatherPatterns) {
    if (timeText.toLowerCase().contains(pattern.toLowerCase())) {
      weatherText = _normalizeOccurrenceWeather(pattern);
      timeText = timeText.replaceAll(RegExp(RegExp.escape(pattern), caseSensitive: false), '').trim();
      break;
    }
  }

  timeText = timeText
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[·,/\-\s]+'), '')
      .replaceAll(RegExp(r'[·,/\-\s]+$'), '')
      .trim();

  final lines = <String>[];
  if (timeText.isNotEmpty) {
    lines.add('시간 : ${_formatOccurrenceTimeText(timeText)}');
  }
  if (weatherText.isNotEmpty) {
    lines.add('날씨 : $weatherText');
  }

  if (lines.isEmpty) return value;
  return lines.join('\n');
}

String _normalizeOccurrenceWeather(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.contains('rainy_rainbow') || value.contains('비/무지개')) return '비/무지개';
  if (value.contains('sunny_rainbow') || value.contains('해/무지개') || value.contains('맑음/무지개')) return '맑음/무지개';
  if (value.contains('rainbow') || value.contains('무지개')) return '무지개';
  if (value.contains('rainy') || value == '비') return '비';
  if (value.contains('sunny') || value == '해' || value == '맑음') return '맑음';
  if (value == '눈') return '눈';
  if (value == '흐림') return '흐림';
  return raw.trim();
}

String _formatOccurrenceTimeText(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final compact = value.replaceAll(' ', '').toLowerCase();

  if (compact == 'all' || compact == 'any' || compact == 'allday' || compact == '0~24' || compact == '0-24' || compact == '상시') {
    return '상시';
  }

  final replaced = value
      .replaceAll('／', '/')
      .replaceAll('，', ',')
      .replaceAll(RegExp(r'\s*/\s*'), ' / ')
      .replaceAll(RegExp(r'\s*,\s*'), ', ');

  return replaced.replaceAllMapped(
    RegExp(r'(\d{1,2})\s*[~-]\s*(\d{1,2})(?!\s*시)'),
        (m) => '${m.group(1)}~${m.group(2)}시',
  );
}

String _normalizeShadowSizeLabel(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == '-') return '';
  final compact = value.toLowerCase().replaceAll(' ', '').replaceAll('_', '-');

  if (compact == 'xs' || compact == 'tiny' || compact == 'very-small' || compact == 'verysmall' || compact == 'blue' || value.contains('매우작') || value.contains('매우 작')) {
    return '매우 작음';
  }
  if (compact == 's' || compact == 'small' || value == '작음' || value == '작다') {
    return '작음';
  }
  if (compact == 'm' || compact == 'medium' || value == '중간') {
    return '중간';
  }
  if (compact == 'l' || compact == 'big' || compact == 'large' || value == '큼' || value == '크다') {
    return '큼';
  }
  if (compact == 'xl' || compact == 'xxl' || compact == 'gold' || compact == 'huge' || compact == 'giant' || value.contains('매우큼') || value.contains('매우 큼')) {
    return '매우 큼';
  }

  return value;
}


List<Map<String, String>> _buildMasteryStageExtraInfo(
    String actionLabel,
    int masterCount, {
      int entryCount = 0,
      int skilledCount = 0,
      int exactMasterCount = 0,
      String unit = '회',
    }) {
  final int master = exactMasterCount > 0 ? exactMasterCount : masterCount;
  if (master <= 0 && entryCount <= 0 && skilledCount <= 0) return const [];

  final int entry = entryCount > 0 ? entryCount : (master > 0 ? (master * 0.333).ceil() : 0);
  final int skilled = skilledCount > 0 ? skilledCount : (master > 0 ? (master * 0.666).ceil() : 0);

  final stages = <Map<String, String>>[
    if (entry > 0)
      {'label': '$actionLabel 초보자', 'value': '${entry}$unit 미만'},
    if (entry > 0)
      {'label': '$actionLabel 입문자', 'value': '${entry}$unit'},
    if (skilled > 0)
      {'label': '$actionLabel 숙련자', 'value': '${skilled}$unit'},
    if (master > 0)
      {'label': '$actionLabel 명인', 'value': '${master}$unit'},
  ];

  return stages;
}

String _masteryDoneStorageKey(String itemKey) => 'mastery_done:$itemKey';

Future<bool> _loadMasteryDoneValue(String itemKey) async {
  return CollectionProgressService.loadMasteryDone(itemKey);
}

Future<void> _saveMasteryDoneValue(String itemKey, bool value) async {
  await CollectionProgressService.saveMasteryDone(itemKey, value);
}


Future<int> _loadDetailAchievementStarValue(String itemKey) async {
  return CollectionProgressService.loadAchievementStar(
    itemKey,
    localStorageKey: 'gathering_achievement_stars',
  );
}

Future<void> _saveDetailAchievementStarValue(String itemKey, int star) async {
  await CollectionProgressService.saveAchievementStarLocal(
    itemKey,
    star,
    localStorageKey: 'gathering_achievement_stars',
  );
}

Widget _buildDetailAchievementStars({
  required String itemKey,
}) {
  return FutureBuilder<int>(
    future: _loadDetailAchievementStarValue(itemKey),
    builder: (context, snapshot) {
      int selected = snapshot.data ?? 0;

      return StatefulBuilder(
        builder: (context, setInnerState) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final star = index + 1;
              final active = selected >= star;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final next = selected == star ? 0 : star;
                  setInnerState(() => selected = next);
                  await _saveDetailAchievementStarValue(itemKey, next);
                },
                child: SizedBox(
                  width: 28,
                  height: 34,
                  child: Center(
                    child: Icon(
                      active ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 29,
                      color: active
                          ? const Color(0xFFFFB84D)
                          : const Color(0xFFD6DEE8),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      );
    },
  );
}

Widget _buildDetailMasteryDoneButton({
  required String itemKey,
}) {
  return FutureBuilder<bool>(
    future: _loadMasteryDoneValue(itemKey),
    builder: (context, snapshot) {
      bool checked = snapshot.data ?? false;

      return StatefulBuilder(
        builder: (context, setInnerState) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final next = !checked;
              setInnerState(() => checked = next);
              await _saveMasteryDoneValue(itemKey, next);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked
                    ? const Color(0xFFFFF4CF)
                    : const Color(0xFFFCF9FF),
                border: Border.all(
                  color: checked
                      ? const Color(0xFFD8B4FE)
                      : const Color(0xFFF0E4FF),
                  width: 1.15,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (checked ? const Color(0xFFFBBF24) : const Color(0xFFD8B4FE))
                        .withOpacity(checked ? 0.16 : 0.05),
                    blurRadius: checked ? 8 : 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                checked
                    ? Icons.workspace_premium_rounded
                    : Icons.workspace_premium_outlined,
                size: 19,
                color: checked
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFD8B4FE),
              ),
            ),
          );
        },
      );
    },
  );
}

class GatheringSearchController extends ChangeNotifier {
  GlobalSearchItem? _pendingItem;

  GlobalSearchItem? consume() {
    final item = _pendingItem;
    _pendingItem = null;
    return item;
  }

  void open(GlobalSearchItem item) {
    _pendingItem = item;
    notifyListeners();
  }
}

class FlowerColorDetail {
  final String colorNameKo;
  final String image;
  final bool isBaseColor;
  final bool isFinalColor;

  FlowerColorDetail({
    required this.colorNameKo,
    required this.image,
    required this.isBaseColor,
    required this.isFinalColor,
  });

  factory FlowerColorDetail.fromJson(Map<String, dynamic> json) {
    return FlowerColorDetail(
      colorNameKo: (json['colorNameKo'] ?? json['color_name_ko'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      isBaseColor: (json['isBaseColor'] ?? json['is_base_color'] ?? false) == true,
      isFinalColor: (json['isFinalColor'] ?? json['is_final_color'] ?? false) == true,
    );
  }
}

class FlowerBreedingRule {
  final String resultColorKo;
  final String parentColorAKo;
  final String parentColorBKo;
  final String? note;
  final bool isCatalogOnly;
  final bool isFinalStep;

  FlowerBreedingRule({
    required this.resultColorKo,
    required this.parentColorAKo,
    required this.parentColorBKo,
    this.note,
    required this.isCatalogOnly,
    required this.isFinalStep,
  });

  factory FlowerBreedingRule.fromJson(Map<String, dynamic> json) {
    return FlowerBreedingRule(
      resultColorKo: (json['resultColorKo'] ?? json['result_color_ko'] ?? '').toString(),
      parentColorAKo: (json['parentColorAKo'] ?? json['parent_color_a_ko'] ?? '').toString(),
      parentColorBKo: (json['parentColorBKo'] ?? json['parent_color_b_ko'] ?? '').toString(),
      note: json['note']?.toString(),
      isCatalogOnly: (json['isCatalogOnly'] ?? json['is_catalog_only'] ?? false) == true,
      isFinalStep: (json['isFinalStep'] ?? json['is_final_step'] ?? false) == true,
    );
  }
}

class FlowerDetail {
  final String id;
  final String nameKo;
  final String image;
  final String growthTime;
  final int level;
  final int seedCost;
  final int seedSell;
  final List<int> prices;
  final int masteryCount;
  final int masteryEntryCount;
  final int masterySkilledCount;
  final int masteryMasterCount;
  final List<int> eventTokenPrices;
  final String seasonTag;
  final List<FlowerColorDetail> flowerColors;
  final List<FlowerBreedingRule> breedingRules;

  FlowerDetail({
    required this.id,
    required this.nameKo,
    required this.image,
    required this.growthTime,
    required this.level,
    required this.seedCost,
    required this.seedSell,
    required this.prices,
    required this.masteryCount,
    required this.masteryEntryCount,
    required this.masterySkilledCount,
    required this.masteryMasterCount,
    required this.eventTokenPrices,
    required this.seasonTag,
    required this.flowerColors,
    required this.breedingRules,
  });

  factory FlowerDetail.fromJson(Map<String, dynamic> json) {
    final colorsJson = (json['flowerColors'] as List<dynamic>?) ?? const [];
    final rulesJson = (json['breedingRules'] as List<dynamic>?) ?? const [];

    return FlowerDetail(
      id: json['id'].toString(),
      nameKo: (json['nameKo'] ?? json['name_ko'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      growthTime: (json['growthTime'] ??
          json['growth_time'] ??
          '').toString(),
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      seedCost: int.tryParse(json['seedCost']?.toString() ?? json['seed_cost']?.toString() ?? '0') ?? 0,
      seedSell: int.tryParse(json['seedSell']?.toString() ?? json['seed_sell']?.toString() ?? '0') ?? 0,
      prices: [
        int.tryParse((json['price1'] ?? json['price_1'] ?? 0).toString()) ?? 0,
        int.tryParse((json['price2'] ?? json['price_2'] ?? 0).toString()) ?? 0,
        int.tryParse((json['price3'] ?? json['price_3'] ?? 0).toString()) ?? 0,
        int.tryParse((json['price4'] ?? json['price_4'] ?? 0).toString()) ?? 0,
        int.tryParse((json['price5'] ?? json['price_5'] ?? 0).toString()) ?? 0,
      ],
      masteryCount: _parseIntFlexible(json['masteryCount'] ?? json['mastery_count'] ?? json['masteryMasterCount'] ?? json['mastery_master_count']),
      masteryEntryCount: _parseIntFlexible(json['masteryEntryCount'] ?? json['mastery_entry_count']),
      masterySkilledCount: _parseIntFlexible(json['masterySkilledCount'] ?? json['mastery_skilled_count']),
      masteryMasterCount: _parseIntFlexible(json['masteryMasterCount'] ?? json['mastery_master_count'] ?? json['masteryCount'] ?? json['mastery_count']),
      eventTokenPrices: _parseEventTokenPrices(json),
      seasonTag: _parseSeasonTag(json),
      flowerColors: colorsJson
          .map((e) => FlowerColorDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
      breedingRules: rulesJson
          .map((e) => FlowerBreedingRule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BirdItem {
  final String id;
  final String name;
  final String nameKo;
  final String image;
  final String location;
  final String availableTime;
  final String timeKey;
  final String weather;
  final int level;
  final int masteryCount;
  final int masteryEntryCount;
  final int masterySkilledCount;
  final int masteryMasterCount;
  final String captureDistance;
  final String wingSpread;
  final String whistle;
  final List<int> prices;
  final List<int> eventTokenPrices;
  final String seasonTag;

  BirdItem({
    required this.id,
    required this.name,
    required this.nameKo,
    required this.image,
    required this.location,
    required this.availableTime,
    required this.timeKey,
    required this.weather,
    required this.level,
    required this.masteryCount,
    required this.masteryEntryCount,
    required this.masterySkilledCount,
    required this.masteryMasterCount,
    required this.captureDistance,
    required this.wingSpread,
    required this.whistle,
    required this.prices,
    required this.eventTokenPrices,
    required this.seasonTag,
  });

  factory BirdItem.fromJson(Map<String, dynamic> json) {
    int parsePrice(dynamic p1, dynamic p2) {
      return int.tryParse((p1 ?? p2 ?? 0).toString()) ?? 0;
    }

    final availableTime =
    (json['availableTime'] ?? json['available_time'] ?? '').toString();

    final timeKey =
    (json['timeKey'] ?? json['time_key'] ?? '').toString();

    return BirdItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameKo: (json['nameKo'] ?? json['name_ko'] ?? json['name'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      availableTime: availableTime,
      timeKey: timeKey,
      weather: (json['weather'] ?? '').toString(),
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      masteryCount: _parseIntFlexible(json['masteryCount'] ?? json['mastery_count'] ?? json['masteryMasterCount'] ?? json['mastery_master_count']),
      masteryEntryCount: _parseIntFlexible(json['masteryEntryCount'] ?? json['mastery_entry_count']),
      masterySkilledCount: _parseIntFlexible(json['masterySkilledCount'] ?? json['mastery_skilled_count']),
      masteryMasterCount: _parseIntFlexible(json['masteryMasterCount'] ?? json['mastery_master_count'] ?? json['masteryCount'] ?? json['mastery_count']),
      captureDistance: _parseTextFlexible(json, ['captureDistance', 'capture_distance', 'catchDistance', 'catch_distance', 'photoDistance', 'photo_distance']),
      wingSpread: _parseTextFlexible(json, ['wingSpread', 'wing_spread', 'wingSpreadTime', 'wing_spread_time', 'wingOpenTime', 'wing_open_time', 'wingOpeningTime', 'wing_opening_time']),
      whistle: _parseTextFlexible(json, ['whistle', 'whistleTime', 'whistle_time', 'whistleRequired', 'whistle_required', 'callTime', 'call_time']),
      prices: [
        parsePrice(json['price1'], json['price_1']),
        parsePrice(json['price2'], json['price_2']),
        parsePrice(json['price3'], json['price_3']),
        parsePrice(json['price4'], json['price_4']),
        parsePrice(json['price5'], json['price_5']),
      ],
      eventTokenPrices: _parseEventTokenPrices(json),
      seasonTag: _parseSeasonTag(json),
    );
  }
}

class FlowerColorSummary {
  final String colorNameKo;
  final String image;

  FlowerColorSummary({
    required this.colorNameKo,
    required this.image,
  });

  factory FlowerColorSummary.fromJson(Map<String, dynamic> json) {
    return FlowerColorSummary(
      colorNameKo: (json['colorNameKo'] ?? json['color_name_ko'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
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
  final String growthTime;
  final String weather;
  final int level;
  final int masteryCount;
  final int masteryEntryCount;
  final int masterySkilledCount;
  final int masteryMasterCount;
  final List<int> prices;
  final List<int> eventTokenPrices;
  final String seasonTag;
  final List<FlowerColorSummary> flowerColorSummaries;

  PlantItem({
    required this.id,
    required this.name,
    required this.nameKo,
    required this.image,
    required this.location,
    required this.availableTime,
    required this.growthTime,
    required this.weather,
    required this.level,
    required this.masteryCount,
    required this.masteryEntryCount,
    required this.masterySkilledCount,
    required this.masteryMasterCount,
    required this.prices,
    required this.eventTokenPrices,
    required this.seasonTag,
    required this.flowerColorSummaries,
  });

  factory PlantItem.fromJson(Map<String, dynamic> json) {
    int parsePrice(dynamic p1, dynamic p2) {
      return int.tryParse((p1 ?? p2 ?? 0).toString()) ?? 0;
    }

    final rawSummaries = json['flowerColorSummaries'];
    final List<dynamic> summariesJson =
    rawSummaries is List ? rawSummaries : const [];

    return PlantItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameKo: (json['nameKo'] ?? json['name_ko'] ?? json['name'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      availableTime: (json['availableTime'] ?? json['available_time'] ?? '').toString(),
      growthTime: (json['growthTime'] ?? json['growth_time'] ?? '-').toString(),
      weather: (json['weather'] ?? '').toString(),
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      masteryCount: _parseIntFlexible(json['masteryCount'] ?? json['mastery_count'] ?? json['masteryMasterCount'] ?? json['mastery_master_count']),
      masteryEntryCount: _parseIntFlexible(json['masteryEntryCount'] ?? json['mastery_entry_count']),
      masterySkilledCount: _parseIntFlexible(json['masterySkilledCount'] ?? json['mastery_skilled_count']),
      masteryMasterCount: _parseIntFlexible(json['masteryMasterCount'] ?? json['mastery_master_count'] ?? json['masteryCount'] ?? json['mastery_count']),
      prices: [
        parsePrice(json['price1'], json['price_1']),
        parsePrice(json['price2'], json['price_2']),
        parsePrice(json['price3'], json['price_3']),
        parsePrice(json['price4'], json['price_4']),
        parsePrice(json['price5'], json['price_5']),
      ],
      eventTokenPrices: _parseEventTokenPrices(json),
      seasonTag: _parseSeasonTag(json),
      flowerColorSummaries: summariesJson
          .whereType<Map<String, dynamic>>()
          .map((e) => FlowerColorSummary.fromJson(e))
          .toList(),
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
  final String weather;
  final int level;
  final int masteryCount;
  final int masteryEntryCount;
  final int masterySkilledCount;
  final int masteryMasterCount;
  final List<int> prices;
  final List<int> eventTokenPrices;
  final String seasonTag;

  InsectItem({
    required this.id,
    required this.name,
    required this.nameKo,
    required this.image,
    required this.location,
    required this.availableTime,
    required this.weather,
    required this.level,
    required this.masteryCount,
    required this.masteryEntryCount,
    required this.masterySkilledCount,
    required this.masteryMasterCount,
    required this.prices,
    required this.eventTokenPrices,
    required this.seasonTag,
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
      weather: (json['weather'] ?? '').toString(),
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      masteryCount: _parseIntFlexible(json['masteryCount'] ?? json['mastery_count'] ?? json['masteryMasterCount'] ?? json['mastery_master_count']),
      masteryEntryCount: _parseIntFlexible(json['masteryEntryCount'] ?? json['mastery_entry_count']),
      masterySkilledCount: _parseIntFlexible(json['masterySkilledCount'] ?? json['mastery_skilled_count']),
      masteryMasterCount: _parseIntFlexible(json['masteryMasterCount'] ?? json['mastery_master_count'] ?? json['masteryCount'] ?? json['mastery_count']),
      prices: [
        parsePrice(json['price1'], json['price_1']),
        parsePrice(json['price2'], json['price_2']),
        parsePrice(json['price3'], json['price_3']),
        parsePrice(json['price4'], json['price_4']),
        parsePrice(json['price5'], json['price_5']),
      ],
      eventTokenPrices: _parseEventTokenPrices(json),
      seasonTag: _parseSeasonTag(json),
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
  final int masteryCount;
  final int masteryEntryCount;
  final int masterySkilledCount;
  final int masteryMasterCount;
  final String shadowSize;
  final List<int> eventTokenPrices;
  final String seasonTag;

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
    required this.masteryCount,
    required this.masteryEntryCount,
    required this.masterySkilledCount,
    required this.masteryMasterCount,
    required this.shadowSize,
    required this.eventTokenPrices,
    required this.seasonTag,
  });

  factory FishItem.fromJson(Map<String, dynamic> json) {
    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      return int.tryParse(value.toString());
    }

    final nameKo = (json['name_ko'] ?? json['nameKo'] ?? '').toString();

    return FishItem(
      id: (json['id'] ?? '').toString(),
      name: nameKo, // 🔥 핵심: name = nameKo로 통일
      nameKo: nameKo,
      image: (json['image'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      availableTime: (
          json['available_time'] ??
              json['availableTime'] ??
              ''
      ).toString(),
      level: parseNullableInt(json['level']),
      price: parseNullableInt(json['price']),
      price1: parseNullableInt(json['price_1'] ?? json['price1']),
      price2: parseNullableInt(json['price_2'] ?? json['price2']),
      price3: parseNullableInt(json['price_3'] ?? json['price3']),
      price4: parseNullableInt(json['price_4'] ?? json['price4']),
      price5: parseNullableInt(json['price_5'] ?? json['price5']),
      weather: (json['weather'] ?? '').toString(),
      masteryCount: _parseIntFlexible(json['masteryCount'] ?? json['mastery_count'] ?? json['masteryMasterCount'] ?? json['mastery_master_count']),
      masteryEntryCount: _parseIntFlexible(json['masteryEntryCount'] ?? json['mastery_entry_count']),
      masterySkilledCount: _parseIntFlexible(json['masterySkilledCount'] ?? json['mastery_skilled_count']),
      masteryMasterCount: _parseIntFlexible(json['masteryMasterCount'] ?? json['mastery_master_count'] ?? json['masteryCount'] ?? json['mastery_count']),
      shadowSize: _parseTextFlexible(json, ['shadowSize', 'shadow_size', 'shadow', 'fishShadow', 'fish_shadow', 'shadowSizeLabel', 'shadow_size_label']),
      eventTokenPrices: _parseEventTokenPrices(json),
      seasonTag: _parseSeasonTag(json),
    );
  }
}

class GatheringScreen extends StatefulWidget {
  final VoidCallback? openDrawer;
  final GatheringSearchController? searchController;
  final int resetSearchSignal;

  const GatheringScreen({
    super.key,
    this.openDrawer,
    this.searchController,
    this.resetSearchSignal = 0,
  });

  @override
  State<GatheringScreen> createState() => _GatheringScreenState();
}

class _GatheringScreenState extends State<GatheringScreen>
    with SingleTickerProviderStateMixin {
  static const String _favoritesKey = 'favorite_gathering_ids';
  static const String _achievementStarsKey = 'gathering_achievement_stars';

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _selectedFilter = '전체';
  String _searchQuery = '';
  String _selectedSort = '레벨순';
  final Set<int> _selectedLevelFilters = {};
  final Set<int> _selectedAchievementStarFilters = {};
  final Set<String> _selectedWeatherFilters = {};
  final Set<String> _selectedFishShadowFilters = {};
  final Set<String> _selectedMasteryCompletionFilters = {};
  final Set<String> _selectedPastSeasonFilters = <String>{'제외'};
  int _lastTabIndex = 0;

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
  Map<String, int> _achievementStars = {};
  Map<String, bool> _masteryDoneMap = {};

  final String _fishApiUrl = 'https://api.keepers-note.o-r.kr/api/fish';
  final String _insectApiUrl = 'https://api.keepers-note.o-r.kr/api/insects';
  final String _birdApiUrl = 'https://api.keepers-note.o-r.kr/api/birds';
  final String _plantApiUrl = 'https://api.keepers-note.o-r.kr/api/gardening';

  ScrollController _getCurrentController() {
    final index = _tabController.index.clamp(0, 3);
    if (index == 0) return _fishScrollController;
    if (index == 1) return _birdScrollController;
    if (index == 2) return _insectScrollController;
    return _plantScrollController;
  }

  List<String> _getCurrentFilterList() {
    final index = _tabController.index;

    if (index == 0) {
      return ['전체', '이벤트', '강 물고기', '호수 물고기', '바다 물고기'];
    }

    if (index == 1) {
      return ['전체', '이벤트', '숲', '호수', '강', '바다/해변', '어촌', '도시', '꽃밭', '주거지', '온천산', '특수'];
    }

    if (index == 2) {
      return ['전체', '이벤트', '숲', '집 앞', '호수', '도시', '어촌'];
    }

    return ['전체', '이벤트'];
  }

  void _dismissKeyboard() {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _attachScrollListener(ScrollController controller) {
    double lastOffset = 0;

    controller.addListener(() {
      if (!mounted || !controller.hasClients) return;

      final double offset = controller.offset;
      final bool showBtn = offset > 100;

      if (showBtn != _showTopBtn) {
        setState(() => _showTopBtn = showBtn);
      }

      if (offset <= 8) {
        if (!_isFilterVisible) {
          setState(() => _isFilterVisible = true);
        }
        lastOffset = offset;
        return;
      }

      final double delta = offset - lastOffset;

      if (delta > 4 && _isFilterVisible) {
        setState(() => _isFilterVisible = false);
      } else if (delta < -4 && !_isFilterVisible) {
        setState(() => _isFilterVisible = true);
      }

      lastOffset = offset;
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

  List<String> _normalizeWeatherLabel(String raw) {
    final value = raw.trim().replaceAll(' ', '').toLowerCase();

    if (value.isEmpty) return [];
    if (value == 'any' || value == 'all' || value == 'unknown') return [];
    if (value == '전체' || value == '모든날씨') return [];

    final List<String> result = [];

    if (value.contains('sunny') || value.contains('맑')) {
      result.add('맑음');
    }
    if (value.contains('rainy') || value.contains('비')) {
      result.add('비');
    }
    if (value.contains('snowy') || value.contains('눈')) {
      result.add('눈');
    }
    if (value.contains('rainbow') || value.contains('무지개')) {
      result.add('무지개');
    }
    if (value.contains('cloud') || value.contains('흐')) {
      result.add('흐림');
    }

    return result.toSet().toList();
  }

  String _normalizeInsectTimeLabel(String raw) {
    return _formatTimeRangeLabel(raw, allDayLabel: '');
  }

  String _formatTimeRangeLabel(String? raw, {required String allDayLabel}) {
    if (raw == null || raw.trim().isEmpty) return allDayLabel;

    final original = raw.trim();
    final compact = original.replaceAll(' ', '').toLowerCase();

    if (compact == 'allday' ||
        compact == 'all' ||
        compact == 'any' ||
        compact == '0~24' ||
        compact == '0-24' ||
        compact == '상시' ||
        compact == '하루종일') {
      return allDayLabel;
    }

    final Map<String, List<int>> timeKeyRanges = {
      'dawn': [0, 6],
      'day': [6, 12],
      'dusk': [12, 18],
      'night': [18, 24],
    };

    final keyParts = compact.split('_').where((part) => part.isNotEmpty).toList();
    if (keyParts.isNotEmpty && keyParts.every(timeKeyRanges.containsKey)) {
      final ranges = keyParts.map((part) => timeKeyRanges[part]!).toList();
      return _joinTimeRanges(ranges, allDayLabel: allDayLabel);
    }

    final normalized = compact
        .replaceAll('／', '/')
        .replaceAll('/', ',')
        .replaceAll('，', ',');

    final matches = RegExp(r'(\d{1,2})[~-](\d{1,2})').allMatches(normalized).toList();
    if (matches.isNotEmpty) {
      final ranges = matches.map((m) {
        final start = int.tryParse(m.group(1) ?? '') ?? 0;
        final end = int.tryParse(m.group(2) ?? '') ?? 0;
        return [start, end];
      }).where((range) {
        return range[0] >= 0 && range[1] <= 24 && range[0] < range[1];
      }).toList();

      if (ranges.isNotEmpty) {
        return _joinTimeRanges(ranges, allDayLabel: allDayLabel);
      }
    }

    return original;
  }

  String _joinTimeRanges(List<List<int>> ranges, {required String allDayLabel}) {
    if (ranges.isEmpty) return allDayLabel;

    final sorted = ranges
        .map((range) => [range[0], range[1]])
        .toList()
      ..sort((a, b) => a[0].compareTo(b[0]));

    final List<List<int>> merged = [];
    for (final range in sorted) {
      if (merged.isEmpty || range[0] > merged.last[1]) {
        merged.add([range[0], range[1]]);
      } else if (range[1] > merged.last[1]) {
        merged.last[1] = range[1];
      }
    }

    if (merged.length == 1 && merged.first[0] == 0 && merged.first[1] == 24) {
      return allDayLabel;
    }

    return merged.map((range) => '${range[0]}시~${range[1]}시').join(', ');
  }

  Map<String, Color> _locationChipColors(String raw) {
    final value = raw.trim();
    final compact = value.replaceAll(' ', '').toLowerCase();

    if (compact.isEmpty) {
      return {
        'bg': const Color(0xFFF4F6F8),
        'border': const Color(0xFFE5E7EB),
        'text': const Color(0xFF6B7280),
      };
    }

    // 숲 / 대나무 숲 / 참나무 숲
    if (compact.contains('대나무숲')) {
      return {
        'bg': const Color(0xFFEAF7EE),
        'border': const Color(0xFFCFE8D7),
        'text': const Color(0xFF3E8E5A),
      };
    }

    if (compact.contains('참나무숲')) {
      return {
        'bg': const Color(0xFFF0F7EE),
        'border': const Color(0xFFDDEBD8),
        'text': const Color(0xFF5A8A57),
      };
    }

    if (compact.contains('숲')) {
      return {
        'bg': const Color(0xFFEFF8F1),
        'border': const Color(0xFFD7EEDC),
        'text': const Color(0xFF4E9A62),
      };
    }

    // 집 앞 / 주거지
    if (compact.contains('집앞') ||
        compact.contains('주거지') ||
        compact.contains('홈') ||
        compact.contains('가정')) {
      return {
        'bg': const Color(0xFFFFF1EC),
        'border': const Color(0xFFFFD9CF),
        'text': const Color(0xFFE87963),
      };
    }

    // 꽃밭
    if (compact.contains('꽃밭')) {
      return {
        'bg': const Color(0xFFFFF0FA),
        'border': const Color(0xFFF6D6EC),
        'text': const Color(0xFFC05A9D),
      };
    }

    // 온천산
    if (compact.contains('온천산') || compact.contains('온천')) {
      return {
        'bg': const Color(0xFFFFF1E8),
        'border': const Color(0xFFFFDDC7),
        'text': const Color(0xFFD67C4A),
      };
    }

    // 도시 / 도심 / 도시 근교
    if (compact.contains('도심')) {
      return {
        'bg': const Color(0xFFF1F5FF),
        'border': const Color(0xFFDCE6FF),
        'text': const Color(0xFF6479C8),
      };
    }

    if (compact.contains('도시근교') ||
        compact.contains('도시') ||
        compact.contains('교외') ||
        compact.contains('근교')) {
      return {
        'bg': const Color(0xFFF4F0FF),
        'border': const Color(0xFFE3D8FF),
        'text': const Color(0xFF7A63C7),
      };
    }

    // 어촌
    if (compact.contains('어촌등대')) {
      return {
        'bg': const Color(0xFFEAF7FF),
        'border': const Color(0xFFCFEAFF),
        'text': const Color(0xFF4A91B8),
      };
    }

    if (compact.contains('어촌부두')) {
      return {
        'bg': const Color(0xFFEFFBFA),
        'border': const Color(0xFFD6F0EE),
        'text': const Color(0xFF4A9B95),
      };
    }

    if (compact.contains('어촌광장') || compact.contains('어촌')) {
      return {
        'bg': const Color(0xFFE9F7FF),
        'border': const Color(0xFFCDEBFA),
        'text': const Color(0xFF3D92B8),
      };
    }

    // 강
    if (compact.contains('거목강')) {
      return {
        'bg': const Color(0xFFEAF7EE),
        'border': const Color(0xFFCFE8D7),
        'text': const Color(0xFF3E8E5A),
      };
    }

    if (compact.contains('고요한강')) {
      return {
        'bg': const Color(0xFFEAF4FF),
        'border': const Color(0xFFCFE2FF),
        'text': const Color(0xFF4A7FD1),
      };
    }

    if (compact.contains('노을강')) {
      return {
        'bg': const Color(0xFFFFEFE6),
        'border': const Color(0xFFFFD8C2),
        'text': const Color(0xFFDD7A4A),
      };
    }

    if (compact.contains('얕은강')) {
      return {
        'bg': const Color(0xFFF2FBF7),
        'border': const Color(0xFFD9F1E7),
        'text': const Color(0xFF4AA37C),
      };
    }

    if (compact.contains('강전체') || compact == '강' || compact.contains('강가')) {
      return {
        'bg': const Color(0xFFEDF6FF),
        'border': const Color(0xFFD8E9FF),
        'text': const Color(0xFF5A8FD8),
      };
    }

    // 호수 / 호숫가
    if (compact.contains('호숫가')) {
      return {
        'bg': const Color(0xFFF2F7FF),
        'border': const Color(0xFFDCE9FF),
        'text': const Color(0xFF5C84C9),
      };
    }

    if (compact.contains('숲속호수')) {
      return {
        'bg': const Color(0xFFF0F7EE),
        'border': const Color(0xFFDDEBD8),
        'text': const Color(0xFF5A8A57),
      };
    }

    if (compact.contains('초원호수')) {
      return {
        'bg': const Color(0xFFF3FAEA),
        'border': const Color(0xFFE0F0C8),
        'text': const Color(0xFF7AA33C),
      };
    }

    if (compact.contains('근교호수')) {
      return {
        'bg': const Color(0xFFF2F6FF),
        'border': const Color(0xFFDEE7FF),
        'text': const Color(0xFF6C7FD8),
      };
    }

    if (compact.contains('화산호')) {
      return {
        'bg': const Color(0xFFFFF1E8),
        'border': const Color(0xFFFFDDC7),
        'text': const Color(0xFFD67C4A),
      };
    }

    if (compact.contains('온천산호수') || compact.contains('온천산수')) {
      return {
        'bg': const Color(0xFFFFF1E8),
        'border': const Color(0xFFFFDDC7),
        'text': const Color(0xFFD67C4A),
      };
    }

    if (compact.contains('호수전체') ||
        compact == '호수' ||
        compact.contains('연못')) {
      return {
        'bg': const Color(0xFFF2F7FF),
        'border': const Color(0xFFDCE9FF),
        'text': const Color(0xFF5C84C9),
      };
    }

    // 바다 / 해변
    if (compact.contains('보라해변')) {
      return {
        'bg': const Color(0xFFF4ECFF),
        'border': const Color(0xFFE0D0FF),
        'text': const Color(0xFF7C5CCB),
      };
    }

    if (compact.contains('고래해변') || compact.contains('고래바다')) {
      return {
        'bg': const Color(0xFFEDEBFF),
        'border': const Color(0xFFD9D3FF),
        'text': const Color(0xFF6E63C7),
      };
    }

    if (compact.contains('동해')) {
      return {
        'bg': const Color(0xFFEAF3FF),
        'border': const Color(0xFFD1E2FF),
        'text': const Color(0xFF4F7ECF),
      };
    }

    if (compact.contains('구해')) {
      return {
        'bg': const Color(0xFFE9F7FF),
        'border': const Color(0xFFCDEBFA),
        'text': const Color(0xFF3D92B8),
      };
    }

    if (compact.contains('잔잔한바다')) {
      return {
        'bg': const Color(0xFFEFFBFA),
        'border': const Color(0xFFD6F0EE),
        'text': const Color(0xFF4A9B95),
      };
    }

    if (compact.contains('바다전체')) {
      return {
        'bg': const Color(0xFFF0F6FF),
        'border': const Color(0xFFD9E6FF),
        'text': const Color(0xFF5F86C9),
      };
    }

    if (compact.contains('바다낚시사건') || compact.contains('바다낚시')) {
      return {
        'bg': const Color(0xFFFFF0F5),
        'border': const Color(0xFFFFD8E6),
        'text': const Color(0xFFD86A92),
      };
    }

    if (compact.contains('바다') ||
        compact.contains('해변') ||
        compact.contains('해안') ||
        compact.contains('해')) {
      return {
        'bg': const Color(0xFFF0F7FF),
        'border': const Color(0xFFD9E9FF),
        'text': const Color(0xFF5B88C7),
      };
    }

    // 들판 / 초원
    if (compact.contains('들판') ||
        compact.contains('초원') ||
        compact.contains('평원')) {
      return {
        'bg': const Color(0xFFF3FAEA),
        'border': const Color(0xFFE0F0C8),
        'text': const Color(0xFF7AA33C),
      };
    }

    // 유인 / 특수 / 이벤트
    if (compact.contains('유인')) {
      return {
        'bg': const Color(0xFFFFF7D6),
        'border': const Color(0xFFFFE6A3),
        'text': const Color(0xFFB7791F),
      };
    }

    if (compact.contains('특수') ||
        compact.contains('이벤트') ||
        compact.contains('사건') ||
        compact.contains('블랑코')) {
      return {
        'bg': const Color(0xFFFFF0F5),
        'border': const Color(0xFFFFD8E6),
        'text': const Color(0xFFD86A92),
      };
    }

    return {
      'bg': const Color(0xFFF4F6F8),
      'border': const Color(0xFFE5E7EB),
      'text': const Color(0xFF6B7280),
    };
  }

  Widget _buildLocationTag(String location) {
    final colors = _locationChipColors(location);

    return _buildBaseChip(
      location,
      bg: colors['bg']!,
      border: colors['border']!,
      textColor: colors['text']!,
    );
  }

  String _normalizeLocationLabel(String raw) {
    final value = raw.trim();
    final compact = value.replaceAll(' ', '').toLowerCase();

    if (compact.isEmpty) return '';

    if (compact.contains('이상한대나무숲') || compact.contains('대나무숲')) {
      return '대나무 숲';
    }
    if (compact.contains('영혼의참나무숲') || compact.contains('참나무숲')) {
      return '참나무 숲';
    }
    if (compact.contains('숲')) return '숲';

    if (compact.contains('집앞')) return '집 앞';

    if (compact.contains('도시근교') || compact.contains('도심') || compact.contains('도시')) {
      return compact.contains('도심') ? '도심' : '도시';
    }

    if (compact.contains('어촌')) return '어촌';
    if (compact.contains('해변')) return '해변';
    if (compact.contains('바다') || compact.contains('해안') || compact.contains('sea') || compact.contains('ocean')) {
      return '바다';
    }

    if (compact.contains('호수') || compact.contains('연못') || compact.contains('lake')) {
      return '호수';
    }

    if (compact.contains('강') || compact.contains('하천') || compact.contains('river')) {
      return '강';
    }

    if (compact.contains('들판') || compact.contains('초원') || compact.contains('평원') || compact.contains('field')) {
      return '들판';
    }

    return value;
  }

  String _normalizeInsectLocationLabel(String raw) {
    final value = raw.trim();
    final compact = value.replaceAll(' ', '').toLowerCase();

    if (compact.isEmpty) return '';

    if (compact.contains('이상한대나무숲') || compact.contains('대나무숲')) {
      return '대나무 숲';
    }

    if (compact.contains('영혼의참나무숲') || compact.contains('참나무숲')) {
      return '참나무 숲';
    }

    if (compact.contains('숲속호수')) return '호숫가';
    if (compact.contains('숲속섬')) return '숲';
    if (compact.contains('숲점프스테이지') || compact.contains('점핑플랫폼') || compact.contains('점프')) {
      return '숲';
    }
    if (compact.contains('숲')) return '숲';

    if (compact.contains('집근처')) return '집 앞';

    if (compact.contains('어촌')) {
      if (compact.contains('등대')) return '어촌 등대';
      if (compact.contains('부두')) return '어촌 부두';
      if (compact.contains('광장')) return '어촌 광장';
      return '어촌';
    }

    if (compact.contains('도시근교') && compact.contains('호수')) return '호수';
    if (compact.contains('도시근교')) return '도시 근교';
    if (compact == '도시') return '도시';

    if (compact.contains('꽃밭') && compact.contains('보라')) return '보라 해변';
    if (compact.contains('꽃밭') && compact.contains('고래산')) return '꽃밭';
    if (compact.contains('풍차꽃밭')) return '꽃밭';
    if (compact.contains('꽃밭')) return '꽃밭';

    if (compact.contains('고래산')) return '들판';
    if (compact.contains('강가')) return '강';
    if (compact.contains('물가')) return '호숫가';
    if (compact.contains('화산호')) return '호수';
    if (compact.contains('호수')) return '호수';

    if (compact.contains('해변')) {
      if (compact.contains('보라')) return '보라 해변';
      return '해변';
    }

    if (compact.contains('온천산') || compact.contains('온천산') || compact.contains('온천')) {
      return '온천산';
    }

    if (compact.contains('곤충유인') || compact.contains('유인장치') || compact.contains('에어벌유인장치')) {
      return '유인';
    }

    return value;
  }

  bool _matchesNormalizedLocation(String rawLocation, String filter) {
    final normalized = _normalizeLocationLabel(rawLocation);

    switch (filter) {
      case '숲':
        return normalized == '숲' ||
            normalized == '대나무 숲' ||
            normalized == '참나무 숲';
      case '집 앞':
        return normalized == '집 앞';
      case '호수':
        return normalized == '호수';
      case '바다':
        return normalized == '바다' || normalized == '해변';
      case '도시':
        return normalized == '도시' || normalized == '도심';
      case '어촌':
        return normalized == '어촌';
      default:
        return true;
    }
  }

  int? _extractRepresentativeHour(String raw) {
    final text = raw.trim().replaceAll(' ', '');
    if (text.isEmpty) return null;

    if (text == '하루종일' || text == '0시~24시') return 12;

    final matches = RegExp(r'(\d{1,2})시').allMatches(text).toList();
    if (matches.isEmpty) return null;

    final hours = matches
        .map((m) => int.tryParse(m.group(1) ?? ''))
        .whereType<int>()
        .toList();

    if (hours.isEmpty) return null;

    return hours.first;
  }

  Map<String, Color> _levelChipColors(int level) {
    if (level == 1) {
      return {
        'bg': const Color(0xFFEEEEEE),
        'border': const Color(0xFFBDBDBD),
        'text': const Color(0xFF616161),
      };
    } else if (level == 2) {
      return {
        'bg': const Color(0xFFFFEBEE),
        'border': const Color(0xFFFFCDD2),
        'text': const Color(0xFFC62828),
      };
    } else if (level == 3) {
      return {
        'bg': const Color(0xFFFFF3E0),
        'border': const Color(0xFFFFE0B2),
        'text': const Color(0xFFE65100),
      };
    } else if (level == 4) {
      return {
        'bg': const Color(0xFFFFFDE7),
        'border': const Color(0xFFFFF9C4),
        'text': const Color(0xFFF57F17),
      };
    } else if (level == 5) {
      return {
        'bg': const Color(0xFFE8F5E9),
        'border': const Color(0xFFC8E6C9),
        'text': const Color(0xFF2E7D32),
      };
    } else if (level == 6) {
      return {
        'bg': const Color(0xFFE1F5FE),
        'border': const Color(0xFFB3E5FC),
        'text': const Color(0xFF0277BD),
      };
    } else if (level == 7) {
      return {
        'bg': const Color(0xFFE8EAF6),
        'border': const Color(0xFFC5CAE9),
        'text': const Color(0xFF1A237E),
      };
    } else if (level == 8) {
      return {
        'bg': const Color(0xFFF3E5F5),
        'border': const Color(0xFFE1BEE7),
        'text': const Color(0xFF7B1FA2),
      };
    } else if (level == 9) {
      return {
        'bg': const Color(0xFFFCE4EC),
        'border': const Color(0xFFF8BBD0),
        'text': const Color(0xFFC2185B),
      };
    } else {
      return {
        'bg': const Color(0xFFFFF8E1),
        'border': const Color(0xFFFFECB3),
        'text': const Color(0xFFEF6C00),
      };
    }
  }

  Map<String, Color> _timeChipColors(String raw) {
    final hour = _extractRepresentativeHour(raw);

    if (hour == null) {
      return {
        'bg': const Color(0xFFF4F6F8),
        'border': const Color(0xFFE5E7EB),
        'text': const Color(0xFF6B7280),
      };
    }

    if (hour >= 5 && hour < 8) {
      return {
        'bg': const Color(0xFFFFF3E8),
        'border': const Color(0xFFFFDDB8),
        'text': const Color(0xFFD97706),
      };
    }

    if (hour >= 8 && hour < 17) {
      return {
        'bg': const Color(0xFFFFF7D6),
        'border': const Color(0xFFFFE6A3),
        'text': const Color(0xFFB7791F),
      };
    }

    if (hour >= 17 && hour < 20) {
      return {
        'bg': const Color(0xFFFFEAE5),
        'border': const Color(0xFFFFCFC2),
        'text': const Color(0xFFDD6B55),
      };
    }

    return {
      'bg': const Color(0xFFEAEFFF),
      'border': const Color(0xFFC9D6FF),
      'text': const Color(0xFF4C5DAA),
    };
  }

  String _formatAvailableTimeChip(String? time) {
    return _formatTimeRangeLabel(time, allDayLabel: '');
  }

  Color _growthTimeChipColor(String raw) {
    final value = raw.replaceAll(' ', '');

    if (value.contains('18시간')) return const Color(0xFFE8F7E8); // 연초록
    if (value.contains('1일6시간')) return const Color(0xFFFFF1E0); // 연주황
    if (value.contains('1일')) return const Color(0xFFEAF4FF); // 연하늘
    if (value.contains('2일')) return const Color(0xFFF3ECFF); // 연보라
    if (value.contains('3일')) return const Color(0xFFFFE7EF); // 연핑크
    return const Color(0xFFF4F6F8); // 기본
  }

  Color _growthTimeChipTextColor(String raw) {
    final value = raw.replaceAll(' ', '');

    if (value.contains('18시간')) return const Color(0xFF4E9B57);
    if (value.contains('1일6시간')) return const Color(0xFFCC7A00);
    if (value.contains('1일')) return const Color(0xFF4A7FD1);
    if (value.contains('2일')) return const Color(0xFF7A5BC1);
    if (value.contains('3일')) return const Color(0xFFD35B87);
    return const Color(0xFF6B7280);
  }

  Widget _buildGrowthTimeTag(String text) {
    final label = _formatGrowthTimeLabel(text);
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5), // ← 동일
      decoration: BoxDecoration(
        color: _growthTimeChipColor(text),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _growthTimeChipTextColor(text).withOpacity(0.16),
          width: 0.8,
        ),
      ),
      child: Transform.translate(
        offset: const Offset(0, -0.5), // ← 동일
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5, // ← 동일
            height: 1.0,
            fontWeight: FontWeight.w600,
            color: _growthTimeChipTextColor(text),
          ),
        ),
      ),
    );
  }

  String _formatGrowthTimeLabel(String raw) {
    final value = raw.trim().replaceAll(' ', '');

    if (value.isEmpty || value == '-') return '';

    if (value.contains('18시간')) return '성장 18시간';
    if (value.contains('1일6시간')) return '성장 1일 6시간';
    if (value.contains('1일')) return '성장 1일';
    if (value.contains('2일')) return '성장 2일';
    if (value.contains('3일')) return '성장 3일';

    return '성장 $raw';
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
        _resetTabScopedFiltersIfNeeded(_tabController.index);
      }
    });
    _searchController.addListener(_onSearchChanged);

    _loadFavorites();
    _loadAchievementStars();
    _loadMasteryDoneMap();
    _fetchAllData();

    widget.searchController?.addListener(_handleExternalSearch);
  }


  void _resetTabScopedFiltersIfNeeded(int newIndex) {
    if (_lastTabIndex == newIndex) return;
    _lastTabIndex = newIndex;

    if (!mounted) return;

    setState(() {
      _selectedFilter = '전체';
      _selectedLevelFilters.clear();
      _selectedAchievementStarFilters.clear();
      _selectedWeatherFilters.clear();
      _selectedFishShadowFilters.clear();
      _selectedMasteryCompletionFilters.clear();
      _selectedPastSeasonFilters
        ..clear()
        ..add('제외');
    });

    _applyFilters();
  }

  @override
  void didUpdateWidget(covariant GatheringScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController?.removeListener(_handleExternalSearch);
      widget.searchController?.addListener(_handleExternalSearch);
    }

    if (widget.resetSearchSignal != oldWidget.resetSearchSignal) {
      _clearSearchState();
    }
  }

  @override
  void dispose() {
    widget.searchController?.removeListener(_handleExternalSearch);
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();

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

  void _scrollToTopForTab(
      GatheringTabType tab, {
        int retryCount = 0,
      }) {
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
    }

    if (controller == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!controller!.hasClients) {
        if (retryCount < 8) {
          Future.delayed(const Duration(milliseconds: 80), () {
            if (!mounted) return;
            _scrollToTopForTab(tab, retryCount: retryCount + 1);
          });
        }
        return;
      }

      controller!.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _applySearchItem(GlobalSearchItem item) {
    _pendingSearchItem = item;

    if (item.gatheringTab == null) return;

    final normalizedId = _normalizeGatheringTargetId(item.id);
    final displayText = item.title.trim();
    final keyword = (item.keyword ?? item.title).trim().toLowerCase();

    _searchController.value = TextEditingValue(
      text: displayText,
      selection: TextSelection.collapsed(offset: displayText.length),
    );
    _searchQuery = keyword;
    _selectedFilter = '전체';
    _selectedLevelFilters.clear();
    _selectedAchievementStarFilters.clear();
    _selectedWeatherFilters.clear();
    _selectedFishShadowFilters.clear();

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

      String resolvedHighlightId = normalizedId;

      if (item.gatheringTab == GatheringTabType.fish) {
        final normalizedTitle =
        item.title.trim().replaceAll(' ', '').toLowerCase();
        final normalizedKeyword =
        (item.keyword ?? item.title).trim().replaceAll(' ', '').toLowerCase();

        for (final fish in _visibleFishList) {
          final fishName =
          _displayName(fish).trim().replaceAll(' ', '').toLowerCase();
          final fishNameKo =
          (fish.nameKo ?? '').trim().replaceAll(' ', '').toLowerCase();

          final idMatch = fish.id.trim() == normalizedId.trim();
          final nameMatch =
              fishName == normalizedTitle ||
                  fishName == normalizedKeyword ||
                  fishNameKo == normalizedTitle ||
                  fishNameKo == normalizedKeyword;

          if (idMatch || nameMatch) {
            resolvedHighlightId = fish.id;
            break;
          }
        }
      }

      setState(() {
        _highlightedId = resolvedHighlightId;
      });

      _scrollToTopForTab(item.gatheringTab!);

      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;

        _searchController.clear();
        _searchQuery = '';
        _applyFilters();
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;

        setState(() {
          if (_highlightedId == resolvedHighlightId) {
            _highlightedId = null;
          }
          _pendingSearchItem = null;
        });
      });
    });
  }

  Future<void> _openFlowerDetail(PlantItem plant) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.keepers-note.o-r.kr/api/gardening/${plant.id}'),
      );

      if (response.statusCode != 200) {
        debugPrint('꽃 상세 조회 실패: ${response.statusCode}');
        return;
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      // 상세 API가 아직 mastery/event 값을 안 내려주는 경우,
      // 목록 API에서 이미 받은 PlantItem 값으로 보강해서 상세페이지에 표시합니다.
      final detail = FlowerDetail.fromJson({
        ...json,
        'masteryCount': json['masteryCount'] ??
            json['mastery_count'] ??
            plant.masteryCount,
        'masteryEntryCount': json['masteryEntryCount'] ??
            json['mastery_entry_count'] ??
            plant.masteryEntryCount,
        'masterySkilledCount': json['masterySkilledCount'] ??
            json['mastery_skilled_count'] ??
            plant.masterySkilledCount,
        'masteryMasterCount': json['masteryMasterCount'] ??
            json['mastery_master_count'] ??
            plant.masteryMasterCount,
        'eventTokenPrice1': json['eventTokenPrice1'] ??
            json['event_token_price_1'] ??
            (plant.eventTokenPrices.isNotEmpty ? plant.eventTokenPrices[0] : 0),
        'eventTokenPrice2': json['eventTokenPrice2'] ??
            json['event_token_price_2'] ??
            (plant.eventTokenPrices.length > 1 ? plant.eventTokenPrices[1] : 0),
        'eventTokenPrice3': json['eventTokenPrice3'] ??
            json['event_token_price_3'] ??
            (plant.eventTokenPrices.length > 2 ? plant.eventTokenPrices[2] : 0),
        'eventTokenPrice4': json['eventTokenPrice4'] ??
            json['event_token_price_4'] ??
            (plant.eventTokenPrices.length > 3 ? plant.eventTokenPrices[3] : 0),
        'eventTokenPrice5': json['eventTokenPrice5'] ??
            json['event_token_price_5'] ??
            (plant.eventTokenPrices.length > 4 ? plant.eventTokenPrices[4] : 0),
        'seasonTag': json['seasonTag'] ??
            json['season_tag'] ??
            json['pastSeason'] ??
            json['past_season'] ??
            json['seasonName'] ??
            json['season_name'] ??
            json['eventSeason'] ??
            json['event_season'] ??
            json['season'] ??
            plant.seasonTag,
      });

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FlowerDetailPage(detail: detail),
        ),
      );

      await _loadMasteryDoneMap();
      await _loadAchievementStars();
      _applyFilters();
    } catch (e) {
      debugPrint('꽃 상세 로드 실패: $e');
    }
  }

  Future<void> _openFishDetail(FishItem fish) async {
    final bool hideMastery = _isEventOrPastSeasonItem(
      eventTokenPrices: fish.eventTokenPrices,
      seasonTag: fish.seasonTag,
      textValues: [fish.id, fish.name, fish.nameKo, fish.image, fish.location],
    );
    final fishPrices = [
      fish.price1 ?? 0,
      fish.price2 ?? 0,
      fish.price3 ?? 0,
      fish.price4 ?? 0,
      fish.price5 ?? 0,
    ];

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GatheringSimpleDetailPage(
          title: _displayName(fish),
          categoryLabel: '물고기',
          levelLabel: fish.level == null ? '-' : '낚시 ${fish.level}레벨',
          image: fish.image,
          fallbackIcon: Icons.set_meal_rounded,
          prices: fishPrices,
          eventTokenPrices: fish.eventTokenPrices,
          masteryDoneKey: hideMastery ? null : 'fish:${fish.id}',
          achievementStarKey: 'fish:${fish.id}',
          masteryDoneLabel: '낚시 명인 달성',
          timeText: _formatDetailAvailableTime(fish.availableTime),
          locationText: fish.location.trim().isEmpty ? '-' : fish.location.trim(),
          weatherText: _formatDetailWeather(fish.weather),
          appearanceInfo: [
            if (fish.shadowSize.trim().isNotEmpty)
              {
                'label': '그림자 크기',
                'value': _normalizeShadowSize(fish.shadowSize),
              },
          ],
          extraInfo: hideMastery
              ? const []
              : [
            ..._buildMasteryStageExtraInfo(
              '낚시',
              fish.masteryMasterCount > 0 ? fish.masteryMasterCount : fish.masteryCount,
              entryCount: fish.masteryEntryCount,
              skilledCount: fish.masterySkilledCount,
              exactMasterCount: fish.masteryMasterCount,
              unit: '마리',
            ),
          ],
        ),
      ),
    );
    await _loadMasteryDoneMap();
    await _loadAchievementStars();
    _applyFilters();
  }

  Future<void> _openBirdDetail(BirdItem bird) async {
    final bool hideMastery = _isEventOrPastSeasonItem(
      eventTokenPrices: bird.eventTokenPrices,
      seasonTag: bird.seasonTag,
      textValues: [bird.id, bird.name, bird.nameKo, bird.image, bird.location],
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GatheringSimpleDetailPage(
          title: _displayBirdName(bird),
          categoryLabel: '새',
          levelLabel: '촬영 ${bird.level}레벨',
          image: bird.image,
          fallbackIcon: Icons.flutter_dash_rounded,
          prices: bird.prices,
          eventTokenPrices: bird.eventTokenPrices,
          masteryDoneKey: hideMastery ? null : 'bird:${bird.id}',
          achievementStarKey: 'bird:${bird.id}',
          masteryDoneLabel: '촬영 명인 달성',
          timeText: _formatDetailAvailableTime(
            bird.timeKey.isNotEmpty ? bird.timeKey : bird.availableTime,
          ),
          locationText: bird.location.trim().isEmpty
              ? '-'
              : bird.location.trim(),
          weatherText: _formatDetailWeather(bird.weather),
          appearanceInfo: [
            if (bird.captureDistance.trim().isNotEmpty)
              {'label': '포착 거리', 'value': bird.captureDistance.trim()},
            if (bird.wingSpread.trim().isNotEmpty)
              {'label': '날개 펴기', 'value': _formatOccurrenceSubInfo(bird.wingSpread)},
            if (bird.whistle.trim().isNotEmpty)
              {'label': '호루라기', 'value': _formatOccurrenceSubInfo(bird.whistle)},
          ],
          extraInfo: hideMastery
              ? const []
              : [
            ..._buildMasteryStageExtraInfo('촬영', bird.masteryCount, entryCount: bird.masteryEntryCount, skilledCount: bird.masterySkilledCount, exactMasterCount: bird.masteryMasterCount, unit: '회'),
          ],
        ),
      ),
    );
    await _loadMasteryDoneMap();
    await _loadAchievementStars();
    _applyFilters();
  }

  Future<void> _openInsectDetail(InsectItem insect) async {
    final bool hideMastery = _isEventOrPastSeasonItem(
      eventTokenPrices: insect.eventTokenPrices,
      seasonTag: insect.seasonTag,
      textValues: [insect.id, insect.name, insect.nameKo, insect.image, insect.location],
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GatheringSimpleDetailPage(
          title: _displayInsectName(insect),
          categoryLabel: '곤충',
          levelLabel: '곤충 채집 ${insect.level}레벨',
          image: insect.image,
          fallbackIcon: Icons.bug_report,
          prices: insect.prices,
          eventTokenPrices: insect.eventTokenPrices,
          masteryDoneKey: hideMastery ? null : 'insect:${insect.id}',
          achievementStarKey: 'insect:${insect.id}',
          masteryDoneLabel: '곤충 채집 명인 달성',
          timeText: _formatDetailAvailableTime(insect.availableTime),
          locationText: insect.location.trim().isEmpty
              ? '-'
              : insect.location.trim(),
          weatherText: _formatDetailWeather(insect.weather),
          extraInfo: hideMastery
              ? const []
              : [
            ..._buildMasteryStageExtraInfo('곤충 채집', insect.masteryCount, entryCount: insect.masteryEntryCount, skilledCount: insect.masterySkilledCount, exactMasterCount: insect.masteryMasterCount, unit: '마리'),
          ],
        ),
      ),
    );
    await _loadMasteryDoneMap();
    await _loadAchievementStars();
    _applyFilters();
  }

  String _formatDetailAvailableTime(String? time) {
    return _formatTimeRangeLabel(time, allDayLabel: '하루종일');
  }

  String _formatDetailWeather(String raw) {
    final labels = _normalizeWeatherLabel(raw);
    if (labels.isNotEmpty) return labels.join(', ');

    final compact = raw.trim().replaceAll(' ', '').toLowerCase();
    if (compact.isEmpty ||
        compact == 'any' ||
        compact == 'all' ||
        compact == 'unknown' ||
        compact == '전체' ||
        compact == '모든날씨') {
      return '모든 날씨';
    }

    return raw.trim();
  }


  Future<void> _loadFavorites() async {
    await CollectionProgressService.mergeRemoteIntoLocal(
      favoritesKey: _favoritesKey,
      achievementStarsKey: _achievementStarsKey,
      onLoaded: (favorites, stars, mastery) {
        if (!mounted) return;
        setState(() {
          _favoriteIds = favorites;
          _achievementStars = stars;
          _masteryDoneMap = mastery;
        });
      },
    );
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favoriteIds.toList());
  }


  Future<void> _loadAchievementStars() async {
    await CollectionProgressService.mergeRemoteIntoLocal(
      favoritesKey: _favoritesKey,
      achievementStarsKey: _achievementStarsKey,
      onLoaded: (favorites, stars, mastery) {
        if (!mounted) return;
        setState(() {
          _favoriteIds = favorites;
          _achievementStars = stars;
          _masteryDoneMap = mastery;
        });
      },
    );
  }

  Future<void> _saveAchievementStars() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_achievementStarsKey, jsonEncode(_achievementStars));
  }

  Future<void> _setAchievementStar(String itemKey, int star) async {
    int nextStar = 0;
    setState(() {
      if (_achievementStars[itemKey] == star) {
        _achievementStars.remove(itemKey);
        nextStar = 0;
      } else {
        _achievementStars[itemKey] = star;
        nextStar = star;
      }
    });
    await _saveAchievementStars();
    await CollectionProgressService.saveAchievementStar(itemKey, nextStar);
    _applyFilters();
  }

  int _achievementStarFor(String itemKey) => _achievementStars[itemKey] ?? 0;

  bool _matchesAchievementStar(String itemKey) {
    if (_selectedAchievementStarFilters.isEmpty) return true;
    return _selectedAchievementStarFilters.contains(_achievementStarFor(itemKey));
  }


  Future<void> _loadMasteryDoneMap() async {
    await CollectionProgressService.mergeRemoteIntoLocal(
      favoritesKey: _favoritesKey,
      achievementStarsKey: _achievementStarsKey,
      onLoaded: (favorites, stars, mastery) {
        if (!mounted) return;
        setState(() {
          _favoriteIds = favorites;
          _achievementStars = stars;
          _masteryDoneMap = mastery;
        });
      },
    );
  }

  bool _matchesMasteryDone(String itemKey) {
    if (_selectedMasteryCompletionFilters.isEmpty) return true;
    final done = _masteryDoneMap[itemKey] == true;
    return (done && _selectedMasteryCompletionFilters.contains('done')) ||
        (!done && _selectedMasteryCompletionFilters.contains('not_done'));
  }

  bool _matchesSelectedWeather(String rawWeather) {
    if (_selectedWeatherFilters.isEmpty) return true;
    final labels = _normalizeWeatherLabel(rawWeather);
    if (labels.isEmpty) return false;
    return labels.any(_selectedWeatherFilters.contains);
  }

  bool _matchesSelectedPastSeason(
      String rawSeasonTag, {
        Iterable<String?> textValues = const [],
      }) {
    final explicitLabel = _normalizeSeasonLabel(rawSeasonTag);
    final label = explicitLabel.isNotEmpty
        ? explicitLabel
        : _inferPastSeasonLabelFromText(textValues);

    // 기본값은 '제외': 지난 시즌 아이템은 목록에서 숨깁니다.
    if (_selectedPastSeasonFilters.isEmpty ||
        _selectedPastSeasonFilters.contains('제외')) {
      return label.isEmpty;
    }

    // 전체: 현재 시즌을 제외하고 지난 시즌 아이템만 보여줍니다.
    if (_selectedPastSeasonFilters.contains('전체')) {
      return label.isNotEmpty;
    }

    if (label.isEmpty) return false;
    return _selectedPastSeasonFilters.contains(label);
  }

  String _normalizeShadowSize(String raw) {
    return _normalizeShadowSizeLabel(raw);
  }

  bool _matchesSelectedShadowSize(FishItem fish) {
    if (_selectedFishShadowFilters.isEmpty) return true;
    return _selectedFishShadowFilters.contains(_normalizeShadowSize(fish.shadowSize));
  }

  Widget _buildAchievementStars(String itemKey) {
    final selected = _achievementStarFor(itemKey);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final star = index + 1;
        final active = selected >= star;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _setAchievementStar(itemKey, star),
          child: SizedBox(
            width: 20,
            height: 28,
            child: Center(
              child: Icon(
                active ? Icons.star_rounded : Icons.star_border_rounded,
                size: 23,
                color: active
                    ? const Color(0xFFFFB84D)
                    : const Color(0xFFD6DEE8),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _toggleFavorite(String itemId) async {
    bool nextLiked = false;
    setState(() {
      if (_favoriteIds.contains(itemId)) {
        _favoriteIds.remove(itemId);
        nextLiked = false;
      } else {
        _favoriteIds.add(itemId);
        nextLiked = true;
      }
    });

    await _saveFavorites();
    await CollectionProgressService.saveFavorite(itemId, nextLiked);
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
        final loadedList = data
            .map((e) => FishItem.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _fishList = loadedList;
          _isFishLoading = false;
        });

        _applyFilters();

        if (_pendingSearchItem != null) {
          _applySearchItem(_pendingSearchItem!);
        }
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
        final loadedList = data
            .map((e) => BirdItem.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _birdList = loadedList;
          _isBirdLoading = false;
        });

        _applyFilters();

        if (_pendingSearchItem != null) {
          _applySearchItem(_pendingSearchItem!);
        }
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
        final loadedList = data
            .map((e) => InsectItem.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _insectList = loadedList;
          _isInsectLoading = false;
        });

        _applyFilters();

        if (_pendingSearchItem != null) {
          _applySearchItem(_pendingSearchItem!);
        }
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
        final loadedList = data
            .map((e) => PlantItem.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _plantList = loadedList;
          _isPlantLoading = false;
        });

        _applyFilters();

        if (_pendingSearchItem != null) {
          _applySearchItem(_pendingSearchItem!);
        }
      } else {
        setState(() {
          _errorMessage = '식물 데이터를 불러오지 못했어요. (${response.statusCode})';
          _isPlantLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '식물 데이터를 불러오는 중 오류가 발생했어요.';
        _isPlantLoading = false;
      });
    }
  }

  bool _containsAny(String source, List<String> keywords) {
    final value = source.toLowerCase().replaceAll(' ', '');
    return keywords.any((k) => value.contains(k.toLowerCase().replaceAll(' ', '')));
  }

  bool _containsBrickKeyword(List<String?> values) {
    return values.any((value) {
      final compact = (value ?? '').toLowerCase().replaceAll(' ', '');
      return compact.contains('brick') || compact.contains('브릭');
    });
  }

  bool _matchesFishFilter(FishItem fish, String filter) {
    final location = fish.location.toLowerCase();
    final weather = fish.weather.toLowerCase();

    final isRiver = _containsAny(location, ['river', '강', '하천']);
    final isLake = _containsAny(location, ['lake', '호수', '연못']);
    final normalizedLocation = location.replaceAll(' ', '');

    final isSea = _containsAny(normalizedLocation, [
      '바다', '해', '고래바다', '잔잔한바다'
    ]);

    switch (filter) {
      case '강 물고기':
        return isRiver;
      case '호수 물고기':
        return isLake;
      case '바다 물고기':
        return isSea;
      case '이벤트':
        return _containsBrickKeyword([
          fish.id,
          fish.name,
          fish.nameKo,
          fish.image,
          fish.location,
        ]);
      case '맑음':
      case '비':
      case '눈':
        return weather.contains(filter.toLowerCase());
      default:
        return true;
    }
  }

  void _handleExternalSearch() {
    final item = widget.searchController?.consume();
    if (item == null) return;
    _applySearchItem(item);
  }

  bool _matchesBirdFilter(BirdItem bird, String filter) {
    final location = bird.location.toLowerCase().replaceAll(' ', '');

    bool hasAny(List<String> keywords) {
      return keywords.any((k) => location.contains(k.toLowerCase().replaceAll(' ', '')));
    }

    switch (filter) {
      case '숲':
        return hasAny([
          '숲',
          '대나무숲',
          '참나무숲',
          '숲속',
        ]);

      case '호수':
        return hasAny([
          '호수',
          '호숫가',
          '연못',
          '시외호',
          '화산호',
        ]);

      case '강':
        return hasAny([
          '강',
        ]);

      case '바다/해변':
        return hasAny([
          '바다',
          '해변',
          '해안',
          '동해',
          '고래바다',
          '잔잔한바다',
          '완풍해',
          '구해',
        ]);

      case '어촌':
        return hasAny([
          '어촌',
          '등대',
          '부두',
        ]);

      case '도시':
        return hasAny([
          '도심',
          '도시근교',
          '도시',
          '교외',
          '근교',
        ]);

      case '꽃밭':
        return hasAny([
          '꽃밭',
        ]);

      case '주거지':
        return hasAny([
          '홈',
          '가정',
        ]);

      case '온천산':
        return hasAny([
          '온천산',
          '온천',
        ]);

      case '특수':
        return hasAny([
          '사건',
          '블랑코머리위',
        ]);

      case '이벤트':
        return _containsBrickKeyword([
          bird.id,
          bird.name,
          bird.nameKo,
          bird.image,
          bird.location,
        ]);

      default:
        return true;
    }
  }

  bool _matchesPlantFilter(PlantItem plant, String filter) {
    if (filter == '이벤트') {
      return _containsBrickKeyword([
        plant.id,
        plant.name,
        plant.nameKo,
        plant.image,
        plant.location,
      ]);
    }

    return true;
  }

  bool _matchesInsectFilter(InsectItem insect, String filter) {
    final normalized = _normalizeInsectLocationLabel(insect.location);

    switch (filter) {
      case '숲':
        return normalized == '숲' ||
            normalized == '대나무 숲' ||
            normalized == '참나무 숲';
      case '집 앞':
        return normalized == '집 앞';
      case '호수':
        return normalized == '호수' || normalized == '호숫가';
      case '바다':
        return normalized == '해변';
      case '도시':
        return normalized == '도시' || normalized == '도시 근교';
      case '어촌':
        return normalized == '어촌' ||
            normalized == '어촌 등대' ||
            normalized == '어촌 부두' ||
            normalized == '어촌 광장';
      case '이벤트':
        return _containsBrickKeyword([
          insect.id,
          insect.name,
          insect.nameKo,
          insect.image,
          insect.location,
        ]);
      default:
        return true;
    }
  }

  String _normalizeBirdLocationLabel(String raw) {
    final value = raw.trim();
    final compact = value.replaceAll(' ', '').toLowerCase();

    if (compact.isEmpty) return '';

    if (compact.contains('이상한대나무숲') || compact.contains('대나무숲')) {
      return '대나무 숲';
    }

    if (compact.contains('영혼의참나무숲') || compact.contains('참나무숲')) {
      return '참나무 숲';
    }

    if (compact.contains('숲속호수') || compact.contains('호숫가')) {
      return '호숫가';
    }

    if (compact.contains('숲속')) return '숲';
    if (compact.contains('숲')) return '숲';

    if (compact.contains('꽃밭')) return '꽃밭';

    if (compact.contains('어촌')) {
      if (compact.contains('등대')) return '어촌 등대';
      if (compact.contains('부두')) return '어촌 부두';
      if (compact.contains('광장')) return '어촌 광장';
      return '어촌';
    }

    if (compact.contains('도심')) return '도심';
    if (compact.contains('도시근교') || compact.contains('교외') || compact.contains('근교')) {
      return '도시 근교';
    }

    if (compact.contains('홈') || compact.contains('가정')) return '주거지';

    if (compact.contains('해변')) {
      if (compact.contains('보라')) return '보라 해변';
      if (compact.contains('고래')) return '고래 해변';
      return '해변';
    }

    if (compact.contains('바다') || compact.contains('해안') || compact.contains('완풍해') || compact.contains('동해') || compact.contains('구해')) {
      return '바다';
    }

    if (compact.contains('호수') || compact.contains('시외호') || compact.contains('화산호')) {
      return '호수';
    }

    if (compact.contains('강')) return '강';

    if (compact.contains('온천산')) return '온천산';

    if (compact.contains('사건')) return '이벤트';
    if (compact.contains('블랑코머리위')) return '특수';

    return value;
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
      _selectedLevelFilters.clear();
      _selectedAchievementStarFilters.clear();
      _selectedWeatherFilters.clear();
      _selectedFishShadowFilters.clear();
      _selectedMasteryCompletionFilters.clear();
      _selectedPastSeasonFilters
        ..clear()
        ..add('제외');
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
    _dismissKeyboard();
    setState(() {
      _selectedFilter = filter;
    });
    _applyFilters();
  }

  void _onSortSelected(String sort) {
    _dismissKeyboard();
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
        return ko.contains(query);
      }).toList();
    }    if (tabIndex == 0 && _selectedFilter != '전체') {
      filteredFish = filteredFish
          .where((item) => _matchesFishFilter(item, _selectedFilter))
          .toList();
    }
    if (_selectedLevelFilters.isNotEmpty) {
      filteredFish = filteredFish
          .where((item) => item.level != null && _selectedLevelFilters.contains(item.level))
          .toList();
    }

    filteredFish = filteredFish
        .where((item) => _matchesAchievementStar('fish:${item.id}'))
        .where((item) => _matchesMasteryDone('fish:${item.id}'))
        .where(_matchesSelectedShadowSize)
        .where((item) => _matchesSelectedWeather(item.weather))
        .where((item) => _matchesSelectedPastSeason(
      item.seasonTag,
      textValues: [item.id, item.name, item.nameKo, item.image, item.location, item.weather],
    ))
        .toList();
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
    if (_selectedLevelFilters.isNotEmpty) {
      filteredBirds = filteredBirds
          .where((item) => _selectedLevelFilters.contains(item.level))
          .toList();
    }

    filteredBirds = filteredBirds
        .where((item) => _matchesAchievementStar('bird:${item.id}'))
        .where((item) => _matchesMasteryDone('bird:${item.id}'))
        .where((item) => _matchesSelectedWeather(item.weather))
        .where((item) => _matchesSelectedPastSeason(
      item.seasonTag,
      textValues: [item.id, item.name, item.nameKo, item.image, item.location, item.weather],
    ))
        .toList();
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
    if (_selectedLevelFilters.isNotEmpty) {
      filteredInsects = filteredInsects
          .where((item) => _selectedLevelFilters.contains(item.level))
          .toList();
    }

    filteredInsects = filteredInsects
        .where((item) => _matchesAchievementStar('insect:${item.id}'))
        .where((item) => _matchesMasteryDone('insect:${item.id}'))
        .where((item) => _matchesSelectedWeather(item.weather))
        .where((item) => _matchesSelectedPastSeason(
      item.seasonTag,
      textValues: [item.id, item.name, item.nameKo, item.image, item.location, item.weather],
    ))
        .toList();
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
    if (_selectedLevelFilters.isNotEmpty) {
      filteredPlants = filteredPlants
          .where((item) => _selectedLevelFilters.contains(item.level))
          .toList();
    }

    filteredPlants = filteredPlants
        .where((item) => _matchesAchievementStar('plant:${item.id}'))
        .where((item) => _matchesMasteryDone('plant:${item.id}'))
        .where((item) => _matchesSelectedWeather(item.weather))
        .where((item) => _matchesSelectedPastSeason(
      item.seasonTag,
      textValues: [item.id, item.name, item.nameKo, item.image, item.location, item.weather, item.growthTime],
    ))
        .toList();
    _sortPlants(filteredPlants);

    if (_pendingSearchItem != null && _pendingSearchItem!.gatheringTab != null) {
      final item = _pendingSearchItem!;
      final normalizedId = _normalizeGatheringTargetId(item.id);

      switch (item.gatheringTab!) {
        case GatheringTabType.fish:
          final normalizedTitle =
          item.title.trim().replaceAll(' ', '').toLowerCase();
          final normalizedKeyword =
          (item.keyword ?? item.title).trim().replaceAll(' ', '').toLowerCase();

          _moveToTopInList<FishItem>(
            filteredFish,
                (e) {
              final idMatch = e.id.trim() == normalizedId.trim();

              final fishName =
              _displayName(e).trim().replaceAll(' ', '').toLowerCase();
              final fishNameKo =
              (e.nameKo ?? '').trim().replaceAll(' ', '').toLowerCase();

              final nameMatch =
                  fishName == normalizedTitle ||
                      fishName == normalizedKeyword ||
                      fishNameKo == normalizedTitle ||
                      fishNameKo == normalizedKeyword;

              return idMatch || nameMatch;
            },
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
      case '레벨순':
        list.sort((a, b) {
          final aLevel = a.level ?? 0;
          final bLevel = b.level ?? 0;
          final levelCompare = aLevel.compareTo(bLevel);
          if (levelCompare != 0) return levelCompare;
          return _displayName(a).compareTo(_displayName(b));
        });
        break;
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
      case '레벨순':
        list.sort((a, b) {
          final levelCompare = a.level.compareTo(b.level);
          if (levelCompare != 0) return levelCompare;
          return _displayBirdName(a).compareTo(_displayBirdName(b));
        });
        break;
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
      case '레벨순':
        list.sort((a, b) {
          final levelCompare = a.level.compareTo(b.level);
          if (levelCompare != 0) return levelCompare;
          return _displayInsectName(a).compareTo(_displayInsectName(b));
        });
        break;
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
      case '레벨순':
        list.sort((a, b) {
          final levelCompare = a.level.compareTo(b.level);
          if (levelCompare != 0) return levelCompare;
          return _displayPlantName(a).compareTo(_displayPlantName(b));
        });
        break;

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
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    final bool showFilterInAppBar = _isFilterVisible;
    final double appBarHeight = topPadding + (showFilterInAppBar ? 214 : 170);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
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

  Widget _buildFlowerColorSummaryBox(FlowerColorSummary color) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showAssetImagePreview(
        title: color.colorNameKo,
        image: color.image,
        fallbackIcon: Icons.local_florist_rounded,
      ),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: const Color(0xC6FFF8E7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              _imageAssetPath(color.image),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.local_florist_rounded,
                size: 16,
                color: Color(0xFF7C6F57),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPressableCard({
    required Widget child,
    required VoidCallback onTap,
  }) {
    bool isPressed = false;

    return StatefulBuilder(
      builder: (context, setCardState) {
        void setPressed(bool value) {
          if (isPressed == value) return;
          setCardState(() => isPressed = value);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setPressed(true),
          onTapCancel: () => setPressed(false),
          onTapUp: (_) async {
            setPressed(false);
            _dismissKeyboard();
            await Future.delayed(const Duration(milliseconds: 20));
            if (!mounted) return;
            onTap();
          },
          child: AnimatedScale(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            scale: isPressed ? 0.982 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, isPressed ? 1.5 : 0, 0),
              child: child,
            ),
          ),
        );
      },
    );
  }
  List<int> _currentLevelOptions() {
    Iterable<int> levels;

    switch (_tabController.index) {
      case 0:
        levels = _fishList.map((e) => e.level ?? 0);
        break;
      case 1:
        levels = _birdList.map((e) => e.level);
        break;
      case 2:
        levels = _insectList.map((e) => e.level);
        break;
      case 3:
        levels = _plantList.map((e) => e.level);
        break;
      default:
        levels = const [1];
    }

    int maxLevel = 1;
    for (final level in levels) {
      if (level > maxLevel) maxLevel = level;
    }

    return List<int>.generate(maxLevel, (index) => index + 1);
  }

  bool _hasActiveFilterSortSheetSettings() {
    return _selectedLevelFilters.isNotEmpty ||
        _selectedAchievementStarFilters.isNotEmpty ||
        _selectedWeatherFilters.isNotEmpty ||
        _selectedFishShadowFilters.isNotEmpty ||
        _selectedMasteryCompletionFilters.isNotEmpty ||
        (_selectedPastSeasonFilters.isNotEmpty &&
            !_selectedPastSeasonFilters.contains('제외')) ||
        _selectedSort != '레벨순';
  }

  Widget _buildFilterSortActionButton() {
    final bool isActive = _hasActiveFilterSortSheetSettings();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: _showFilterSortSheet,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 38,
          height: 36,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFFF1EC)
                : Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFFFD6CC)
                  : const Color(0xFFE9EEF4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8E7C).withOpacity(isActive ? 0.12 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 19,
                color: isActive
                    ? const Color(0xFFFF8E7C)
                    : const Color(0xFF94A3B8),
              ),
              if (_selectedLevelFilters.isNotEmpty)
                Positioned(
                  right: 7,
                  top: 7,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF8E7C),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFF1EC)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFFB8AA)
                  : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? const Color(0xFFFF7E68)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSortSheet() {
    _dismissKeyboard();

    final tempLevels = Set<int>.from(_selectedLevelFilters);
    final tempAchievementStars = Set<int>.from(_selectedAchievementStarFilters);
    final tempWeatherFilters = Set<String>.from(_selectedWeatherFilters);
    final tempShadowFilters = Set<String>.from(_selectedFishShadowFilters);
    final tempMasteryCompletionFilters = Set<String>.from(_selectedMasteryCompletionFilters);
    final tempPastSeasonFilters = Set<String>.from(_selectedPastSeasonFilters);
    if (tempPastSeasonFilters.isEmpty) {
      tempPastSeasonFilters.add('제외');
    }
    String tempSort = _selectedSort;
    final levelOptions = _currentLevelOptions();
    const sortOptions = ['레벨순', '이름순', '가격순', '좋아요순'];
    const weatherOptions = ['맑음', '흐림', '비', '눈', '무지개'];
    const shadowOptions = ['매우 작음', '작음', '중간', '큼', '매우 큼'];
    const pastSeasonOptions = ['제외', '전체', '빙설 시즌', '꿈의 명암'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget sectionTitle(String title) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                  ),
                ),
              );
            }

            Widget chipWrap(List<Widget> children) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: children,
              );
            }

            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.78,
                ),
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '필터 / 정렬',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          splashRadius: 20,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionTitle('정렬'),
                            chipWrap(sortOptions.map((sort) {
                              return _buildSheetChoiceChip(
                                label: sort,
                                isSelected: tempSort == sort,
                                onTap: () => setSheetState(() => tempSort = sort),
                              );
                            }).toList()),
                            const SizedBox(height: 18),
                            sectionTitle('레벨'),
                            chipWrap([
                              _buildSheetChoiceChip(
                                label: '전체',
                                isSelected: tempLevels.isEmpty,
                                onTap: () => setSheetState(tempLevels.clear),
                              ),
                              ...levelOptions.map((level) {
                                return _buildSheetChoiceChip(
                                  label: '$level레벨',
                                  isSelected: tempLevels.contains(level),
                                  onTap: () {
                                    setSheetState(() {
                                      if (tempLevels.contains(level)) {
                                        tempLevels.remove(level);
                                      } else {
                                        tempLevels.add(level);
                                      }
                                    });
                                  },
                                );
                              }),
                            ]),
                            const SizedBox(height: 18),
                            sectionTitle('달성 성급'),
                            chipWrap([
                              _buildSheetChoiceChip(
                                label: '전체',
                                isSelected: tempAchievementStars.isEmpty,
                                onTap: () => setSheetState(tempAchievementStars.clear),
                              ),
                              ...List.generate(5, (index) {
                                final star = index + 1;
                                return _buildSheetChoiceChip(
                                  label: '$star성',
                                  isSelected: tempAchievementStars.contains(star),
                                  onTap: () {
                                    setSheetState(() {
                                      if (tempAchievementStars.contains(star)) {
                                        tempAchievementStars.remove(star);
                                      } else {
                                        tempAchievementStars.add(star);
                                      }
                                    });
                                  },
                                );
                              }),
                            ]),
                            const SizedBox(height: 18),
                            sectionTitle('명인 달성'),
                            chipWrap([
                              _buildSheetChoiceChip(
                                label: '전체',
                                isSelected: tempMasteryCompletionFilters.isEmpty,
                                onTap: () => setSheetState(tempMasteryCompletionFilters.clear),
                              ),
                              _buildSheetChoiceChip(
                                label: '완료',
                                isSelected: tempMasteryCompletionFilters.contains('done'),
                                onTap: () {
                                  setSheetState(() {
                                    if (tempMasteryCompletionFilters.contains('done')) {
                                      tempMasteryCompletionFilters.remove('done');
                                    } else {
                                      tempMasteryCompletionFilters.add('done');
                                    }
                                  });
                                },
                              ),
                              _buildSheetChoiceChip(
                                label: '미완료',
                                isSelected: tempMasteryCompletionFilters.contains('not_done'),
                                onTap: () {
                                  setSheetState(() {
                                    if (tempMasteryCompletionFilters.contains('not_done')) {
                                      tempMasteryCompletionFilters.remove('not_done');
                                    } else {
                                      tempMasteryCompletionFilters.add('not_done');
                                    }
                                  });
                                },
                              ),
                            ]),
                            const SizedBox(height: 18),
                            sectionTitle('등장 날씨'),
                            chipWrap([
                              _buildSheetChoiceChip(
                                label: '전체',
                                isSelected: tempWeatherFilters.isEmpty,
                                onTap: () => setSheetState(tempWeatherFilters.clear),
                              ),
                              ...weatherOptions.map((weather) {
                                return _buildSheetChoiceChip(
                                  label: weather,
                                  isSelected: tempWeatherFilters.contains(weather),
                                  onTap: () {
                                    setSheetState(() {
                                      if (tempWeatherFilters.contains(weather)) {
                                        tempWeatherFilters.remove(weather);
                                      } else {
                                        tempWeatherFilters.add(weather);
                                      }
                                    });
                                  },
                                );
                              }),
                            ]),
                            if (_tabController.index == 0) ...[
                              const SizedBox(height: 18),
                              sectionTitle('그림자 크기'),
                              chipWrap([
                                _buildSheetChoiceChip(
                                  label: '전체',
                                  isSelected: tempShadowFilters.isEmpty,
                                  onTap: () => setSheetState(tempShadowFilters.clear),
                                ),
                                ...shadowOptions.map((shadow) {
                                  return _buildSheetChoiceChip(
                                    label: shadow,
                                    isSelected: tempShadowFilters.contains(shadow),
                                    onTap: () {
                                      setSheetState(() {
                                        if (tempShadowFilters.contains(shadow)) {
                                          tempShadowFilters.remove(shadow);
                                        } else {
                                          tempShadowFilters.add(shadow);
                                        }
                                      });
                                    },
                                  );
                                }),
                              ]),
                            ],
                            const SizedBox(height: 18),
                            sectionTitle('지난 시즌 보기'),
                            chipWrap([
                              ...pastSeasonOptions.map((season) {
                                return _buildSheetChoiceChip(
                                  label: season,
                                  isSelected: season == '제외'
                                      ? tempPastSeasonFilters.isEmpty ||
                                      tempPastSeasonFilters.contains('제외')
                                      : tempPastSeasonFilters.contains(season),
                                  onTap: () {
                                    setSheetState(() {
                                      if (season == '제외' || season == '전체') {
                                        tempPastSeasonFilters
                                          ..clear()
                                          ..add(season);
                                      } else {
                                        tempPastSeasonFilters.remove('제외');
                                        tempPastSeasonFilters.remove('전체');
                                        if (tempPastSeasonFilters.contains(season)) {
                                          tempPastSeasonFilters.remove(season);
                                        } else {
                                          tempPastSeasonFilters.add(season);
                                        }
                                        if (tempPastSeasonFilters.isEmpty) {
                                          tempPastSeasonFilters.add('제외');
                                        }
                                      }
                                    });
                                  },
                                );
                              }),
                            ]),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                tempLevels.clear();
                                tempAchievementStars.clear();
                                tempWeatherFilters.clear();
                                tempShadowFilters.clear();
                                tempMasteryCompletionFilters.clear();
                                tempPastSeasonFilters
                                  ..clear()
                                  ..add('제외');
                                tempSort = '레벨순';
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF94A3B8),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text(
                              '초기화',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (tempPastSeasonFilters.isEmpty) {
                                tempPastSeasonFilters.add('제외');
                              }
                              setState(() {
                                _selectedLevelFilters
                                  ..clear()
                                  ..addAll(tempLevels);
                                _selectedAchievementStarFilters
                                  ..clear()
                                  ..addAll(tempAchievementStars);
                                _selectedWeatherFilters
                                  ..clear()
                                  ..addAll(tempWeatherFilters);
                                _selectedFishShadowFilters
                                  ..clear()
                                  ..addAll(tempShadowFilters);
                                _selectedMasteryCompletionFilters
                                  ..clear()
                                  ..addAll(tempMasteryCompletionFilters);
                                _selectedPastSeasonFilters
                                  ..clear()
                                  ..addAll(tempPastSeasonFilters);
                                _selectedSort = tempSort;
                              });
                              _applyFilters();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8E7C),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text(
                              '적용',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterBarArea() {
    final filters = _getCurrentFilterList();

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
          _buildFilterSortActionButton(),
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

  Widget _buildGatheringCardShell({
    required bool isHighlighted,
    required Widget child,
    VoidCallback? onTap,
  }) {
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
            onTap: onTap,
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
              child: child,
            ),
          ),
        ),
      ),
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 180),
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
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 180),
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

  Widget _buildPriceButton(List<int> prices, {int? seedCost, List<int> eventTokenPrices = const []}) {
    final validPrices = prices.where((e) => e > 0).toList();
    final validEventTokenPrices = eventTokenPrices.where((e) => e > 0).toList();

    String previewText(List<int> values, String suffix) {
      if (values.isEmpty) return '-';
      if (values.first == values.last) {
        return '${_formatPrice(values.first)}$suffix';
      }
      return '${_formatPrice(values.first)}$suffix ~ ${_formatPrice(values.last)}$suffix';
    }

    final pricePreview = validPrices.isEmpty
        ? '가격보기'
        : previewText(validPrices, '원');
    final coinPreview = validEventTokenPrices.isEmpty
        ? ''
        : previewText(validEventTokenPrices, '코인');
    final bool hasEventCoin = coinPreview.isNotEmpty;

    return GestureDetector(
      onTap: () => _showPriceBottomSheet(
        prices,
        seedCost: seedCost,
        eventTokenPrices: eventTokenPrices,
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: hasEventCoin ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF8E7C).withOpacity(0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    pricePreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2D3436),
                      height: 1.0,
                    ),
                  ),
                  if (hasEventCoin) ...[
                    const SizedBox(height: 0),
                    Text(
                      coinPreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 9.6,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF8E7C),
                        height: 1.0,
                      ),
                    ),
                  ],
                ],
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

  Widget _buildCardBottomAction(
      List<int> prices, {
        String? itemKey,
        List<int> eventTokenPrices = const [],
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _buildPriceButton(
            prices,
            eventTokenPrices: eventTokenPrices,
          ),
        ),
        if (itemKey != null) ...[
          const SizedBox(height: 0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildAchievementStars(itemKey),
                ),
              ),
              _buildCardMasteryDoneButton(itemKey),
            ],
          ),
        ],
      ],
    );
  }



  Widget _buildCardProgressRow(String itemKey) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildAchievementStars(itemKey),
          ),
        ),
        _buildCardMasteryDoneButton(itemKey),
      ],
    );
  }
  Widget _buildCardMasteryDoneButton(String itemKey) {
    final bool checked = _masteryDoneMap[itemKey] == true;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final next = !checked;
        setState(() => _masteryDoneMap[itemKey] = next);
        await _saveMasteryDoneValue(itemKey, next);
        if (!mounted) return;
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked
              ? const Color(0xFFFFF4CF)
              : const Color(0xFFFCF9FF),
          border: Border.all(
            color: checked
                ? const Color(0xFFD8B4FE)
                : const Color(0xFFF0E4FF),
            width: 1.15,
          ),
          boxShadow: [
            BoxShadow(
              color: (checked ? const Color(0xFFFBBF24) : const Color(0xFFD8B4FE))
                  .withOpacity(checked ? 0.16 : 0.05),
              blurRadius: checked ? 8 : 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          checked
              ? Icons.workspace_premium_rounded
              : Icons.workspace_premium_outlined,
          size: 19,
          color: checked
              ? const Color(0xFFF59E0B)
              : const Color(0xFFD8B4FE),
        ),
      ),
    );
  }

  Widget _buildCardFavoriteButton(String itemId, bool isFavorite) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleFavorite(itemId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isFavorite
              ? const Color(0xFFFFEEF4)
              : const Color(0xFFFFFBFC),
          border: Border.all(
            color: isFavorite
                ? const Color(0xFFFFBFD0)
                : const Color(0xFFFFE6EE),
            width: 1.15,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFA6BA).withOpacity(isFavorite ? 0.14 : 0.05),
              blurRadius: isFavorite ? 7 : 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 19,
          color: isFavorite
              ? const Color(0xFFFF7F9F)
              : const Color(0xFFFFC7D6),
        ),
      ),
    );
  }

  Widget _buildInsectCard(InsectItem insect) {
    final bool isHighlighted = _highlightedId == insect.id;
    final timeChip = _normalizeInsectTimeLabel(insect.availableTime);
    final locationChip = insect.location.trim();
    final levelColors = _levelChipColors(insect.level);
    final timeColors = _timeChipColors(timeChip);
    final bool showMastery = !_isEventOrPastSeasonItem(
      eventTokenPrices: insect.eventTokenPrices,
      seasonTag: insect.seasonTag,
      textValues: [insect.id, insect.name, insect.nameKo, insect.image, insect.location],
    );

    return _buildGatheringCardShell(
      isHighlighted: isHighlighted,
      onTap: () => _openInsectDetail(insect),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardImage(
                  insect.image,
                  Icons.bug_report,
                  previewTitle: _displayInsectName(insect),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 106),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardTitle(_displayInsectName(insect), insect.id),
                        const SizedBox(height: 0),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  _buildBaseChip(
                                    'Lv.${insect.level}',
                                    bg: levelColors['bg']!,
                                    border: levelColors['border']!,
                                    textColor: levelColors['text']!,
                                  ),
                                  if (timeChip.isNotEmpty)
                                    _buildBaseChip(
                                      timeChip,
                                      bg: timeColors['bg']!,
                                      border: timeColors['border']!,
                                      textColor: timeColors['text']!,
                                    ),
                                  if (locationChip.isNotEmpty)
                                    _buildLocationTag(locationChip),
                                ],
                              ),
                            ),
                            if (showMastery) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildCardMasteryDoneButton('insect:${insect.id}'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 0),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: 5,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _buildAchievementStars('insect:${insect.id}'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 7,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildPriceButton(
                      insect.prices,
                      eventTokenPrices: insect.eventTokenPrices,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPlantCard(PlantItem plant) {
    final bool isHighlighted = _highlightedId == plant.id;
    final levelColors = _levelChipColors(plant.level);
    final bool showMastery = !_isEventOrPastSeasonItem(
      eventTokenPrices: plant.eventTokenPrices,
      seasonTag: plant.seasonTag,
      textValues: [plant.id, plant.name, plant.nameKo, plant.image, plant.location],
    );

    return _buildGatheringCardShell(
      isHighlighted: isHighlighted,
      onTap: () => _openFlowerDetail(plant),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showAssetImagePreview(
                    title: _displayPlantName(plant),
                    image: plant.image,
                    fallbackIcon: Icons.local_florist_rounded,
                  ),
                  child: Container(
                    width: 106,
                    height: 106,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFAF8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF8E7C).withOpacity(0.15),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          _imageAssetPath(plant.image),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_florist_rounded,
                            color: Colors.grey,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 106),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardTitle(_displayPlantName(plant), plant.id),
                        const SizedBox(height: 0),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  _buildBaseChip(
                                    'Lv.${plant.level}',
                                    bg: levelColors['bg']!,
                                    border: levelColors['border']!,
                                    textColor: levelColors['text']!,
                                  ),
                                  if (plant.growthTime.trim().isNotEmpty && plant.growthTime.trim() != '-')
                                    _buildGrowthTimeTag(plant.growthTime.trim()),
                                ],
                              ),
                            ),
                            if (showMastery) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildCardMasteryDoneButton('plant:${plant.id}'),
                              ),
                            ],
                          ],
                        ),
                        if (plant.flowerColorSummaries.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 28,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: plant.flowerColorSummaries
                                    .map((color) => _buildFlowerColorSummaryBox(color))
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 0),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: 5,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _buildAchievementStars('plant:${plant.id}'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 7,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildPriceButton(
                      plant.prices,
                      eventTokenPrices: plant.eventTokenPrices,
                    ),
                  ),
                ),
              ],
            ),
          ],
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

    final timeChip = _formatAvailableTimeChip(fish.availableTime);
    final weatherLabels = _normalizeWeatherLabel(fish.weather);
    final locationChip = fish.location.trim();
    final timeColors = _timeChipColors(timeChip);
    final bool showMastery = !_isEventOrPastSeasonItem(
      eventTokenPrices: fish.eventTokenPrices,
      seasonTag: fish.seasonTag,
      textValues: [fish.id, fish.name, fish.nameKo, fish.image, fish.location],
    );

    return _buildGatheringCardShell(
      isHighlighted: isHighlighted,
      onTap: () => _openFishDetail(fish),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardImage(
                  fish.image,
                  Icons.set_meal_rounded,
                  previewTitle: _displayName(fish),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 106),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardTitle(_displayName(fish), fish.id),
                        const SizedBox(height: 0),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  if (fish.level != null)
                                    _buildBaseChip(
                                      'Lv.${fish.level}',
                                      bg: _levelChipColors(fish.level!)['bg']!,
                                      border: _levelChipColors(fish.level!)['border']!,
                                      textColor: _levelChipColors(fish.level!)['text']!,
                                    ),
                                  if (timeChip.isNotEmpty)
                                    _buildBaseChip(
                                      timeChip,
                                      bg: timeColors['bg']!,
                                      border: timeColors['border']!,
                                      textColor: timeColors['text']!,
                                    ),
                                  if (locationChip.isNotEmpty)
                                    _buildLocationTag(locationChip),
                                  ...weatherLabels.map((label) {
                                    Color bg = const Color(0xFFF0F7FF);
                                    Color border = const Color(0xFFD9E9FF);
                                    Color textColor = const Color(0xFF5B88C7);

                                    switch (label) {
                                      case '맑음':
                                        bg = const Color(0xFFFFF7D6);
                                        border = const Color(0xFFFFE6A3);
                                        textColor = const Color(0xFFB7791F);
                                        break;
                                      case '비':
                                        bg = const Color(0xFFEAF3FF);
                                        border = const Color(0xFFD4E4FF);
                                        textColor = const Color(0xFF4A67A1);
                                        break;
                                      case '눈':
                                        bg = const Color(0xFFF3F4F6);
                                        border = const Color(0xFFE5E7EB);
                                        textColor = const Color(0xFF6B7280);
                                        break;
                                      case '무지개':
                                        bg = const Color(0xFFFFF0FA);
                                        border = const Color(0xFFF6D6EC);
                                        textColor = const Color(0xFFC05A9D);
                                        break;
                                      case '흐림':
                                        bg = const Color(0xFFF3F4F6);
                                        border = const Color(0xFFE5E7EB);
                                        textColor = const Color(0xFF6B7280);
                                        break;
                                    }

                                    return _buildBaseChip(
                                      label,
                                      bg: bg,
                                      border: border,
                                      textColor: textColor,
                                    );
                                  }),
                                ],
                              ),
                            ),
                            if (showMastery) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildCardMasteryDoneButton('fish:${fish.id}'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 0),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: 5,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _buildAchievementStars('fish:${fish.id}'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 7,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildPriceButton(
                      fishPrices,
                      eventTokenPrices: fish.eventTokenPrices,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBaseChip(
      String text, {
        Color bg = const Color(0xFFF4F6F8),
        Color border = const Color(0xFFE5E7EB),
        Color textColor = const Color(0xFF6B7280),
      }) {
    final int? level = (text.contains('레벨') || text.startsWith('Lv.'))
        ? int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''))
        : null;
    final bool isRainbowLevel = level != null && level >= 11;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: isRainbowLevel
            ? const LinearGradient(
          colors: [
            Color(0xFFFFD1D1),
            Color(0xFFFFF4D1),
            Color(0xFFD1FFDA),
            Color(0xFFD1E3FF),
            Color(0xFFE5D1FF),
          ],
        )
            : null,
        color: isRainbowLevel ? null : bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRainbowLevel ? const Color(0xFFE7D8FF) : border,
          width: 0.8,
        ),
      ),
      child: Transform.translate(
        offset: const Offset(0, -0.5),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9.5,
            height: 1.0,
            fontWeight: isRainbowLevel ? FontWeight.w800 : FontWeight.w600,
            color: isRainbowLevel ? const Color(0xFF424242) : textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildBirdCard(BirdItem bird) {
    final bool isHighlighted = _highlightedId == bird.id;
    final timeChip = _formatAvailableTimeChip(
      bird.timeKey.isNotEmpty ? bird.timeKey : bird.availableTime,
    );
    final locationChip = bird.location.trim();
    final weatherLabels = _normalizeWeatherLabel(bird.weather);
    final timeColors = _timeChipColors(timeChip);
    final bool showMastery = !_isEventOrPastSeasonItem(
      eventTokenPrices: bird.eventTokenPrices,
      seasonTag: bird.seasonTag,
      textValues: [bird.id, bird.name, bird.nameKo, bird.image, bird.location],
    );

    return _buildGatheringCardShell(
      isHighlighted: isHighlighted,
      onTap: () => _openBirdDetail(bird),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardImage(
                  bird.image,
                  Icons.flutter_dash_rounded,
                  previewTitle: _displayBirdName(bird),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 106),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardTitle(_displayBirdName(bird), bird.id),
                        const SizedBox(height: 0),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  _buildBaseChip(
                                    'Lv.${bird.level}',
                                    bg: _levelChipColors(bird.level)['bg']!,
                                    border: _levelChipColors(bird.level)['border']!,
                                    textColor: _levelChipColors(bird.level)['text']!,
                                  ),
                                  if (timeChip.isNotEmpty)
                                    _buildBaseChip(
                                      timeChip,
                                      bg: timeColors['bg']!,
                                      border: timeColors['border']!,
                                      textColor: timeColors['text']!,
                                    ),
                                  if (locationChip.isNotEmpty)
                                    _buildLocationTag(locationChip),
                                  ...weatherLabels.map((label) {
                                    Color bg = const Color(0xFFF0F7FF);
                                    Color border = const Color(0xFFD9E9FF);
                                    Color textColor = const Color(0xFF5B88C7);
                                    switch (label) {
                                      case '맑음':
                                        bg = const Color(0xFFFFF7D6);
                                        border = const Color(0xFFFFE6A3);
                                        textColor = const Color(0xFFB7791F);
                                        break;
                                      case '비':
                                        bg = const Color(0xFFEAF3FF);
                                        border = const Color(0xFFD4E4FF);
                                        textColor = const Color(0xFF4A67A1);
                                        break;
                                      case '눈':
                                        bg = const Color(0xFFF3F4F6);
                                        border = const Color(0xFFE5E7EB);
                                        textColor = const Color(0xFF6B7280);
                                        break;
                                      case '무지개':
                                        bg = const Color(0xFFFFF0FA);
                                        border = const Color(0xFFF6D6EC);
                                        textColor = const Color(0xFFC05A9D);
                                        break;
                                      case '흐림':
                                        bg = const Color(0xFFF3F4F6);
                                        border = const Color(0xFFE5E7EB);
                                        textColor = const Color(0xFF6B7280);
                                        break;
                                    }
                                    return _buildBaseChip(label, bg: bg, border: border, textColor: textColor);
                                  }),
                                ],
                              ),
                            ),
                            if (showMastery) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildCardMasteryDoneButton('bird:${bird.id}'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 0),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: 5,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _buildAchievementStars('bird:${bird.id}'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 7,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildPriceButton(
                      bird.prices,
                      eventTokenPrices: bird.eventTokenPrices,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
  Widget _buildCardImage(
      String image,
      IconData fallbackIcon, {
        String? previewTitle,
      }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: previewTitle == null
          ? null
          : () => _showAssetImagePreview(
        title: previewTitle,
        image: image,
        fallbackIcon: fallbackIcon,
      ),
      child: Container(
        width: 106,
        height: 106,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF8E7C).withOpacity(0.15),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Image.asset(
                _imageAssetPath(image),
                fit: BoxFit.contain,
                alignment: Alignment.center,
                errorBuilder: (c, e, s) => Icon(
                  fallbackIcon,
                  color: Colors.grey,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardTitle(
      String text,
      String itemId, {
        String? masteryItemKey,
      }) {
    final isFavorite = _favoriteIds.contains(itemId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AutoSizeText(
              text,
              style: const TextStyle(
                fontSize: 15.2,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
                height: 1.15,
              ),
              maxLines: 2,
              minFontSize: 8,
              stepGranularity: 0.5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildCardFavoriteButton(itemId, isFavorite),
      ],
    );
  }

  void _showAssetImagePreview({
    required String title,
    required String image,
    required IconData fallbackIcon,
  }) {
    final String imagePath = _imageAssetPath(image);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'preview',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            fallbackIcon,
                            color: Colors.white.withOpacity(0.85),
                            size: 72,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 82,
                        right: 82,
                        bottom: -48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.22),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.2,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2D3436),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
    );
  }

  // 2. 칩 위젯 생성 함수 (장소 색상 추가 및 쏠림 해결)
  Widget _buildSmallTag(
      String text, {
        bool isLocation = false,
        bool isWeather = false,
        bool isTime = false,
      }) {
    final String rawText = text.trim();
    if (rawText.isEmpty) return const SizedBox.shrink();

    Color bg = const Color(0xFFF5F5F5);
    Color border = const Color(0xFFE0E0E0);
    Color textColor = const Color(0xFF757575);

    if (rawText.contains('레벨')) {
      final level = int.tryParse(rawText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

      if (level == 1) {
        bg = const Color(0xFFEEEEEE);
        border = const Color(0xFFBDBDBD);
        textColor = const Color(0xFF616161);
      } else if (level == 2) {
        bg = const Color(0xFFFFEBEE);
        border = const Color(0xFFFFCDD2);
        textColor = const Color(0xFFC62828);
      } else if (level == 3) {
        bg = const Color(0xFFFFF3E0);
        border = const Color(0xFFFFE0B2);
        textColor = const Color(0xFFE65100);
      } else if (level == 4) {
        bg = const Color(0xFFFFFDE7);
        border = const Color(0xFFFFF9C4);
        textColor = const Color(0xFFF57F17);
      } else if (level == 5) {
        bg = const Color(0xFFE8F5E9);
        border = const Color(0xFFC8E6C9);
        textColor = const Color(0xFF2E7D32);
      } else if (level == 6) {
        bg = const Color(0xFFE1F5FE);
        border = const Color(0xFFB3E5FC);
        textColor = const Color(0xFF0277BD);
      } else if (level == 7) {
        bg = const Color(0xFFE8EAF6);
        border = const Color(0xFFC5CAE9);
        textColor = const Color(0xFF3949AB);
      } else if (level == 8) {
        bg = const Color(0xFFF3E5F5);
        border = const Color(0xFFE1BEE7);
        textColor = const Color(0xFF8E24AA);
      } else if (level == 9) {
        bg = const Color(0xFFFCE4EC);
        border = const Color(0xFFF8BBD0);
        textColor = const Color(0xFFC2185B);
      } else {
        bg = const Color(0xFFF3F4F6);
        border = const Color(0xFFD1D5DB);
        textColor = const Color(0xFF4B5563);
      }
    } else if (isWeather) {
      switch (rawText) {
        case '맑음':
          bg = const Color(0xFFFFF7D6);
          border = const Color(0xFFFFE6A3);
          textColor = const Color(0xFFB7791F);
          break;
        case '흐림':
          bg = const Color(0xFFF1F5F9);
          border = const Color(0xFFDCE5EE);
          textColor = const Color(0xFF64748B);
          break;
        case '비':
          bg = const Color(0xFFEAF4FF);
          border = const Color(0xFFCFE4FF);
          textColor = const Color(0xFF4A7FD1);
          break;
        case '눈':
          bg = const Color(0xFFEFF8FF);
          border = const Color(0xFFD6EEFF);
          textColor = const Color(0xFF3B82C4);
          break;
        case '무지개':
          bg = const Color(0xFFF4ECFF);
          border = const Color(0xFFE2D3FF);
          textColor = const Color(0xFF8B5CF6);
          break;
      }
    } else if (isLocation) {
      final label = rawText;

      switch (label) {
        case '대나무 숲':
          bg = const Color(0xFFF1FBEA);
          border = const Color(0xFFD9F0C8);
          textColor = const Color(0xFF7CB342);
          break;
        case '참나무 숲':
          bg = const Color(0xFFE6F6EA);
          border = const Color(0xFFC7E7CF);
          textColor = const Color(0xFF2F855A);
          break;
        case '숲':
          bg = const Color(0xFFEAF7EE);
          border = const Color(0xFFCFE8D7);
          textColor = const Color(0xFF3D8B5C);
          break;
        case '호숫가':
          bg = const Color(0xFFEEF9FF);
          border = const Color(0xFFD7EEFF);
          textColor = const Color(0xFF2B7FB8);
          break;
        case '호수':
          bg = const Color(0xFFEAF7FF);
          border = const Color(0xFFCFEAFF);
          textColor = const Color(0xFF2F89C5);
          break;
        case '강':
          bg = const Color(0xFFE8F7FF);
          border = const Color(0xFFCAE9F7);
          textColor = const Color(0xFF1F7A8C);
          break;
        case '바다':
          bg = const Color(0xFFEAF1FF);
          border = const Color(0xFFCDDBFF);
          textColor = const Color(0xFF3366CC);
          break;
        case '해변':
          bg = const Color(0xFFEAF2FF);
          border = const Color(0xFFD5E2FF);
          textColor = const Color(0xFF3B6FD8);
          break;
        case '보라 해변':
          bg = const Color(0xFFF3ECFF);
          border = const Color(0xFFE2D4FF);
          textColor = const Color(0xFF8B5CF6);
          break;
        case '고래 해변':
          bg = const Color(0xFFEAF6FF);
          border = const Color(0xFFCEE8FF);
          textColor = const Color(0xFF3B82C4);
          break;
        case '어촌':
          bg = const Color(0xFFEAF8FF);
          border = const Color(0xFFD3ECFF);
          textColor = const Color(0xFF3C8DBB);
          break;
        case '어촌 등대':
          bg = const Color(0xFFEFF8FF);
          border = const Color(0xFFD8EEFF);
          textColor = const Color(0xFF4A90B8);
          break;
        case '어촌 부두':
          bg = const Color(0xFFE8F4FF);
          border = const Color(0xFFCCE1FF);
          textColor = const Color(0xFF357ABD);
          break;
        case '어촌 광장':
          bg = const Color(0xFFF0F8FF);
          border = const Color(0xFFDCEEFF);
          textColor = const Color(0xFF5A8FB3);
          break;
        case '도심':
          bg = const Color(0xFFF3ECFF);
          border = const Color(0xFFE3D3FF);
          textColor = const Color(0xFF8B5CF6);
          break;
        case '도시 근교':
          bg = const Color(0xFFF1EEFF);
          border = const Color(0xFFDDD6FF);
          textColor = const Color(0xFF7C6AE6);
          break;
        case '도시':
          bg = const Color(0xFFF4F0FF);
          border = const Color(0xFFE4DCFF);
          textColor = const Color(0xFF8A63D2);
          break;
        case '주거지':
        case '집 앞':
          bg = const Color(0xFFFFF1E5);
          border = const Color(0xFFFFD9BC);
          textColor = const Color(0xFFE67E22);
          break;
        case '꽃밭':
          bg = const Color(0xFFFFEFF7);
          border = const Color(0xFFF9D3E7);
          textColor = const Color(0xFFD45A9B);
          break;
        case '온천산':
          bg = const Color(0xFFFFF4E8);
          border = const Color(0xFFFFDFC2);
          textColor = const Color(0xFFCC7A00);
          break;
        case '이벤트':
          bg = const Color(0xFFFFF4F4);
          border = const Color(0xFFFFD7D7);
          textColor = const Color(0xFFD65A5A);
          break;
        case '특수':
        case '유인':
          bg = const Color(0xFFF5F5F7);
          border = const Color(0xFFE1E4E8);
          textColor = const Color(0xFF6B7280);
          break;
        case '들판':
          bg = const Color(0xFFFFF8E8);
          border = const Color(0xFFFFE8BF);
          textColor = const Color(0xFFB7791F);
          break;
      }
    } else if (isTime) {
      final colors = _timeChipColors(rawText);
      bg = colors['bg']!;
      border = colors['border']!;
      textColor = colors['text']!;
    }

    final int? levelValue = rawText.contains('레벨')
        ? int.tryParse(rawText.replaceAll(RegExp(r'[^0-9]'), ''))
        : null;
    final bool isRainbowLevel = levelValue != null && levelValue >= 11;

    final String displayText = isLocation
        ? rawText
        : rawText;

    if (displayText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: isRainbowLevel
            ? const LinearGradient(
          colors: [
            Color(0xFFFFD1D1),
            Color(0xFFFFF4D1),
            Color(0xFFD1FFDA),
            Color(0xFFD1E3FF),
            Color(0xFFE5D1FF),
          ],
        )
            : null,
        color: isRainbowLevel ? null : bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRainbowLevel ? const Color(0xFFE7D8FF) : border,
          width: 0.8,
        ),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 10,
          height: 1.0,
          fontWeight: isRainbowLevel ? FontWeight.w800 : FontWeight.w700,
          color: isRainbowLevel ? const Color(0xFF424242) : textColor,
        ),
      ),
    );
  }

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
        onTap: _resetTabScopedFiltersIfNeeded,
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
          Tab(text: '낚시'),
          Tab(text: '새 관찰'),
          Tab(text: '곤충채집'),
          Tab(text: '꽃'),
        ],
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
          width: 40, // 🔥 40 → 34
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
            width: 17, // 🔥 20 → 17
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

  Widget _buildAppTitle() {
    return const Text(
      '채집',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2D3436),
        letterSpacing: -0.2,
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
              ? '물고기 이름을 검색해보세요.'
              : _tabController.index == 1
              ? '새 이름을 검색해보세요.'
              : _tabController.index == 2
              ? '곤충 이름을 검색해보세요.'
              : '꽃 이름을 검색해보세요.',
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
              size: 18,
            ),
            onPressed: () {
              _searchController.clear();
              _dismissKeyboard();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 13,
          ),
        ),
        onTapOutside: (_) => _dismissKeyboard(),
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

  void _showPriceBottomSheet(List<int> prices, {int? seedCost, List<int> eventTokenPrices = const []}) {
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

    final visibleEventTokenPrices = <Map<String, dynamic>>[];
    for (int i = 0; i < eventTokenPrices.length; i++) {
      if (eventTokenPrices[i] > 0) {
        visibleEventTokenPrices.add({
          'star': i + 1,
          'price': eventTokenPrices[i],
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                      height: 28,
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
                if (visiblePrices.isEmpty && visibleEventTokenPrices.isEmpty && (seedCost == null || seedCost <= 0))
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
                  Column(
                    children: [
                      if (seedCost != null && seedCost > 0)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
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
                                  color: const Color(0xFFFFE7CC),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '구매가',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF8A4B08),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_formatPrice(seedCost)}원',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2D3436),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                      if (visibleEventTokenPrices.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '이벤트 코인 판매가',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF7A65),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...visibleEventTokenPrices.map((item) {
                          final int star = item['star'] as int;
                          final int price = item['price'] as int;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
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
                                  '${_formatPrice(price)}코인',
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
                    ],
                  ),
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

class GatheringSimpleDetailPage extends StatelessWidget {
  final String title;
  final String categoryLabel;
  final String levelLabel;
  final String image;
  final IconData fallbackIcon;
  final List<int> prices;
  final String timeText;
  final String locationText;
  final String weatherText;
  final List<Map<String, String>> appearanceInfo;
  final List<Map<String, String>> extraInfo;
  final List<int> eventTokenPrices;
  final String? masteryDoneKey;
  final String? achievementStarKey;
  final String masteryDoneLabel;

  const GatheringSimpleDetailPage({
    super.key,
    required this.title,
    required this.categoryLabel,
    required this.levelLabel,
    required this.image,
    required this.fallbackIcon,
    required this.prices,
    required this.timeText,
    required this.locationText,
    required this.weatherText,
    this.appearanceInfo = const [],
    this.extraInfo = const [],
    this.eventTokenPrices = const [],
    this.masteryDoneKey,
    this.achievementStarKey,
    this.masteryDoneLabel = '명인 달성',
  });

  Color _masteryStageIconColor(String label) {
    if (label.contains('초보자')) return const Color(0xFF94A3B8);
    if (label.contains('입문자')) return const Color(0xFF60A5FA);
    if (label.contains('숙련자')) return const Color(0xFFFBBF24);
    if (label.contains('명인')) return const Color(0xFFA855F7);
    return const Color(0xFFFF8E7C);
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
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

  Color _starBadgeColor(int star) {
    switch (star) {
      case 1:
        return const Color(0xFFF3F4F6);
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

  Color _infoIconColor(String label) {
    if (label.contains('초보자')) return const Color(0xFF94A3B8); // 은색
    if (label.contains('입문자')) return const Color(0xFF60A5FA); // 파란색
    if (label.contains('숙련자')) return const Color(0xFFFBBF24); // 노란색
    if (label.contains('명인')) return const Color(0xFFA855F7); // 보라색
    return const Color(0xFFFF8E7C);
  }

  IconData _infoIcon(String label) {
    if (label.contains('낚시')) return Icons.set_meal_rounded;
    if (label.contains('촬영')) return Icons.camera_alt_rounded;
    if (label.contains('곤충 채집')) return Icons.bug_report_rounded;
    if (label.contains('농사') || label.contains('원예') || label.contains('재배')) return Icons.agriculture_rounded;
    switch (label) {
      case '출현 시간':
        return Icons.schedule_rounded;
      case '출현 장소':
        return Icons.place_rounded;
      case '날씨':
        return Icons.wb_cloudy_rounded;
      case '낚시 명인':
        return Icons.set_meal_rounded;
      case '촬영 명인':
        return Icons.camera_alt_rounded;
      case '곤충 채집 명인':
        return Icons.bug_report_rounded;
      case '원예 명인':
      case '재배 명인':
        return Icons.agriculture_rounded;
      case '그림자 크기':
        return Icons.waves_rounded;
      case '포착 거리':
        return Icons.social_distance_rounded;
      case '날개 펴기':
      case '날개 펴기 시간':
        return Icons.open_in_full_rounded;
      case '호루라기':
      case '호루라기 시간':
        return Icons.volume_up_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Widget _infoTile(String label, String value) {
    final display = value.trim().isEmpty ? '-' : value.trim();

    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFFFE2DB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.022),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _infoIcon(label),
            size: 16,
            color: _infoIconColor(label),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            display,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D3436),
              height: 1.12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: Color(0xFF2D3436),
          height: 1.0,
        ),
      ),
    );
  }

  Widget _priceTile(int star, int price, {String suffix = '원'}) {
    final priceText = price > 0 ? '${_formatPrice(price)}$suffix' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE2DB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _starBadgeColor(star),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$star성',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3F3F46),
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 1),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                priceText,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D3436),
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _imageAssetPath(image);
    final visiblePrices = List<Map<String, int>>.generate(
      5,
          (index) => {
        'star': index + 1,
        'price': index < prices.length ? prices[index] : 0,
      },
    );
    final bool hasPrice = prices.any((price) => price > 0);
    final visibleEventTokenPrices = List<Map<String, int>>.generate(
      5,
          (index) => {
        'star': index + 1,
        'price': index < eventTokenPrices.length ? eventTokenPrices[index] : 0,
      },
    );
    final bool hasEventTokenPrice = eventTokenPrices.any((price) => price > 0);
    final occurrenceInfo = <Map<String, String>>[
      {'label': '출현 시간', 'value': timeText},
      {'label': '날씨', 'value': weatherText},
      {'label': '출현 장소', 'value': locationText},
      if (appearanceInfo.length == 1) appearanceInfo.first,
    ];
    final blockAppearanceInfo =
    appearanceInfo.length == 1 ? const <Map<String, String>>[] : appearanceInfo;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFA),
      appBar: _keepersDetailGlassAppBar(
        context,
        title: title,
        subtitle: '$categoryLabel · $levelLabel',
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFFFE2DB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.045),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    if (masteryDoneKey != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _buildDetailMasteryDoneButton(
                          itemKey: masteryDoneKey!,
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFAF8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFFF8E7C).withOpacity(0.15),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Image.asset(
                              imagePath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                fallbackIcon,
                                size: 72,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        if (achievementStarKey != null) ...[
                          const SizedBox(height: 10),
                          _buildDetailAchievementStars(
                            itemKey: achievementStarKey!,
                          ),
                        ],
                        const SizedBox(height: 15),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D3436),
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3EE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$categoryLabel · $levelLabel',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF7A65),
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('출현 정보'),
              const SizedBox(height: 10),
              SizedBox(
                height: 76,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int index = 0; index < occurrenceInfo.length; index++) ...[
                      if (index > 0) const SizedBox(width: 7),
                      Expanded(
                        child: _infoTile(
                          occurrenceInfo[index]['label'] ?? '-',
                          occurrenceInfo[index]['value'] ?? '-',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (blockAppearanceInfo.isNotEmpty) ...[
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: blockAppearanceInfo.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 7,
                    mainAxisSpacing: 7,
                    childAspectRatio: 2.35,
                  ),
                  itemBuilder: (context, index) {
                    final info = blockAppearanceInfo[index];
                    return _infoTile(info['label'] ?? '-', info['value'] ?? '-');
                  },
                ),
              ],
              if (extraInfo.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionTitle('명인 달성 기준'),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: extraInfo.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 7,
                    mainAxisSpacing: 7,
                    childAspectRatio: 2.35,
                  ),
                  itemBuilder: (context, index) {
                    final info = extraInfo[index];
                    return _infoTile(info['label'] ?? '-', info['value'] ?? '-');
                  },
                ),
              ],

              const SizedBox(height: 20),
              _sectionTitle('성급별 판매가'),
              const SizedBox(height: 10),
              if (!hasPrice)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFE2DB)),
                  ),
                  child: const Center(
                    child: Text(
                      '등록된 판매가가 없어요.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visiblePrices.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    final item = visiblePrices[index];
                    return _priceTile(item['star']!, item['price']!, suffix: '원');
                  },
                ),
              if (hasEventTokenPrice) ...[
                const SizedBox(height: 20),
                _sectionTitle('이벤트 코인 판매가'),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleEventTokenPrices.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    final item = visibleEventTokenPrices[index];
                    return _priceTile(item['star']!, item['price']!, suffix: '코인');
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FlowerDetailPage extends StatelessWidget {
  final FlowerDetail detail;

  const FlowerDetailPage({
    super.key,
    required this.detail,
  });

  String _formatPrice(int? price) {
    if (price == null) return '';
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  Color _growthTimeChipColor(String raw) {
    final value = raw.replaceAll(' ', '');

    if (value.contains('18시간')) return const Color(0xFFE8F7E8);
    if (value.contains('1일6시간')) return const Color(0xFFFFF1E0);
    if (value.contains('1일')) return const Color(0xFFEAF4FF);
    if (value.contains('2일')) return const Color(0xFFF3ECFF);
    if (value.contains('3일')) return const Color(0xFFFFE7EF);
    return const Color(0xFFF4F6F8);
  }

  Color _growthTimeChipTextColor(String raw) {
    final value = raw.replaceAll(' ', '');

    if (value.contains('18시간')) return const Color(0xFF4E9B57);
    if (value.contains('1일6시간')) return const Color(0xFFCC7A00);
    if (value.contains('1일')) return const Color(0xFF4A7FD1);
    if (value.contains('2일')) return const Color(0xFF7A5BC1);
    if (value.contains('3일')) return const Color(0xFFD35B87);
    return const Color(0xFF6B7280);
  }

  Color _masteryStageIconColor(String label) {
    if (label.contains('초보자')) return const Color(0xFF94A3B8); // 은색
    if (label.contains('입문자')) return const Color(0xFF60A5FA); // 파란색
    if (label.contains('숙련자')) return const Color(0xFFFBBF24); // 노란색
    if (label.contains('명인')) return const Color(0xFFA855F7); // 보라색
    return const Color(0xFFFF8E7C);
  }

  Color _getStarBadgeColor(int star) {
    switch (star) {
      case 1:
        return const Color(0xFFF3F4F6);
      case 2:
        return const Color(0xFFDDF7E8);
      case 3:
        return const Color(0xFFE3F2FD);
      case 4:
        return const Color(0xFFF3E8FF);
      case 5:
        return const Color(0xFFFFF1C7);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Widget _priceTile(int star, int price, {String suffix = '원'}) {
    final priceText = price > 0 ? '${_formatPrice(price)}$suffix' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE2DB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _getStarBadgeColor(star),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$star성',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3F3F46),
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              priceText,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2D3436),
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = detail.image.startsWith('assets/')
        ? detail.image
        : 'assets/${detail.image}';
    final visibleEventTokenPrices = List<Map<String, int>>.generate(
      5,
          (index) => {
        'star': index + 1,
        'price': index < detail.eventTokenPrices.length ? detail.eventTokenPrices[index] : 0,
      },
    );
    final bool hasEventTokenPrice = detail.eventTokenPrices.any((price) => price > 0);
    final bool hasFlowerMastery = !_isEventOrPastSeasonItem(
      eventTokenPrices: detail.eventTokenPrices,
      seasonTag: detail.seasonTag,
      textValues: [detail.id, detail.nameKo, detail.image, detail.growthTime],
    ) &&
        (detail.masteryCount > 0 ||
            detail.masteryEntryCount > 0 ||
            detail.masterySkilledCount > 0 ||
            detail.masteryMasterCount > 0);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF8),
      appBar: _keepersDetailGlassAppBar(
        context,
        title: detail.nameKo,
        subtitle: '꽃 · 원예 ${detail.level}레벨',
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          physics: const BouncingScrollPhysics(),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92), // ✅ 카드 배경 통일
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFFF8E7C).withOpacity(0.12), // ✅ 테두리 통일
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  if (hasFlowerMastery)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _buildDetailMasteryDoneButton(
                        itemKey: 'plant:${detail.id}',
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFAF8),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFFF8E7C).withOpacity(0.15),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Image.asset(
                            imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.local_florist_rounded,
                              size: 72,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildDetailAchievementStars(
                        itemKey: 'plant:${detail.id}',
                      ),
                      const SizedBox(height: 15),
                      Text(
                        detail.nameKo,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2D3436),
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '꽃 · 원예 ${detail.level}레벨',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7B8794),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (detail.growthTime.isNotEmpty)
                            _detailMetaChip(
                              detail.growthTime,
                              bg: _growthTimeChipColor(detail.growthTime),
                              fg: _growthTimeChipTextColor(detail.growthTime),
                            ),
                          _detailMetaChip(
                            '씨앗 ${_formatPrice(detail.seedCost)}원',
                            bg: const Color(0xFFFFF3F0),
                            fg: const Color(0xFFFF7A65),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasFlowerMastery) ...[
              const SizedBox(height: 20),
              const Text(
                '재배 단계',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 10),
              ..._buildMasteryStageExtraInfo('재배', detail.masteryCount, entryCount: detail.masteryEntryCount, skilledCount: detail.masterySkilledCount, exactMasterCount: detail.masteryMasterCount, unit: '회').map((stage) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFFE2DB)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 18,
                        color: _masteryStageIconColor(stage['label'] ?? ''),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          stage['label'] ?? '재배',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF7A65),
                          ),
                        ),
                      ),
                      Text(
                        stage['value'] ?? '-',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (hasEventTokenPrice) ...[
              const SizedBox(height: 20),
              const Text(
                '이벤트 코인 판매가',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visibleEventTokenPrices.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final item = visibleEventTokenPrices[index];
                  return _priceTile(item['star']!, item['price']!, suffix: '코인');
                },
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              '꽃 색 종류',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: detail.flowerColors.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final color = detail.flowerColors[index];
                final colorPath = color.image.isNotEmpty
                    ? (color.image.startsWith('assets/')
                    ? color.image
                    : 'assets/${color.image}')
                    : '';

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4C7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFE08A)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.82),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: colorPath.isNotEmpty
                                ? Image.asset(
                              colorPath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.local_florist_rounded,
                                size: 18,
                                color: Colors.grey,
                              ),
                            )
                                : const Icon(
                              Icons.local_florist_rounded,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        color.colorNameKo,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4B5563),
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              '배합식',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 10),
            ...detail.breedingRules.map((rule) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFE2DB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rule.parentColorAKo} + ${rule.parentColorBKo} = ${rule.resultColorKo}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    if (rule.isCatalogOnly || rule.isFinalStep) ...[
                      const SizedBox(height: 0),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (rule.isCatalogOnly)
                            _detailMetaChip(
                              '도감작',
                              bg: const Color(0xFFFFF3F0),
                              fg: const Color(0xFFFF7A65),
                            ),
                          if (rule.isFinalStep)
                            _detailMetaChip(
                              '종결 배합',
                              bg: const Color(0xFFEFF6FF),
                              fg: const Color(0xFF3B82F6),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  static Widget _detailMetaChip(
      String text, {
        required Color bg,
        required Color fg,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: fg,
          height: 1.0,
        ),
      ),
    );
  }
}

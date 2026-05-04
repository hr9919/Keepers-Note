import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'services/crop_timer_live_activity_service.dart';
import 'services/crop_timer_notification_service.dart';

const Map<String, int> _cropMinutesById = {
  'tomato': 15,
  'potato': 60,
  'wheat': 240,
  'lettuce': 480,
  'pineapple': 30,
  'carrot': 120,
  'strawberry': 360,
  'corn': 720,
  'grape': 600,
  'eggplant': 420,
};

const Map<String, int> _cropMinutesByName = {
  '토마토': 15,
  '감자': 60,
  '밀': 240,
  '상추': 480,
  '파인애플': 30,
  '당근': 120,
  '딸기': 360,
  '옥수수': 720,
  '포도': 600,
  '가지': 420,
};

const Map<String, int> _cropSortOrder = {
  'tomato': 1,
  'pineapple': 2,
  'potato': 3,
  'carrot': 4,
  'wheat': 5,
  'strawberry': 6,
  'eggplant': 7,
  'lettuce': 8,
  'grape': 9,
  'corn': 10,
};

class CropTimerScreen extends StatefulWidget {
  const CropTimerScreen({super.key});

  @override
  State<CropTimerScreen> createState() => _CropTimerScreenState();
}

class _CropTimerScreenState extends State<CropTimerScreen> {
  static const String _storageKey = 'crop_timer_items';
  static const String _materialApiUrl =
      'https://api.keepers-note.o-r.kr/api/cooking/materials';

  final ScrollController _scrollController = ScrollController();

  Timer? _ticker;
  Timer? _notificationTicker;

  List<CropTimerCrop> _crops = [];
  CropTimerCrop? _selectedCrop;

  List<CropTimerItem> _items = [];

  bool _isCropLoading = true;
  bool _isStartingTimer = false;
  bool _showTopButton = false;
  bool _checkingDone = false;

  @override
  void initState() {
    super.initState();

    _loadItems();
    _fetchCrops();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {});

      _checkAndNotifyCompletedTimers();
    });

    _notificationTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      _syncProgressNotification();
    });

    _scrollController.addListener(() {
      if (!_scrollController.hasClients || !mounted) return;

      final show = _scrollController.offset > 160;
      if (show != _showTopButton) {
        setState(() {
          _showTopButton = show;
        });
      }
    });

    CropTimerNotificationService.instance.init();
    CropTimerLiveActivityService.instance.init();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _notificationTicker?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCrops() async {
    try {
      final response = await http.get(Uri.parse(_materialApiUrl));

      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _isCropLoading = false;
        });
        return;
      }

      final List<dynamic> decoded =
      jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;

      final crops = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where(_shouldIncludeAsCrop)
          .map(CropTimerCrop.fromJson)
          .where((e) => e.name.trim().isNotEmpty)
          .where((e) => e.growMinutes > 0)
          .toList();

      crops.sort((a, b) {
        final aOrder = _cropSortOrder[a.id] ?? 999;
        final bOrder = _cropSortOrder[b.id] ?? 999;

        if (aOrder != bOrder) {
          return aOrder.compareTo(bOrder);
        }

        return a.name.compareTo(b.name);
      });

      if (!mounted) return;

      setState(() {
        _crops = crops;
        _selectedCrop = crops.isNotEmpty ? crops.first : null;
        _isCropLoading = false;
      });
    } catch (e) {
      debugPrint('작물 목록 불러오기 실패: $e');

      if (!mounted) return;
      setState(() {
        _isCropLoading = false;
      });
    }
  }

  static bool _shouldIncludeAsCrop(Map<String, dynamic> json) {
    final isCultivable = _parseIsCultivable(json);
    final minutes = _parseGrowMinutes(json);

    return isCultivable || minutes > 0;
  }

  static bool _parseIsCultivable(Map<String, dynamic> json) {
    final dynamic raw = json['isCultivable'] ?? json['is_cultivable'];

    if (raw is bool) return raw;
    if (raw is num) return raw == 1;

    if (raw is String) {
      final value = raw.trim().toLowerCase();
      return value == '1' || value == 'true' || value == 'y';
    }

    return false;
  }

  Future<void> _syncLiveActivity() async {
    final activeItems = _items
        .where((e) => DateTime.now().isBefore(e.harvestAt))
        .toList()
      ..sort((a, b) => a.harvestAt.compareTo(b.harvestAt));

    await CropTimerLiveActivityService.instance.endAllActivities();

    if (activeItems.isEmpty) {
      return;
    }

    final next = activeItems.first;

    final summaryText = activeItems.length <= 1
        ? ''
        : '작물 ${activeItems.length}개 진행 중';

    await CropTimerLiveActivityService.instance.startCropTimer(
      timerId: next.id.toString(),
      cropId: next.cropId,
      cropName: next.cropName,
      summaryText: summaryText,
      plantedAt: next.plantedAt,
      harvestAt: next.harvestAt,
    );
  }

  Future<void> _syncProgressNotification() async {
    final activeItems = _items
        .where((e) => DateTime.now().isBefore(e.harvestAt))
        .toList()
      ..sort((a, b) => a.harvestAt.compareTo(b.harvestAt));

    if (activeItems.isEmpty) {
      await CropTimerNotificationService.instance
          .cancelCropTimerProgressNotification();
      return;
    }

    await CropTimerNotificationService.instance
        .showCropTimerProgressSummaryNotification(
      items: activeItems
          .map(
            (item) => CropTimerNotificationItem(
          cropName: item.cropName,
          plantedAt: item.plantedAt,
          harvestAt: item.harvestAt,
        ),
      )
          .toList(),
    );
  }

  Future<void> _checkAndNotifyCompletedTimers() async {
    if (_checkingDone) return;
    if (_items.isEmpty) return;

    _checkingDone = true;

    try {
      final now = DateTime.now();
      bool changed = false;

      final updatedItems = <CropTimerItem>[];

      for (final item in _items) {
        if (!item.doneNotified && !item.harvestAt.isAfter(now)) {
          await CropTimerNotificationService.instance
              .showCropHarvestDoneNotification(
            notificationId: item.id,
            cropName: item.cropName,
          );

          updatedItems.add(
            item.copyWith(doneNotified: true),
          );

          changed = true;
        } else {
          updatedItems.add(item);
        }
      }

      if (!changed) return;

      if (!mounted) return;

      setState(() {
        _items = updatedItems;
      });

      await _saveItems();
      await _syncProgressNotification();
      await _syncLiveActivity();
    } finally {
      _checkingDone = false;
    }
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      await _syncProgressNotification();
      await _syncLiveActivity();
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;

      final loaded = decoded
          .whereType<Map>()
          .map((e) => CropTimerItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id != 0)
          .toList();

      loaded.sort((a, b) => a.harvestAt.compareTo(b.harvestAt));

      if (!mounted) return;

      setState(() {
        _items = loaded;
      });

      await _syncProgressNotification();
      await _syncLiveActivity();
      await _checkAndNotifyCompletedTimers();
    } catch (e) {
      debugPrint('작물 타이머 저장값 불러오기 실패: $e');
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _startTimer() async {
    final crop = _selectedCrop;
    if (crop == null || _isStartingTimer) return;

    if (crop.growMinutes <= 0) {
      _showSnackBar('이 작물은 수확 시간이 등록되어 있지 않아요.');
      return;
    }

    setState(() {
      _isStartingTimer = true;
    });

    try {
      final now = DateTime.now();
      final harvestAt = now.add(Duration(minutes: crop.growMinutes));
      final id = now.millisecondsSinceEpoch.remainder(2147483647);

      final item = CropTimerItem(
        id: id,
        cropId: crop.id,
        cropName: crop.name,
        asset: crop.asset,
        plantedAt: now,
        harvestAt: harvestAt,
        doneNotified: false,
      );

      setState(() {
        _items.insert(0, item);
        _items.sort((a, b) => a.harvestAt.compareTo(b.harvestAt));
      });

      await _saveItems();

      await CropTimerNotificationService.instance
          .scheduleCropHarvestNotification(
        notificationId: id,
        cropName: crop.name,
        harvestAt: harvestAt,
      );

      await _syncProgressNotification();
      await _syncLiveActivity();

      _showSnackBar('${crop.name} 수확 알림을 예약했어요.');
    } catch (e) {
      debugPrint('작물 타이머 시작 실패: $e');
      _showSnackBar('타이머 시작에 실패했어요.');
    } finally {
      if (!mounted) return;
      setState(() {
        _isStartingTimer = false;
      });
    }
  }

  Future<void> _deleteTimer(CropTimerItem item) async {
    setState(() {
      _items.removeWhere((e) => e.id == item.id);
    });

    await _saveItems();
    await CropTimerNotificationService.instance.cancelCropTimer(item.id);
    await _syncProgressNotification();
    await _syncLiveActivity();
  }

  Future<void> _openCropPicker() async {
    if (_crops.isEmpty) return;

    final picked = await showModalBottomSheet<CropTimerCrop>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.24),
      builder: (context) {
        return _CropPickerSheet(
          crops: _crops,
          selected: _selectedCrop,
          formatGrowTime: _formatGrowTime,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedCrop = picked;
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2D3436),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      ),
    );
  }

  String _formatGrowTime(int minutes) {
    if (minutes <= 0) return '시간 미등록';

    final hours = minutes ~/ 60;
    final remainMinutes = minutes % 60;

    if (hours > 0 && remainMinutes > 0) {
      return '$hours시간 $remainMinutes분';
    }

    if (hours > 0) {
      return '$hours시간';
    }

    return '$minutes분';
  }

  String _formatRemain(DateTime harvestAt) {
    final diff = harvestAt.difference(DateTime.now());

    if (diff.isNegative) {
      return '수확 가능';
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours시간 $minutes분 남음';
    }

    if (minutes > 0) {
      return '$minutes분 $seconds초 남음';
    }

    return '$seconds초 남음';
  }

  String _formatHarvestTime(DateTime dateTime) {
    final now = DateTime.now();

    final isToday = now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day;

    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final isTomorrow = tomorrow.year == dateTime.year &&
        tomorrow.month == dateTime.month &&
        tomorrow.day == dateTime.day;

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    if (isToday) {
      return '오늘 $hour:$minute';
    }

    if (isTomorrow) {
      return '내일 $hour:$minute';
    }

    return '${dateTime.month}.${dateTime.day} $hour:$minute';
  }

  double _progress(CropTimerItem item) {
    final total = item.harvestAt.difference(item.plantedAt).inSeconds;

    if (total <= 0) return 1;

    final passed = DateTime.now().difference(item.plantedAt).inSeconds;

    return (passed / total).clamp(0.0, 1.0);
  }

  int get _doneCount {
    return _items.where((e) => DateTime.now().isAfter(e.harvestAt)).length;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFFFF8F5),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_gradient.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    const Color(0xFFFFF5F1).withOpacity(0.54),
                    const Color(0xFFFFF8F5).withOpacity(0.86),
                  ],
                ),
              ),
            ),
          ),
          RefreshIndicator(
            color: const Color(0xFFFF8E7C),
            onRefresh: _fetchCrops,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: topPadding + 76),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStartCard(),
                        const SizedBox(height: 18),
                        _buildSectionHeader(),
                        const SizedBox(height: 10),
                        _buildActiveList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildGlassAppBar(topPadding),
          ),
          Positioned(
            right: 18,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              scale: _showTopButton ? 1 : 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showTopButton ? 1 : 0,
                child: _buildTopButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAppBar(double topPadding) {
    return ClipRRect(
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
              _buildRoundButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
                color: const Color(0xFFFF8E7C),
                backgroundColor: const Color(0xFFFFF0EC),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '작물 타이머',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2D3436),
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '수확 시간 알림 설정',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9AA4B2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildRoundButton(
                icon: Icons.refresh_rounded,
                onTap: _fetchCrops,
                color: const Color(0xFF4A90E2),
                backgroundColor: const Color(0xFFF0F7FF),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required Color backgroundColor,
  }) {
    return Material(
      color: backgroundColor,
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
              color: color.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildStartCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.84),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: _isCropLoading
              ? const SizedBox(
            height: 186,
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF8E7C),
              ),
            ),
          )
              : _crops.isEmpty
              ? SizedBox(
            height: 186,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1EC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFFF8E7C),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '등록된 작물 정보를 찾지 못했어요.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1EC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.spa_rounded,
                      size: 20,
                      color: Color(0xFFFF8E7C),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '새 타이머 시작',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D3436),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '심은 작물을 선택해주세요',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9AA4B2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSelectedCropCard(),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed:
                  _isStartingTimer ? null : _startTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8E7C),
                    disabledBackgroundColor:
                    const Color(0xFFFFC3B8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: _isStartingTimer
                        ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      key: ValueKey('text'),
                      '타이머 시작',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedCropCard() {
    final crop = _selectedCrop;

    if (crop == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.white.withOpacity(0.72),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _openCropPicker,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFFDCD4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Image.asset(
                  crop.asset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.eco_rounded,
                    color: Color(0xFFFF8E7C),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crop.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2D3436),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '수확까지 ${_formatGrowTime(crop.growMinutes)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF8E7C),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF94A3B8),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '진행 중인 타이머',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D3436),
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (_items.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1EC),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFFFDCD4),
                width: 1,
              ),
            ),
            child: Text(
              _doneCount > 0 ? '수확 가능 $_doneCount개' : '총 ${_items.length}개',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFF8E7C),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveList() {
    if (_items.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 38,
              horizontal: 18,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.66),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.78),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1EC),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    size: 30,
                    color: Color(0xFFFF8E7C),
                  ),
                ),
                const SizedBox(height: 13),
                const Text(
                  '진행 중인 작물 타이머가 없어요.',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7C8796),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  '작물을 심었다면 수확 알림을 예약해보세요.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB0B8C4),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: _items.map(_buildTimerTile).toList(),
    );
  }

  Widget _buildTimerTile(CropTimerItem item) {
    final bool isDone = DateTime.now().isAfter(item.harvestAt);
    final double progress = _progress(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isDone ? 0.92 : 0.82),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDone
                    ? const Color(0xFFFFB4A6)
                    : Colors.white.withOpacity(0.82),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDone
                          ? const [
                        Color(0xFFFFF1EC),
                        Color(0xFFFFDDD4),
                      ]
                          : const [
                        Color(0xFFFFFAF8),
                        Color(0xFFFFF0EC),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: Image.asset(
                    item.asset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.eco_rounded,
                      color: Color(0xFFFF8E7C),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.cropName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2D3436),
                                letterSpacing: -0.25,
                              ),
                            ),
                          ),
                          if (isDone)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1EC),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '완료',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFF6F61),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFFFE6DF),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF8E7C),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatRemain(item.harvestAt),
                              style: TextStyle(
                                fontSize: 12.2,
                                fontWeight: FontWeight.w900,
                                color: isDone
                                    ? const Color(0xFFFF6F61)
                                    : const Color(0xFF7C8796),
                              ),
                            ),
                          ),
                          Text(
                            _formatHarvestTime(item.harvestAt),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB0B8C4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _deleteTimer(item),
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.close_rounded,
                        color: Color(0xFFB0B8C4),
                        size: 21,
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

  Widget _buildTopButton() {
    return Material(
      color: Colors.white.withOpacity(0.88),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
          );
        },
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.82),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.keyboard_arrow_up_rounded,
            color: Color(0xFFFF8E7C),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _CropPickerSheet extends StatelessWidget {
  final List<CropTimerCrop> crops;
  final CropTimerCrop? selected;
  final String Function(int minutes) formatGrowTime;

  const _CropPickerSheet({
    required this.crops,
    required this.selected,
    required this.formatGrowTime,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomPadding),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: Colors.white.withOpacity(0.82),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1EC),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Color(0xFFFF8E7C),
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '작물 선택',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2D3436),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '수확 알림을 받을 작물을 골라주세요',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(context),
                        child: const SizedBox(
                          width: 38,
                          height: 38,
                          child: Icon(
                            Icons.close_rounded,
                            size: 21,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: crops.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final crop = crops[index];
                      final isSelected = selected?.id == crop.id;

                      return Material(
                        color: isSelected
                            ? const Color(0xFFFFF1EC)
                            : Colors.white.withOpacity(0.68),
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => Navigator.pop(context, crop),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFFB4A6)
                                    : const Color(0xFFEFE6E2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.74),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Image.asset(
                                    crop.asset,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.eco_rounded,
                                      color: Color(0xFFFF8E7C),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        crop.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF2D3436),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '수확까지 ${formatGrowTime(crop.growMinutes)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFFF8E7C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFF8E7C)
                                        : const Color(0xFFF8FAFC),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_rounded
                                        : Icons.chevron_right_rounded,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFFB0B8C4),
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CropTimerCrop {
  final String id;
  final String name;
  final String asset;
  final int growMinutes;

  const CropTimerCrop({
    required this.id,
    required this.name,
    required this.asset,
    required this.growMinutes,
  });

  factory CropTimerCrop.fromJson(Map<String, dynamic> json) {
    final String id = json['id']?.toString().trim().toLowerCase() ?? '';

    final String name =
    (json['nameKo'] ?? json['name_ko'] ?? json['name'] ?? '')
        .toString()
        .trim();

    final String rawImage = json['image']?.toString().trim() ?? '';

    final String asset = rawImage.startsWith('assets/')
        ? rawImage
        : rawImage.isNotEmpty
        ? 'assets/$rawImage'
        : _cropFallbackAssetPath(name);

    return CropTimerCrop(
      id: id.isNotEmpty ? id : name,
      name: name,
      asset: asset,
      growMinutes: _parseGrowMinutes(json),
    );
  }
}

class CropTimerItem {
  final int id;
  final String cropId;
  final String cropName;
  final String asset;
  final DateTime plantedAt;
  final DateTime harvestAt;
  final bool doneNotified;

  CropTimerItem({
    required this.id,
    required this.cropId,
    required this.cropName,
    required this.asset,
    required this.plantedAt,
    required this.harvestAt,
    this.doneNotified = false,
  });

  factory CropTimerItem.fromJson(Map<String, dynamic> json) {
    return CropTimerItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      cropId: json['cropId']?.toString() ?? '',
      cropName: json['cropName']?.toString() ?? '',
      asset: json['asset']?.toString() ?? '',
      plantedAt: DateTime.tryParse(json['plantedAt']?.toString() ?? '') ??
          DateTime.now(),
      harvestAt: DateTime.tryParse(json['harvestAt']?.toString() ?? '') ??
          DateTime.now(),
      doneNotified: json['doneNotified'] == true,
    );
  }

  CropTimerItem copyWith({
    bool? doneNotified,
  }) {
    return CropTimerItem(
      id: id,
      cropId: cropId,
      cropName: cropName,
      asset: asset,
      plantedAt: plantedAt,
      harvestAt: harvestAt,
      doneNotified: doneNotified ?? this.doneNotified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cropId': cropId,
      'cropName': cropName,
      'asset': asset,
      'plantedAt': plantedAt.toIso8601String(),
      'harvestAt': harvestAt.toIso8601String(),
      'doneNotified': doneNotified,
    };
  }
}

int _parseGrowMinutes(Map<String, dynamic> json) {
  final dynamic minuteRaw =
      json['growMinutes'] ??
          json['grow_minutes'] ??
          json['growthMinutes'] ??
          json['growth_minutes'] ??
          json['harvestMinutes'] ??
          json['harvest_minutes'] ??
          json['cultivationMinutes'] ??
          json['cultivation_minutes'] ??
          json['growTimeMinutes'] ??
          json['grow_time_minutes'] ??
          json['cropGrowMinutes'] ??
          json['crop_grow_minutes'];

  final int? minutes = int.tryParse(minuteRaw?.toString() ?? '');

  if (minutes != null && minutes > 0) {
    return minutes;
  }

  final String id = json['id']?.toString().trim().toLowerCase() ?? '';

  final String nameKo =
  (json['nameKo'] ?? json['name_ko'] ?? json['name'] ?? '')
      .toString()
      .trim();

  final int? byId = _cropMinutesById[id];
  if (byId != null && byId > 0) {
    return byId;
  }

  final int? byName = _cropMinutesByName[nameKo];
  if (byName != null && byName > 0) {
    return byName;
  }

  return 0;
}

String _cropFallbackAssetPath(String name) {
  final normalized = name.trim();

  const map = {
    '감자': 'assets/images/crops/potato.webp',
    '밀': 'assets/images/crops/wheat.webp',
    '상추': 'assets/images/crops/lettuce.webp',
    '당근': 'assets/images/crops/carrot.webp',
    '옥수수': 'assets/images/crops/corn.webp',
    '딸기': 'assets/images/crops/strawberry.webp',
    '포도': 'assets/images/crops/grape.webp',
    '가지': 'assets/images/crops/eggplant.webp',
    '토마토': 'assets/images/crops/tomato.webp',
    '파인애플': 'assets/images/resources/pineapple.png',
  };

  return map[normalized] ?? 'assets/images/default.png';
}
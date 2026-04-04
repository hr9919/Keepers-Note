import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'data/place_labels.dart';
import 'models/place_label.dart';
import 'models/resource_model.dart';
import 'services/api_service.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

class MapScreen extends StatefulWidget {
  final bool openFilterOnStart;

  const MapScreen({
    super.key,
    this.openFilterOnStart = false,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<ResourceModel> _resources = [];
  bool _isLoading = true;
  Set<String> _enabledResources = {};
  bool _showAllNpcs = true;
  bool _showAllAnimals = false;

  final Color seaColor = const Color(0xFF6CA0B3);
  final Color accentColor = const Color(0xFFFF8E7C);

  final TransformationController _transformationController =
  TransformationController();

  double _currentScale = 1.0;
  bool _didSetInitialTransform = false;
  bool _didOpenDrawerOnStart = false;
  int? _selectedResourceId;

  String _voterId = "";

  bool _isProgressiveVotePin(ResourceModel res) {
    return res.koName == '그 자리 참나무' || res.koName == '완벽한 형광석';
  }

  bool _isVoteCompleted(ResourceModel res) {
    return res.voteCount >= 5 || res.isFixed;
  }

  double _votePinOpacity(ResourceModel res) {
    if (!_isProgressiveVotePin(res)) return 1.0;
    if (_isVoteCompleted(res)) return 1.0;

    switch (res.voteCount) {
      case 0:
        return 0.28;
      case 1:
        return 0.42;
      case 2:
        return 0.58;
      case 3:
        return 0.74;
      case 4:
        return 0.88;
      default:
        return 1.0;
    }
  }

  TapDownDetails? _doubleTapDetails;
  AnimationController? _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;

  static const double _baseMapWidthFactor = 0.90;
  static const double _initialMapScale = 1.0;
  static const double _minMapScale = _initialMapScale;
  static const double _maxMapScale = 4.5;
  static const double _doubleTapZoomScale = 2.2;

  static const double _placeRevealScale = 1.45;

  @override
  void initState() {
  super.initState();
  _loadVoterId();
  _loadResources();
  }

  @override
  void dispose() {
    final controller = _zoomAnimationController;
    _zoomAnimationController = null;
    _zoomAnimation = null;
    controller?.dispose();

    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadVoterId() async {
    try {
      final user = await UserApi.instance.me();
      final voterId = user.id?.toString() ?? "";

      if (!mounted) return;
      setState(() {
        _voterId = voterId;
      });
    } catch (e) {
      debugPrint('유저 정보 불러오기 실패: $e');
    }
  }

  Future<void> _handleVote(ResourceModel res) async {
    if (_voterId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 불러올 수 없습니다. 다시 시도해주세요.')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
          'http://161.33.30.40:8080/api/map/vote/${res.id}?voterId=$_voterId',
        ),
      );

      if (response.statusCode == 200) {
        await _loadResources();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${res.koName}에 투표했습니다!')),
        );

        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.body.isNotEmpty ? response.body : '투표에 실패했습니다.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('투표 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _loadResources() async {
    try {
      final data = await ApiService.getResources();
      if (!mounted) return;

      setState(() {
        _resources = data;

        _enabledResources = data
            .where(
              (res) =>
          res.category != 'npc' &&
              res.category != 'animal' &&
              res.category != 'location' &&
              !res.isFixed,
        )
            .map((res) => res.resourceName)
            .toSet();

        _showAllNpcs = true;
        _showAllAnimals = false;
        _isLoading = false;
      });

      _openDrawerIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _openDrawerIfNeeded();
    }
  }

  void _openDrawerIfNeeded() {
    if (!widget.openFilterOnStart || _didOpenDrawerOnStart) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didOpenDrawerOnStart) return;
      _didOpenDrawerOnStart = true;
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  double _clampScale(double scale) {
    return scale.clamp(_minMapScale, _maxMapScale);
  }

  Matrix4 _buildMatrix({
    required BoxConstraints constraints,
    required double mapSize,
    required double scale,
    required Offset desiredTranslation,
  }) {
    final double safeScale = _clampScale(scale);
    final double scaledWidth = mapSize * safeScale;
    final double scaledHeight = mapSize * safeScale;

    final double centeredX = (constraints.maxWidth - scaledWidth) / 2;
    final double centeredY = (constraints.maxHeight - scaledHeight) / 2;

    if ((safeScale - _minMapScale).abs() < 0.001) {
      return Matrix4.identity()
        ..translate(centeredX, centeredY)
        ..scale(safeScale);
    }

    return Matrix4.identity()
      ..translate(desiredTranslation.dx, desiredTranslation.dy)
      ..scale(safeScale);
  }

  void _forceCenterAtMinimumScale(
      BoxConstraints constraints,
      double mapSize,
      ) {
    final Matrix4 centered = _buildMatrix(
      constraints: constraints,
      mapSize: mapSize,
      scale: _minMapScale,
      desiredTranslation: Offset.zero,
    );

    _transformationController.value = centered;

    if (mounted && _currentScale != _minMapScale) {
      setState(() {
        _currentScale = _minMapScale;
      });
    }
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    final oldController = _zoomAnimationController;
    _zoomAnimationController = null;
    _zoomAnimation = null;

    oldController?.stop();
    oldController?.dispose();

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _zoomAnimationController = controller;

    final animation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _zoomAnimation = animation;

    animation.addListener(() {
      if (!mounted || _zoomAnimationController != controller) return;

      _transformationController.value = animation.value;
      final newScale = _transformationController.value.getMaxScaleOnAxis();

      if (newScale != _currentScale) {
        setState(() {
          _currentScale = newScale;
        });
      }
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (_zoomAnimationController == controller) {
          _zoomAnimationController = null;
          _zoomAnimation = null;
        }
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _animateToCenterScale({
    required BoxConstraints constraints,
    required double mapSize,
    required double scale,
  }) {
    final double safeScale = _clampScale(scale);
    final double scaledMapWidth = mapSize * safeScale;
    final double scaledMapHeight = mapSize * safeScale;

    final Offset translation = Offset(
      (constraints.maxWidth - scaledMapWidth) / 2,
      (constraints.maxHeight - scaledMapHeight) / 2,
    );

    final Matrix4 target = _buildMatrix(
      constraints: constraints,
      mapSize: mapSize,
      scale: safeScale,
      desiredTranslation: translation,
    );

    _animateToMatrix(target);
  }

  void _applyTransformToCenter({
    required BoxConstraints constraints,
    required double mapSize,
    required double scale,
  }) {
    final double safeScale = _clampScale(scale);
    final double scaledMapWidth = mapSize * safeScale;
    final double scaledMapHeight = mapSize * safeScale;

    final Offset translation = Offset(
      (constraints.maxWidth - scaledMapWidth) / 2,
      (constraints.maxHeight - scaledMapHeight) / 2,
    );

    _transformationController.value = _buildMatrix(
      constraints: constraints,
      mapSize: mapSize,
      scale: safeScale,
      desiredTranslation: translation,
    );

    _currentScale = safeScale;
  }

  void _applyInitialTransform(BoxConstraints constraints, double mapSize) {
    if (_didSetInitialTransform) return;
    if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didSetInitialTransform) return;

      _applyTransformToCenter(
        constraints: constraints,
        mapSize: mapSize,
        scale: _initialMapScale,
      );

      setState(() {
        _didSetInitialTransform = true;
      });
    });
  }

  void _resetToMinimumScale(BoxConstraints constraints, double mapSize) {
    _animateToCenterScale(
      constraints: constraints,
      mapSize: mapSize,
      scale: _minMapScale,
    );
  }

  void _handleDoubleTap(BoxConstraints constraints, double mapSize) {
    if (_doubleTapDetails == null) return;

    final Offset tapPosition = _doubleTapDetails!.localPosition;
    final double current = _transformationController.value.getMaxScaleOnAxis();

    if (current > _minMapScale + 0.05) {
      _resetToMinimumScale(constraints, mapSize);
      return;
    }

    final double targetScale = math.min(_doubleTapZoomScale, _maxMapScale);
    final Offset scenePoint = _transformationController.toScene(tapPosition);

    final Offset desiredTranslation = Offset(
      tapPosition.dx - scenePoint.dx * targetScale,
      tapPosition.dy - scenePoint.dy * targetScale,
    );

    final Matrix4 targetMatrix = _buildMatrix(
      constraints: constraints,
      mapSize: mapSize,
      scale: targetScale,
      desiredTranslation: desiredTranslation,
    );

    _animateToMatrix(targetMatrix);
  }

  void _showResourceDetail(ResourceModel res) {
    final bool isVoteTarget = _isProgressiveVotePin(res);
    final bool isActuallyVerified = _isVoteCompleted(res);
    final bool needsVote = isVoteTarget && !isActuallyVerified;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        res.iconPath,
                        width: 26,
                        height: 26,
                        errorBuilder: (c, e, s) =>
                        const Icon(Icons.pets, color: Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      res.koName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (isActuallyVerified)
                  const Icon(Icons.verified, color: Colors.blue, size: 24),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                res.description ?? "정보가 없습니다.",
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                if (needsVote) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleVote(res),
                      icon: const Icon(Icons.thumb_up_outlined),
                      label: Text("여기 있어요! (${res.voteCount})"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("확인"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getDistinctNamesByCategory(List<String> categories) {
    return _resources
        .where((res) => categories.contains(res.category))
        .map((res) => res.resourceName)
        .toSet()
        .toList();
  }

  void _toggleResource(String resourceName) {
    setState(() {
      if (_enabledResources.contains(resourceName)) {
        _enabledResources.remove(resourceName);
      } else {
        _enabledResources.add(resourceName);
      }
    });
  }

  bool _isVisibleOnMap(ResourceModel res) {
    if (res.category == 'npc') return _showAllNpcs;
    if (res.category == 'animal') return _showAllAnimals;
    if (res.category == 'location') return false;
    return _enabledResources.contains(res.resourceName);
  }

  List<ResourceModel> _findNearbyCharacters(
      ResourceModel target, {
        double threshold = 0.022,
      }) {
    final List<ResourceModel> nearby = _resources.where((res) {
      final bool isCharacter = res.category == 'npc' || res.category == 'animal';
      if (!isCharacter) return false;
      if (!_isVisibleOnMap(res)) return false;

      final double dx = res.x - target.x;
      final double dy = res.y - target.y;
      final double distanceSquared = dx * dx + dy * dy;
      return distanceSquared <= threshold * threshold;
    }).toList();

    nearby.sort((a, b) {
      final double da = math.pow(a.x - target.x, 2).toDouble() +
          math.pow(a.y - target.y, 2).toDouble();
      final double db = math.pow(b.x - target.x, 2).toDouble() +
          math.pow(b.y - target.y, 2).toDouble();

      if (da != db) return da.compareTo(db);
      return a.koName.compareTo(b.koName);
    });

    return nearby;
  }

  void _handleCharacterTap(ResourceModel res) {
    final nearby = _findNearbyCharacters(res);

    if (nearby.length <= 1) {
      setState(() {
        _selectedResourceId = res.id;
      });
      _showResourceDetail(res);
      return;
    }

    _showCharacterPicker(nearby, tapped: res);
  }

  void _showCharacterPicker(
      List<ResourceModel> items, {
        required ResourceModel tapped,
      }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '겹쳐 있는 캐릭터',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '선택할 캐릭터를 눌러 주세요.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ...items.map((res) {
                final bool isAnimal = res.category == 'animal';
                final bool isTapped = res.id == tapped.id;

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedResourceId = res.id;
                    });
                    _showResourceDetail(res);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isTapped
                          ? const Color(0xFFFFF7F5)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isTapped
                            ? accentColor.withOpacity(0.35)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isAnimal
                                  ? Colors.lightBlue
                                  : const Color(0xFFFFD7D1),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              res.iconPath,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.image_not_supported_outlined,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                res.koName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isAnimal ? '동물 친구' : '마을 주민',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerSectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF94A3B8),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildMapFilterChip(String resourceName) {
    if (_resources.isEmpty) return const SizedBox.shrink();

    final bool isEnabled = _enabledResources.contains(resourceName);

    final ResourceModel sampleRes = _resources.firstWhere(
          (r) => r.resourceName == resourceName,
      orElse: () => _resources.first,
    );

    return GestureDetector(
      onTap: () => _toggleResource(resourceName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isEnabled
              ? const Color(0xFFFFF4F1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEnabled
                ? const Color(0xFFFF8E7C)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isEnabled
                      ? const Color(0xFFFFD4CC)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Image.asset(
                sampleRes.iconPath,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.inventory_2_outlined,
                  size: 12,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              sampleRes.koName,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isEnabled
                    ? const Color(0xFF111827)
                    : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapFilterSection({
    required String title,
    required List<String> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDrawerSectionLabel(title),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map(_buildMapFilterChip).toList(),
        ),
      ],
    );
  }

  Widget _buildFilterDrawer() {
    final gatherItems =
    _getDistinctNamesByCategory(['fruit', 'bubble', 'tree', 'material']);
    final mushroomItems = _getDistinctNamesByCategory(['mushroom']);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.86,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '지도 필터',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildToggleRow(
                      icon: Icons.people_alt_outlined,
                      title: '마을 주민',
                      value: _showAllNpcs,
                      onChanged: (val) => setState(() => _showAllNpcs = val),
                    ),
                    const SizedBox(height: 10),
                    _buildToggleRow(
                      icon: Icons.pets_outlined,
                      title: '동물 친구들',
                      value: _showAllAnimals,
                      onChanged: (val) => setState(() => _showAllAnimals = val),
                    ),
                    const SizedBox(height: 22),
                    _buildMapFilterSection(
                      title: '채집 자원',
                      items: gatherItems,
                    ),
                    const SizedBox(height: 18),
                    _buildMapFilterSection(
                      title: '버섯 종류',
                      items: mushroomItems,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF475569)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          _buildDrawerCustomSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerCustomSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 53,
        height: 30,
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFFFF8E7C).withOpacity(0.56)
              : const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Container(
              width: 25,
              height: 25,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingMapHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildHeaderIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    '지도',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              _buildHeaderIconButton(
                icon: Icons.tune_rounded,
                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF334155),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildMapMarker(ResourceModel res, double mapSize) {
    const double markerSize = 28;

    final double visualScale = (1 / _currentScale).clamp(0.5, 1.0);

    return Positioned(
      left: (res.x * mapSize) - (markerSize / 2),
      top: (res.y * mapSize) - (markerSize / 2),
      child: GestureDetector(
        onTap: () {
          final bool isCharacter =
              res.category == 'npc' || res.category == 'animal';

          if (isCharacter) {
            _handleCharacterTap(res);
          } else {
            setState(() {
              _selectedResourceId = res.id;
            });
            _showResourceDetail(res);
          }
        },
        child: Transform.scale(
          scale: visualScale,
          alignment: Alignment.center,
          child: Opacity(
            opacity: _votePinOpacity(res),
            child: _buildCircleMarker(
              res,
              isAnimal: res.category == 'animal',
              isNpc: res.category == 'npc',
              isSelected: _selectedResourceId == res.id,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleMarker(
      ResourceModel res, {
        required bool isAnimal,
        required bool isNpc,
        required bool isSelected,
      }) {
    Color borderColor;

    if (isSelected) {
      borderColor = accentColor;
    } else if (isAnimal) {
      borderColor = Colors.lightBlue;
    } else if (isNpc) {
      borderColor = const Color(0xFFFFD7D1);
    } else {
      borderColor = const Color(0xFFFF8E7C);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 28,
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: isSelected ? 2.6 : 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isSelected ? 0.20 : 0.14),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          res.iconPath,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const Icon(
            Icons.image_not_supported_outlined,
            size: 18,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  bool _shouldShowPlaceLabel(PlaceLabel place) {
    if (place.showFromBaseZoom) return true;
    return _currentScale >= _placeRevealScale;
  }

  Widget _buildPlaceLabels(double mapSize) {
    final double textScale = (1 / (_currentScale * 1.22)).clamp(0.34, 0.78);

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final place in placeLabels)
            if (_shouldShowPlaceLabel(place))
              for (final pos in place.positions)
                Positioned(
                  left: pos.dx * mapSize,
                  top: pos.dy * mapSize,
                  child: Transform.translate(
                    offset: const Offset(-24, -8),
                    child: Transform.scale(
                      scale: textScale,
                      alignment: Alignment.centerLeft,
                      child: Opacity(
                        opacity: 0.78,
                        child: Text(
                          place.nameKo,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: Color(0xBB000000),
                                blurRadius: 5,
                                offset: Offset(0, 1.2),
                              ),
                              Shadow(
                                color: Color(0x55000000),
                                blurRadius: 10,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildZoomButtons(BoxConstraints constraints, double mapSize) {
    return Column(
      children: [
        _buildRoundActionButton(
          icon: Icons.add_rounded,
          onTap: () {
            final nextScale =
            (_currentScale * 1.2).clamp(_minMapScale, _maxMapScale);
            _animateToCenterScale(
              constraints: constraints,
              mapSize: mapSize,
              scale: nextScale,
            );
          },
        ),
        const SizedBox(height: 10),
        _buildRoundActionButton(
          icon: Icons.remove_rounded,
          onTap: () {
            final nextScale =
            (_currentScale / 1.2).clamp(_minMapScale, _maxMapScale);
            _animateToCenterScale(
              constraints: constraints,
              mapSize: mapSize,
              scale: nextScale,
            );
          },
        ),
        const SizedBox(height: 10),
        _buildRoundActionButton(
          icon: Icons.refresh_rounded,
          onTap: () => _resetToMinimumScale(constraints, mapSize),
        ),
      ],
    );
  }

  Widget _buildRoundActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.94),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: seaColor,
      endDrawer: _buildFilterDrawer(),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.white),
      )
          : LayoutBuilder(
        builder: (context, constraints) {
          final double mapSize = constraints.maxWidth * _baseMapWidthFactor;
          _applyInitialTransform(constraints, mapSize);

          final visibleResources =
          _resources.where((res) => _isVisibleOnMap(res)).toList();

          visibleResources.sort((a, b) {
            final int aPriority = a.id == _selectedResourceId ? 1 : 0;
            final int bPriority = b.id == _selectedResourceId ? 1 : 0;
            return aPriority.compareTo(bPriority);
          });

          return Stack(
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTapDown: (details) {
                      _doubleTapDetails = details;
                    },
                    onDoubleTap: () => _handleDoubleTap(constraints, mapSize),
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: _minMapScale,
                      maxScale: _maxMapScale,
                      panEnabled: _currentScale > _minMapScale + 0.001,
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(400),
                      clipBehavior: Clip.none,
                      onInteractionUpdate: (_) {
                        final matrix = _transformationController.value;
                        final newScale =
                        _clampScale(matrix.getMaxScaleOnAxis());

                        if ((newScale - _minMapScale).abs() < 0.001) {
                          _forceCenterAtMinimumScale(constraints, mapSize);
                          return;
                        }

                        if (newScale != _currentScale) {
                          setState(() {
                            _currentScale = newScale;
                          });
                        }
                      },
                      onInteractionEnd: (_) {
                        if ((_currentScale - _minMapScale).abs() < 0.001) {
                          _forceCenterAtMinimumScale(constraints, mapSize);
                        }
                      },
                      child: SizedBox(
                        width: mapSize,
                        height: mapSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/map_background.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                            _buildPlaceLabels(mapSize),
                            ...visibleResources
                                .map((res) => _buildMapMarker(res, mapSize)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: MediaQuery.of(context).padding.top + 12,
                child: _buildFloatingMapHeader(),
              ),
              Positioned(
                right: 16,
                bottom: 24,
                child: _buildZoomButtons(constraints, mapSize),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModernPinPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final Color shadowColor;

  _ModernPinPainter({
    required this.color,
    required this.borderColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path();
    final double w = size.width;
    final double h = size.height;

    path.moveTo(w / 2, h);
    path.quadraticBezierTo(w * 0.12, h * 0.62, w * 0.16, h * 0.34);
    path.arcToPoint(
      Offset(w * 0.84, h * 0.34),
      radius: Radius.circular(w * 0.34),
      clockwise: false,
    );
    path.quadraticBezierTo(w * 0.88, h * 0.62, w / 2, h);

    canvas.drawShadow(path, shadowColor, 6, false);

    final Paint fillPaint = Paint()..color = color;
    canvas.drawPath(path, fillPaint);

    final Paint strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ModernPinPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}
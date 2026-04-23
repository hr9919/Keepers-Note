import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'data/place_labels.dart';
import 'models/place_label.dart';
import 'models/resource_model.dart';
import 'models/map_data_response.dart';
import 'models/spawn_point_model.dart';
import 'models/spawn_resource_model.dart';
import 'services/api_service.dart';

class MapScreen extends StatefulWidget {
  final bool openFilterOnStart;
  final Set<String>? initialEnabledResourceKeys;
  final bool? initialShowAllNpcs;
  final bool? initialShowAllAnimals;
  final String userId;   // 서버 user id
  final bool isAdmin;    // 관리자 여부

  const MapScreen({
    super.key,
    this.openFilterOnStart = false,
    this.initialEnabledResourceKeys,
    this.initialShowAllNpcs,
    this.initialShowAllAnimals,
    required this.userId,
    required this.isAdmin,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<ResourceModel> _fixedResources = [];
  List<SpawnPointModel> _spawnPoints = [];

  bool _isLoading = true;
  Set<String> _enabledResources = {};
  bool _showAllNpcs = true;
  bool _showAllAnimals = false;
  bool _isFilterPanelOpen = false;

  bool _showVoteNoticeBar = false;
  bool _hasShownVoteNoticeOnce = false;
  bool _isTodayLocationVerified = false;
  Timer? _voteNoticeTimer;
  String _todayOakLocationLabel = '';
  String _todayFluoriteLocationLabel = '';

  final Color seaColor = const Color(0xFF6CA0B3);
  final Color accentColor = const Color(0xFFFF8E7C);

  final TransformationController _transformationController =
  TransformationController();

  double _currentScale = 1.0;
  bool _didSetInitialTransform = false;
  bool _didOpenDrawerOnStart = false;
  int? _selectedFixedResourceId;
  int? _selectedSpawnPointId;

  String _voterId = "";


  void _showFloatingSnackBarMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final media = MediaQuery.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, media.padding.bottom + 76),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _loadUserId();
    await _loadResources();
  }

  @override
  void dispose() {
    _voteNoticeTimer?.cancel();

    final controller = _zoomAnimationController;
    _zoomAnimationController = null;
    _zoomAnimation = null;
    controller?.dispose();

    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    try {
      final MapDataResponse data =
      await ApiService.getResources(userId: _voterId);

      if (!mounted) return;

      final fixedFilterKeys = data.fixedResources
          .where(
            (res) =>
        res.category != 'npc' &&
            res.category != 'animal' &&
            res.category != 'location' &&
            _normalizeFilterKey(res) != 'gold_bubble',
      )
          .map((res) => _normalizeFilterKey(res));

      final spawnFilterKeys = data.spawnPoints
          .expand((point) => point.resources)
          .map((res) => _normalizeSpawnResourceKey(res));

      final Set<String> availableKeys = {
        ...fixedFilterKeys,
        ...spawnFilterKeys,
      };

      final Set<String>? requestedKeys = widget.initialEnabledResourceKeys;
      final bool useCustomInitialKeys =
          requestedKeys != null && requestedKeys.isNotEmpty;

      final Set<String> safeInitialKeys = useCustomInitialKeys
          ? requestedKeys.where((key) => availableKeys.contains(key)).toSet()
          : <String>{};

      final Set<String> defaultInitialKeys = {
        if (availableKeys.contains('roaming_oak')) 'roaming_oak',
        if (availableKeys.contains('fluorite')) 'fluorite',
      };

      for (final point in data.spawnPoints) {
        debugPrint('--- spawn point id=${point.id} oakOnly=${point.isOakOnly}');
        for (final res in point.resources) {
          debugPrint(
            'resource=${res.resourceName}, verified=${res.isVerified}, vote=${res.voteCount}',
          );
        }
      }

      SpawnPointModel? verifiedOakPoint;
      SpawnPointModel? verifiedFluoritePoint;

      for (final point in data.spawnPoints) {
        for (final res in point.resources) {
          if (res.resourceName == 'roaming_oak' && res.isVerified) {
            verifiedOakPoint = point;
          }
          if (res.resourceName == 'fluorite' && res.isVerified) {
            verifiedFluoritePoint = point;
          }
        }
      }

      final bool hasVerifiedOak = verifiedOakPoint != null;
      final bool hasVerifiedFluorite = verifiedFluoritePoint != null;

      final bool isTodayLocationVerified =
          hasVerifiedOak && hasVerifiedFluorite;

      final String todayOakLocationLabel =
      verifiedOakPoint?.placeLabel?.trim().isNotEmpty == true
          ? verifiedOakPoint!.placeLabel!.trim()
          : '';

      final String todayFluoriteLocationLabel =
      verifiedFluoritePoint?.placeLabel?.trim().isNotEmpty == true
          ? verifiedFluoritePoint!.placeLabel!.trim()
          : '';

      final bool shouldShowVoteNotice =
          !_hasShownVoteNoticeOnce && data.spawnPoints.isNotEmpty;

      setState(() {
        _fixedResources = data.fixedResources;
        _spawnPoints = data.spawnPoints;

        _enabledResources = useCustomInitialKeys
            ? {...safeInitialKeys}
            : {...defaultInitialKeys};

        _showAllNpcs = widget.initialShowAllNpcs ?? !useCustomInitialKeys;
        _showAllAnimals = widget.initialShowAllAnimals ?? false;
        _isLoading = false;

        _isTodayLocationVerified = isTodayLocationVerified;
        _todayOakLocationLabel = todayOakLocationLabel;
        _todayFluoriteLocationLabel = todayFluoriteLocationLabel;

        if (shouldShowVoteNotice) {
          _hasShownVoteNoticeOnce = true;
        }
      });

      if (shouldShowVoteNotice) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 150), () {
            if (!mounted) return;
            _showVoteNoticeTemporarily();
          });
        });
      }

      _openDrawerIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _openDrawerIfNeeded();
    }
  }

  Future<void> _loadUserId() async {
    if (!mounted) return;
    setState(() {
      _voterId = widget.userId;
    });
  }

  Future<void> _handleVote(SpawnResourceModel res) async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (_voterId.isEmpty) {
      if (!mounted) return;
      _showFloatingSnackBarMessage('로그인 정보를 불러올 수 없습니다. 다시 시도해주세요.');
      return;
    }

    if (res.alreadyVotedSameType) {
      if (!mounted) return;
      _showFloatingSnackBarMessage('이미 ${res.koName}에 투표했어요.');
      return;
    }

    try {
      final response = await ApiService.voteResource(
        id: res.id,
        userId: _voterId,
      );

      await _loadResources();

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showFloatingSnackBarMessage('${res.koName}에 투표했습니다!');
        return;
      }

      if (response.statusCode == 409) {
        _showFloatingSnackBarMessage(response.body.isNotEmpty ? response.body : '이미 이 자원 종류에 투표했어요.');
        return;
      }

      _showFloatingSnackBarMessage(response.body.isNotEmpty ? response.body : '투표에 실패했습니다.');
    } catch (e) {
      if (!mounted) return;
      _showFloatingSnackBarMessage('투표 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _confirmAdminLocation(
      double x,
      double y,
      String resourceType,
      ) async {
    if (!widget.isAdmin) return;

    final String userId = widget.userId.trim();
    if (userId.isEmpty) {
      _showFloatingSnackBarMessage('로그인 정보를 불러올 수 없습니다. 다시 시도해주세요.');
      return;
    }

    final double safeX = x.clamp(0.0, 1.0).toDouble();
    final double safeY = y.clamp(0.0, 1.0).toDouble();

    try {
      final uri = Uri.parse(
        'https://api.keepers-note.o-r.kr/api/map/admin/confirm-location',
      ).replace(
        queryParameters: <String, String>{
          'userId': userId,
        },
      );

      final response = await http
          .post(
        uri,
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'lng': safeX * 1024.0,
          'lat': -(safeY * 1024.0),
          'resourceType': resourceType,
        }),
      )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final String label = resourceType == 'roaming_oak' ? '참나무' : '형광석';
        _showFloatingSnackBarMessage('오늘 $label 위치가 확정되었어요.');
        await _loadResources();
        return;
      }

      final String body = utf8.decode(response.bodyBytes).trim();
      _showFloatingSnackBarMessage(
        body.isNotEmpty ? body : '위치 확정에 실패했어요. (${response.statusCode})',
      );
    } on TimeoutException {
      if (!mounted) return;
      _showFloatingSnackBarMessage('서버 응답이 지연되고 있어요. 잠시 후 다시 시도해주세요.');
    } catch (e) {
      if (!mounted) return;
      _showFloatingSnackBarMessage('위치 확정 중 오류가 발생했어요: $e');
    }
  }

  void _showAdminLocationConfirmSheet(double x, double y) {
    if (!widget.isAdmin) return;

    final double safeX = x.clamp(0.0, 1.0).toDouble();
    final double safeY = y.clamp(0.0, 1.0).toDouble();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _buildUnifiedSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHandle(),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFD8CF)),
                    ),
                    child: const Icon(
                      Icons.add_location_alt_rounded,
                      color: Color(0xFFFF8E7C),
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '오늘 위치로 지정',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'x ${safeX.toStringAsFixed(4)} · y ${safeY.toStringAsFixed(4)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '지정할 자원을 선택하면 해당 좌표가 오늘의 확정 위치로 등록돼요.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildAdminLocationSelectButton(
                      title: '참나무',
                      subtitle: '그 자리 참나무',
                      iconPath: 'assets/images/resources/roaming-oak.png',
                      accent: const Color(0xFFFF8E7C),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _confirmAdminLocation(safeX, safeY, 'roaming_oak');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAdminLocationSelectButton(
                      title: '형광석',
                      subtitle: '완벽한 형광석',
                      iconPath: 'assets/images/resources/fluorite.png',
                      accent: const Color(0xFF5DBFEA),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _confirmAdminLocation(safeX, safeY, 'fluorite');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminLocationSelectButton({
    required String title,
    required String subtitle,
    required String iconPath,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.28)),
                ),
                child: Image.asset(
                  iconPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.help_outline_rounded,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVoteNoticeTemporarily() {
    _voteNoticeTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _showVoteNoticeBar = true;
    });

    _voteNoticeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showVoteNoticeBar = false;
      });
    });
  }

  void _toggleFilterPanel() {
    setState(() {
      _isFilterPanelOpen = !_isFilterPanelOpen;
    });
  }

  void _closeFilterPanel() {
    if (!_isFilterPanelOpen) return;
    setState(() {
      _isFilterPanelOpen = false;
    });
  }

  void _showSpawnPointDetail(SpawnPointModel point) {
    final oak = point.oak;
    final fluorite = point.fluorite;

    final bool oakVerified = point.resources.any(
          (res) => res.resourceName == 'roaming_oak' && res.isVerified,
    );

    final bool fluoriteVerified = point.resources.any(
          (res) => res.resourceName == 'fluorite' && res.isVerified,
    );

    final bool pointVerified = oakVerified || fluoriteVerified;

    final String pointLabel =
    point.placeLabel?.trim().isNotEmpty == true
        ? point.placeLabel!.trim()
        : '위치 확인 중';

    String descriptionText;
    if (oakVerified && fluoriteVerified) {
      descriptionText = '참나무와 형광석이 모두 $pointLabel에 있어요!';
    } else if (oakVerified) {
      descriptionText = '참나무는 $pointLabel에 있어요!';
    } else if (fluoriteVerified) {
      descriptionText = '형광석은 $pointLabel에 있어요!';
    } else {
      descriptionText = '게임에서 확인한 형광석, 참나무 위치에 투표해 주세요.';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildUnifiedSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSheetHandle(),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFFFE1D9),
                    ),
                  ),
                  child: _buildSpawnPointBottomSheetIcon(point),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.isOakOnly ? '참나무 후보 위치' : '참나무/형광석 후보 위치',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        descriptionText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A8A9A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (oak != null) buildVoteCard(oak),
            if (fluorite != null) buildVoteCard(fluorite),
            if (oak == null && fluorite == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE7EDF5)),
                ),
                child: const Text(
                  '표시할 후보 자원이 없어요.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _normalizeSpawnResourceKey(SpawnResourceModel res) {
    return res.resourceName;
  }

  String _getDisplayName(String filterKey) {
    switch (filterKey) {
      case 'roaming_oak':
        return '그 자리 참나무';
      case 'fluorite':
        return '완벽한 형광석';
      default:
        final sample = _getRepresentativeByFilterKey(filterKey);
        return sample?.koName ?? filterKey;
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

  void _showFixedResourceDetail(ResourceModel res) {
    final bool isNpc = res.category == 'npc';
    final bool isAnimal = res.category == 'animal';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildUnifiedSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSheetHandle(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isAnimal
                          ? const Color(0xFFD9EEFF)
                          : const Color(0xFFFFDDD7),
                      width: 1.4,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      res.iconPath,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                      const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        res.koName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isAnimal
                              ? const Color(0xFFEFF8FF)
                              : const Color(0xFFFFF4F1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isAnimal
                              ? '동물 친구'
                              : isNpc
                              ? '마을 주민'
                              : '위치 정보',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isAnimal
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFFF8E7C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE7EDF5)),
              ),
              child: Text(
                (res.description ?? '').trim().isEmpty
                    ? '아직 등록된 설명이 없어요.'
                    : res.description!.trim(),
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ResourceModel? _getRepresentativeByFilterKey(String filterKey) {
    try {
      return _fixedResources.firstWhere(
            (r) => _normalizeFilterKey(r) == filterKey,
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _getDistinctNamesByCategory(List<String> categories) {
    final fixedKeys = _fixedResources
        .where((res) => categories.contains(res.category))
        .map((res) => _normalizeFilterKey(res));

    final spawnKeys = _spawnPoints
        .expand((point) => point.resources)
        .where((res) {
      if (categories.contains('tree') && res.resourceName == 'roaming_oak') {
        return true;
      }
      if (categories.contains('mineral') && res.resourceName == 'fluorite') {
        return true;
      }
      return false;
    })
        .map((res) => _normalizeSpawnResourceKey(res));

    final Set<String> result = {
      ...fixedKeys,
      ...spawnKeys,
    };

    // ✅ 응답 상태와 상관없이 필터 칩은 항상 보이게
    if (categories.contains('tree')) {
      result.add('roaming_oak');
    }
    if (categories.contains('mineral')) {
      result.add('fluorite');
    }

    return result.toList()
      ..sort((a, b) => _getDisplayName(a).compareTo(_getDisplayName(b)));
  }

  String _normalizeFilterKey(ResourceModel res) {
    return res.resourceName;
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

  bool _isSpawnPointVisible(SpawnPointModel point) {
    if (!point.hasAnyActiveResource) return false;

    final hasVisibleResource = point.resources.any((res) {
      final key = _normalizeSpawnResourceKey(res);
      return _enabledResources.contains(key);
    });

    return hasVisibleResource;
  }

  bool _isVisibleOnMap(ResourceModel res) {
    if (res.category == 'npc') return _showAllNpcs;
    if (res.category == 'animal') return _showAllAnimals;
    if (res.category == 'location') return false;

    return _enabledResources.contains(_normalizeFilterKey(res));
  }

  List<ResourceModel> _findNearbyCharacters(
      ResourceModel target, {
        double threshold = 0.022,
      }) {
    final List<ResourceModel> nearby = _fixedResources.where((res) {
      final bool isCharacter = res.category == 'npc' || res.category == 'animal';
      if (!isCharacter) return false;
      if (!_isVisibleOnMap(res)) return false;

      final double dx = res.x - target.x;
      final double dy = res.y - target.y;
      final double distanceSquared = dx * dx + dy * dy;
      return distanceSquared <= threshold * threshold;
    }).toList();

    nearby.sort((a, b) {
      final double da =
          math.pow(a.x - target.x, 2).toDouble() +
              math.pow(a.y - target.y, 2).toDouble();
      final double db =
          math.pow(b.x - target.x, 2).toDouble() +
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
        _selectedFixedResourceId = res.id;
      });
      _showFixedResourceDetail(res);
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
      isScrollControlled: true,
      builder: (context) => _buildUnifiedSheet(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.62,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHandle(),
              const Text(
                '겹쳐 있는 캐릭터',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '선택할 캐릭터를 눌러 주세요.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final res = items[index];
                    final bool isAnimal = res.category == 'animal';
                    final bool isTapped = res.id == tapped.id;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedFixedResourceId = res.id;
                          });
                          _showFixedResourceDetail(res);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isTapped
                                ? const Color(0xFFFFF7F5)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isTapped
                                  ? accentColor.withOpacity(0.35)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isAnimal
                                        ? const Color(0xFFD9EEFF)
                                        : const Color(0xFFFFDDD7),
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
                                    const SizedBox(height: 3),
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
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<BoxShadow> _softShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isAccent = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isAccent
                ? const Color(0xFFFF8E7C)
                : Colors.white.withOpacity(0.90),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAccent
                  ? const Color(0xFFFF8E7C)
                  : Colors.white.withOpacity(0.75),
              width: 1,
            ),
            boxShadow: _softShadow,
          ),
          child: Icon(
            icon,
            size: 22,
            color: isAccent ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildMapHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.9),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 21,
            color: const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedSheet({required Widget child}) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.98),
              const Color(0xFFFFFBFA),
            ],
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
            BoxShadow(
              color: const Color(0xFFFF8E7C).withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildVoteCard(SpawnResourceModel res) {
    final bool canVote = !res.isVerified && !res.alreadyVotedSameType;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFFFFAF8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFE7E1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8E7C).withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3EF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFFFDED6),
              ),
            ),
            child: Image.asset(
              res.iconPath,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) =>
              const Icon(Icons.help_outline_rounded, size: 18),
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
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  res.isVerified
                      ? '오늘 위치가 확정되었어요'
                      : res.alreadyVotedSameType
                      ? '이미 같은 종류에 투표했어요'
                      : '현재 ${res.voteCount}표 모였어요',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7A8A9A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: canVote ? () => _handleVote(res) : null,
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: canVote
                      ? const Color(0xFFFF8E7C)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: canVote
                      ? [
                    BoxShadow(
                      color: const Color(0xFFFF8E7C).withOpacity(0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                      : null,
                ),
                child: Text(
                  res.isVerified
                      ? '확정'
                      : res.alreadyVotedSameType
                      ? '완료'
                      : '투표',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: canVote
                        ? Colors.white
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        width: 54,
        height: 6,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFD6CD),
              const Color(0xFFFFB3A3),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
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
    final bool isEnabled = _enabledResources.contains(resourceName);
    final ResourceModel? sampleRes = _getRepresentativeByFilterKey(resourceName);

    String? fallbackIconPath;
    if (resourceName == 'roaming_oak') {
      fallbackIconPath = 'assets/images/resources/roaming-oak.png';
    } else if (resourceName == 'fluorite') {
      fallbackIconPath = 'assets/images/resources/fluorite.png';
    }

    return GestureDetector(
      onTap: () => _toggleResource(resourceName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isEnabled
              ? const Color(0xFFFFF4F1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEnabled
                ? const Color(0xFFFF8E7C)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sampleRes != null || fallbackIconPath != null)
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                child: Image.asset(
                  sampleRes?.iconPath ?? fallbackIconPath!,
                  width: 14,
                  height: 14,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.image_not_supported_outlined,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    );
                  },
                ),
              )
            else
              const Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            const SizedBox(width: 5),
            Text(
              _getDisplayName(resourceName),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isEnabled
                    ? const Color(0xFFFF8E7C)
                    : const Color(0xFF475569),
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
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items.map((item) => _buildMapFilterChip(item)).toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildMapFilterPanel() {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    final mobileResourceItems = <String>[
      if (_getDistinctNamesByCategory(['tree']).contains('roaming_oak'))
        'roaming_oak',
      if (_getDistinctNamesByCategory(['mineral']).contains('fluorite'))
        'fluorite',
    ];

    final gatherItems = _getDistinctNamesByCategory([
      'fruit',
      'bubble',
      'material',
    ]);

    final mushroomItems = _getDistinctNamesByCategory(['mushroom']);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 340),
      curve: _isFilterPanelOpen
          ? Curves.easeOutQuad
          : Curves.easeInCubic,
      top: topPadding + 72,
      right: _isFilterPanelOpen ? 12 : -320,
      child: IgnorePointer(
        ignoring: !_isFilterPanelOpen,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          opacity: _isFilterPanelOpen ? 1 : 0.96,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 286,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height
                    - topPadding
                    - bottomPadding
                    - 120,
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.992),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFF0E3DC),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.09),
                    blurRadius: 22,
                    offset: const Offset(-4, 10),
                  ),
                  BoxShadow(
                    color: const Color(0xFFFF8E7C).withOpacity(0.045),
                    blurRadius: 14,
                    offset: const Offset(-2, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          '정렬 및 필터',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF443834),
                          ),
                        ),
                      ),
                      _buildMapPanelIconButton(
                        icon: Icons.refresh_rounded,
                        onTap: () {
                          _resetFiltersToDefault();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('필터가 기본값으로 초기화됐어요.'),
                              duration: Duration(milliseconds: 1400),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildMapPanelIconButton(
                        icon: Icons.close_rounded,
                        onTap: _closeFilterPanel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '필터',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6E625D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCompactTogglePair(),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _buildMapFilterSection(
                            title: '유동 자원',
                            items: mobileResourceItems,
                          ),
                          const SizedBox(height: 12),
                          _buildMapFilterSection(
                            title: '채집 자원',
                            items: gatherItems,
                          ),
                          const SizedBox(height: 12),
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
          ),
        ),
      ),
    );
  }

  Widget _buildMapPanelIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFFFF8F5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFF2E3DC),
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: const Color(0xFFFF8E7C),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTogglePair() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _buildCompactToggleCard(
            icon: Icons.people_alt_outlined,
            title: 'NPC',
            value: _showAllNpcs,
            onTap: () {
              setState(() {
                _showAllNpcs = !_showAllNpcs;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCompactToggleCard(
            icon: Icons.pets_outlined,
            title: '동물',
            value: _showAllAnimals,
            onTap: () {
              setState(() {
                _showAllAnimals = !_showAllAnimals;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompactToggleCard({
    required IconData icon,
    required String title,
    required bool value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: value
                ? const Color(0xFFFFF2EF)
                : const Color(0xFFFFFBFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: value
                  ? const Color(0xFFFFD8CF)
                  : const Color(0xFFF0E3DC),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFF8E7C).withOpacity(
                  value ? 0.10 : 0.04,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: value
                    ? const Color(0xFFFF8E7C)
                    : const Color(0xFF7B6D64),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: value
                        ? const Color(0xFFFF8E7C)
                        : const Color(0xFF7B6D64),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildMiniSwitch(value: value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSwitch({required bool value}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 34,
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFFFF8E7C).withOpacity(0.55)
            : const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  void _resetFiltersToDefault() {
    final fixedKeys = _fixedResources
        .where(
          (res) =>
      res.category != 'npc' &&
          res.category != 'animal' &&
          res.category != 'location' &&
          !res.isFixed &&
          _normalizeFilterKey(res) != 'gold_bubble',
    )
        .map((res) => _normalizeFilterKey(res));

    final spawnKeys = _spawnPoints
        .expand((point) => point.resources)
        .map((res) => _normalizeSpawnResourceKey(res));

    const defaultVoteKeys = {
      'roaming_oak',
      'fluorite',
    };

    setState(() {
      _enabledResources = {
        ...fixedKeys,
        ...spawnKeys,
        ...defaultVoteKeys,
      };

      _showAllNpcs = true;
      _showAllAnimals = false;
    });
  }

  Widget _buildSpawnPointBottomSheetIcon(SpawnPointModel point) {
    if (point.isBothVerified) {
      return Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 28,
            color: Color(0xFFFF8E7C),
          ),
          Positioned(
            left: 2,
            bottom: 2,
            child: Image.asset(
              'assets/images/resources/roaming-oak.png',
              width: 16,
              height: 16,
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: Image.asset(
              'assets/images/resources/fluorite.png',
              width: 16,
              height: 16,
            ),
          ),
        ],
      );
    }

    if (point.isOakVerified && point.oak != null) {
      return Image.asset(point.oak!.iconPath, width: 28, height: 28);
    }

    if (point.isFluoriteVerified && point.fluorite != null) {
      return Image.asset(point.fluorite!.iconPath, width: 28, height: 28);
    }

    return const Icon(
      Icons.question_mark_rounded,
      size: 22,
      color: Color(0xFFFF8E7C),
    );
  }

  Widget _buildSpawnPointPinImage(SpawnPointModel point) {
    // 둘 다 확정
    if (point.isBothVerified) {
      return Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 30,
            color: Color(0xFFFF8E7C),
          ),
          Positioned(
            left: 1,
            bottom: 2,
            child: Image.asset(
              'assets/images/resources/roaming-oak.png',
              width: 16,
              height: 16,
            ),
          ),
          Positioned(
            right: 1,
            top: 2,
            child: Image.asset(
              'assets/images/resources/fluorite.png',
              width: 16,
              height: 16,
            ),
          ),
        ],
      );
    }

    // 참나무 확정
    if (point.isOakVerified && point.oak != null) {
      return Image.asset(point.oak!.iconPath, width: 28, height: 28);
    }

    // 형광석 확정
    if (point.isFluoriteVerified && point.fluorite != null) {
      return Image.asset(point.fluorite!.iconPath, width: 28, height: 28);
    }

    // ⭐ 투표 전 (물음표 아이콘)
    return const Icon(
      Icons.question_mark_rounded,
      size: 26,
      color: Color(0xFFFF8E7C),
    );
  }

  Widget _buildFloatingMapHeader() {
    return Column(
      children: [
        Row(
          children: [
            _buildMapGlassIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.88),
                      const Color(0xFFFFF6F3).withOpacity(0.92),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFFE4DE),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF8E7C).withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 18),
                    Spacer(),
                    Icon(
                      Icons.map_rounded,
                      size: 18,
                      color: Color(0xFFFF8E7C),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '지도',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334155),
                      ),
                    ),
                    Spacer(),
                    SizedBox(width: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),

            _buildMapGlassIconButton(
              icon: Icons.tune_rounded,
              onTap: _toggleFilterPanel,
            ),
          ],
        ),

        const SizedBox(height: 10),

        _buildVoteNoticeFloatingBar(),
      ],
    );
  }

  Widget _buildVoteNoticeFloatingBar() {
    String noticeText;

    if (_isTodayLocationVerified) {
      final List<String> parts = [];

      if (_todayOakLocationLabel.trim().isNotEmpty) {
        parts.add('참나무는 ${_todayOakLocationLabel.trim()}');
      }

      if (_todayFluoriteLocationLabel.trim().isNotEmpty) {
        parts.add('형광석은 ${_todayFluoriteLocationLabel.trim()}');
      }

      if (parts.isEmpty) {
        noticeText = '오늘의 자원 위치가 확정되었어요!';
      } else {
        noticeText = '${parts.join(', ')}에 있어요!';
      }
    } else {
      noticeText = '오늘의 자원 위치에 투표해 주세요!';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double fullWidth = constraints.maxWidth;

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 0,
            end: _showVoteNoticeBar ? 1 : 0,
          ),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, factor, _) {
            final double slideX = (1 - factor) * -18;
            final double opacity =
            Curves.easeOut.transform(factor).clamp(0.0, 1.0);
            final double scale = 0.985 + (0.015 * factor);

            return ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: factor,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(slideX, 0),
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: fullWidth,
                        child: Container(
                          height: 44, // ✅ 고정 높이로 변경
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.88),
                                const Color(0xFFFFF6F3).withOpacity(0.92),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFFFE4DE),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: const Color(0xFFFF8E7C).withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1ED),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFFFE1D9),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.campaign_rounded,
                                  size: 14,
                                  color: Color(0xFFFF8E7C),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  noticeText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showVoteNoticeBar = false;
                                  });
                                },
                                child: const Text(
                                  '닫기',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFF8E7C),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFFE4DE),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFFFF8E7C).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 22,
            color: const Color(0xFFFF8E7C),
          ),
        ),
      ),
    );
  }

  Widget _buildNpcMarker(ResourceModel res, {bool isAnimal = false}) {
    return _buildCircleMarker(
      iconPath: res.iconPath,
      borderColor: isAnimal
          ? const Color(0xFF38BDF8) // 동물
          : const Color(0xFF3B82F6), // NPC
      isSelected: _selectedFixedResourceId == res.id,
      size: 28,
      fit: BoxFit.cover,
      padding: const EdgeInsets.all(2),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.88),
                const Color(0xFFFFF6F3).withOpacity(0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withOpacity(0.72),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: const Color(0xFFFF8E7C).withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMapZoomActionButton(
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
              _buildZoomDivider(),
              _buildMapZoomActionButton(
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
              _buildZoomDivider(),
              _buildMapZoomActionButton(
                icon: Icons.refresh_rounded,
                onTap: () => _resetToMinimumScale(constraints, mapSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapZoomActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFFE4DE),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF5F6F82),
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildZoomDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: 24,
      height: 1,
      color: const Color(0xFFFFE6E0),
    );
  }


  String _resolveSpawnPointVisualIconPath(SpawnPointModel point) {
    final oak = point.oak;
    final fluorite = point.fluorite;

    final bool oakFocused = oak != null &&
        (point.isOakVerified || oak.isVerified || oak.isFixed || oak.votedByMe);
    final bool fluoriteFocused = fluorite != null &&
        (point.isFluoriteVerified ||
            fluorite.isVerified ||
            fluorite.isFixed ||
            fluorite.votedByMe);

    if (fluoriteFocused && !oakFocused) {
      return fluorite.iconPath;
    }

    if (oakFocused && !fluoriteFocused) {
      return oak.iconPath;
    }

    if (oak != null && fluorite == null) {
      return oak.iconPath;
    }

    if (fluorite != null && oak == null) {
      return fluorite.iconPath;
    }

    return oak?.iconPath ??
        fluorite?.iconPath ??
        'assets/images/default.png';
  }

  Color _resolveSpawnPointVisualBorderColor(SpawnPointModel point) {
    final oak = point.oak;
    final fluorite = point.fluorite;

    final bool hasOak = oak != null;
    final bool hasFluorite = fluorite != null;

    final bool oakFocused = oak != null &&
        (point.isOakVerified || oak.isVerified || oak.isFixed || oak.votedByMe);
    final bool fluoriteFocused = fluorite != null &&
        (point.isFluoriteVerified ||
            fluorite.isVerified ||
            fluorite.isFixed ||
            fluorite.votedByMe);

    if (fluoriteFocused && !oakFocused) {
      return const Color(0xFF8ED6FF);
    }

    if (oakFocused && !fluoriteFocused) {
      return const Color(0xFFFF8E7C);
    }

    if (hasOak && hasFluorite) {
      return const Color(0xFFBFA2FF);
    }

    if (hasOak) {
      return const Color(0xFFFF8E7C);
    }

    return const Color(0xFF8ED6FF);
  }

  Widget _buildSpawnPointMarker(SpawnPointModel point, double mapSize) {
    const double markerSize = 36;
    final double markerScale = (1 / _currentScale).clamp(0.3, 1.0);

    final bool hasOak = point.oak != null;
    final bool hasFluorite = point.fluorite != null;
    final bool isSelected = _selectedSpawnPointId == point.id;
    final bool isVerified = point.isOakVerified || point.isFluoriteVerified;

    final Color borderColor = isSelected
        ? accentColor
        : _resolveSpawnPointVisualBorderColor(point);

    final String iconPath = _resolveSpawnPointVisualIconPath(point);

    return Positioned(
      left: (point.x * mapSize) - (markerSize / 2),
      top: (point.y * mapSize) - (markerSize / 2),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSpawnPointId = point.id;
            _selectedFixedResourceId = null;
          });
          _showSpawnPointDetail(point);
        },
        child: Transform.scale(
          scale: markerScale,
          alignment: Alignment.center,
          child: _buildCircleMarker(
            borderColor: borderColor,
            isSelected: isSelected,
            size: 28,
            fit: BoxFit.contain,
            padding: const EdgeInsets.all(4),
            child: (!isVerified && !isSelected)
                ? Center(
              child: Text(
                '❓',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,   // ← 16 → 13로 줄임
                  height: 1.0,    // ← 이게 핵심 (baseline 보정)
                  fontWeight: FontWeight.w900,
                  color: borderColor,
                ),
              ),
            )
                : Image.asset(
              iconPath,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: borderColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFixedResourceMarker(ResourceModel res, double mapSize) {
    const double markerSize = 36;
    final double markerScale = (1 / _currentScale).clamp(0.3, 1.0);

    return Positioned(
      left: (res.x * mapSize) - (markerSize / 2),
      top: (res.y * mapSize) - (markerSize / 2),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFixedResourceId = res.id;
            _selectedSpawnPointId = null;
          });

          if (res.category == 'npc' || res.category == 'animal') {
            _handleCharacterTap(res);
          } else {
            _showFixedResourceDetail(res);
          }
        },
        child: Transform.scale(
          scale: markerScale,
          alignment: Alignment.center,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 160),
            scale: _selectedFixedResourceId == res.id ? 1.08 : 1.0,
            child: res.category == 'npc'
                ? _buildNpcMarker(res)
                : res.category == 'animal'
                ? _buildNpcMarker(res, isAnimal: true)
                : _buildCircleMarker(
              iconPath: res.iconPath,
              borderColor: const Color(0xFFFF8E7C), // 일반 자원
              isSelected: _selectedFixedResourceId == res.id,
              size: 28,
              fit: BoxFit.cover,
              padding: const EdgeInsets.all(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleMarker({
    String? iconPath,
    Widget? child,
    required Color borderColor,
    required bool isSelected,
    double size = 28,
    BoxFit fit = BoxFit.cover,
    EdgeInsets padding = const EdgeInsets.all(2),
  }) {
    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: isSelected ? 2.8 : 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isSelected ? 0.22 : 0.14),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: Colors.white,
          alignment: Alignment.center,
          child: child ??
              Image.asset(
                iconPath ?? '',
                fit: fit,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.image_not_supported_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: true,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: seaColor,
        drawerScrimColor: Colors.black.withOpacity(0.2),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : LayoutBuilder(
          builder: (context, constraints) {
            final double mapSize =
                constraints.maxWidth * _baseMapWidthFactor;
            _applyInitialTransform(constraints, mapSize);

            final visibleFixedResources = _fixedResources
                .where((res) => _isVisibleOnMap(res))
                .toList();

            final visibleSpawnPoints = _spawnPoints
                .where((point) => _isSpawnPointVisible(point))
                .toList();

            visibleFixedResources.sort((a, b) {
              final int aPriority =
              a.id == _selectedFixedResourceId ? 1 : 0;
              final int bPriority =
              b.id == _selectedFixedResourceId ? 1 : 0;
              return aPriority.compareTo(bPriority);
            });

            visibleSpawnPoints.sort((a, b) {
              final int aPriority =
              a.id == _selectedSpawnPointId ? 1 : 0;
              final int bPriority =
              b.id == _selectedSpawnPointId ? 1 : 0;
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

                      onLongPressStart: (details) {
                        if (!widget.isAdmin) return;

                        final Offset scenePoint =
                        _transformationController.toScene(details.localPosition);

                        final double x = (scenePoint.dx / mapSize).clamp(0.0, 1.0).toDouble();
                        final double y = (scenePoint.dy / mapSize).clamp(0.0, 1.0).toDouble();

                        _showAdminLocationConfirmSheet(x, y);
                      },

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
                          final newScale = _clampScale(
                            matrix.getMaxScaleOnAxis(),
                          );

                          if ((newScale - _minMapScale).abs() < 0.001) {
                            _forceCenterAtMinimumScale(
                              constraints,
                              mapSize,
                            );
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
                            _forceCenterAtMinimumScale(
                              constraints,
                              mapSize,
                            );
                          }
                        },
                        child: SizedBox(
                          width: mapSize,
                          height: mapSize,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/map_background.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                              _buildPlaceLabels(mapSize),
                              ...visibleFixedResources.map(
                                    (res) => _buildFixedResourceMarker(
                                  res,
                                  mapSize,
                                ),
                              ),
                              ...visibleSpawnPoints.map(
                                    (point) => _buildSpawnPointMarker(
                                  point,
                                  mapSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  top: MediaQuery.of(context).padding.top + 12,
                  child: _buildFloatingMapHeader(),
                ),
                Positioned(
                  right: 16,
                  bottom: bottomPadding + 20,
                  child: _buildZoomButtons(constraints, mapSize),
                ),
                if (widget.isAdmin)
                  Positioned(
                    left: 20,
                    bottom: bottomPadding + 24,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: const Text(
                          '관리자: 길게 눌러 오늘 위치 지정',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_isFilterPanelOpen,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      opacity: _isFilterPanelOpen ? 1 : 0,
                      child: GestureDetector(
                        onTap: _closeFilterPanel,
                        child: Container(
                          color: Colors.black.withOpacity(0.18),
                        ),
                      ),
                    ),
                  ),
                ),

                _buildMapFilterPanel(),
              ],
            );
          },
        ),
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

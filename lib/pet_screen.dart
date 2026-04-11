import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

import 'manage_pet_screen.dart';
import 'models/global_search_item.dart';
import 'models/pet_model.dart';
import 'setting_screen.dart';

class PetScreen extends StatefulWidget {
  final VoidCallback? openDrawer;
  final GlobalSearchItem? initialSearchItem;

  const PetScreen({
    super.key,
    this.openDrawer,
    this.initialSearchItem,
  });

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  ScrollController _getCurrentPetScrollController() {
    final index = _tabController.index.clamp(0, 1);
    return index == 0 ? _catScrollController : _dogScrollController;
  }

  final TextEditingController _searchController = TextEditingController();
  bool _isFilterVisible = true;
  bool _showMyPetProfiles = false;
  final Set<String> _likedPetCardIds = {};

  final ScrollController _catScrollController = ScrollController();
  final ScrollController _dogScrollController = ScrollController();
  bool _showTopBtn = false;

  String _selectedColor = '전체';
  String _selectedEyeType = '전체';
  bool _isMenuOpen = false;
  bool _isSubmitting = false;

  final TextEditingController _snackSearchController =
  TextEditingController();
  final ScrollController _snackFishScrollController = ScrollController();

  String _snackSearchQuery = '';
  String? _submittedSnackQuery;
  String? _highlightedSnackFishId;

  List<Pet> _allPets = [];
  List<FishItem> _fishList = [];
  bool _isLoading = true;
  String? _kakaoId;

  final String _petApiUrl = 'http://161.33.30.40:8080/api/pets';
  final String _fishApiUrl = 'http://161.33.30.40:8080/api/fish';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    _attachScrollListener(_catScrollController);
    _attachScrollListener(_dogScrollController);

    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _catScrollController.dispose();
    _dogScrollController.dispose();
    _snackSearchController.dispose();
    _snackFishScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadUserInfo();
    await _fetchFishData();
    if (_kakaoId != null) {
      await _fetchPetData();
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await UserApi.instance.me();
      if (mounted) {
        setState(() => _kakaoId = user.id.toString());
      }
    } catch (e) {
      debugPrint('사용자 정보 로드 실패: $e');
    }
  }

  Future<void> _fetchPetData() async {
    if (_kakaoId == null) return;

    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final response = await http.get(
        Uri.parse('$_petApiUrl/user/$_kakaoId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data =
        jsonDecode(utf8.decode(response.bodyBytes));

        if (!mounted) return;

        setState(() {
          _allPets = data.map(
                (json) => Pet(
              id: json['id'],
              name: json['name'],
              breed: json['breed'],
              isCat: json['isCat'] ?? true,
              imagePath: json['imagePath'],
              favoriteSnack: json['favoriteSnack'] ?? '',
              triedSnacks: Set<String>.from(json['triedSnacks'] ?? []),
              sortOrder: json['sortOrder'],
              color: (json['color'] ?? '전체').toString(),
              eyeType: (json['eyeType'] ?? '전체').toString(),
            ),
          ).toList();

          _allPets.sort(
                (a, b) => (b.id ?? 0).compareTo(a.id ?? 0),
          );
        });
      }
    } catch (e) {
      debugPrint('반려동물 데이터 로드 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchFishData() async {
    try {
      final response = await http.get(Uri.parse(_fishApiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data =
        jsonDecode(utf8.decode(response.bodyBytes));

        if (mounted) {
          setState(() {
            _fishList = data
                .map((e) => FishItem.fromJson(e))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('물고기 데이터 로드 에러: $e');
    }
  }

  Future<void> _updatePetOrderOnServer() async {
    if (_kakaoId == null || _allPets.isEmpty) return;

    final List<int> petIds = _allPets
        .where((p) => p.id != null)
        .map((p) => p.id!)
        .toList();

    if (petIds.isEmpty) return;

    try {
      final response = await http.put(
        Uri.parse('$_petApiUrl/reorder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(petIds),
      );

      if (response.statusCode != 200) {
        debugPrint('순서 저장 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('순서 저장 에러: $e');
    }
  }

  Future<void> _savePetToServer(
      String name,
      String breed,
      String? imagePath, {
        int? existingId,
      }) async {
    if (_kakaoId == null) return;

    try {
      final Map<String, dynamic> petData = {
        'kakaoId': int.parse(_kakaoId!),
        'name': name,
        'breed': breed,
        'isCat': _tabController.index == 0,
        'imagePath': imagePath,
      };

      http.Response response;

      if (existingId == null) {
        response = await http.post(
          Uri.parse(_petApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            ...petData,
            'favoriteSnack': '',
            'triedSnacks': [],
          }),
        );
      } else {
        response = await http.put(
          Uri.parse('$_petApiUrl/$existingId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(petData),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchPetData();
      }
    } catch (e) {
      debugPrint('저장/수정 실패: $e');
    }
  }

  Future<void> _updatePetSnacks(Pet pet) async {
    if (_kakaoId == null || pet.id == null) return;

    try {
      await http.put(
        Uri.parse('$_petApiUrl/${pet.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'kakaoId': int.parse(_kakaoId!),
          'name': pet.name,
          'breed': pet.breed,
          'isCat': pet.isCat,
          'imagePath': pet.imagePath,
          'favoriteSnack': pet.favoriteSnack,
          'triedSnacks': pet.triedSnacks.toList(),
        }),
      );
    } catch (e) {
      debugPrint('간식 업데이트 실패: $e');
    }
  }

  Future<void> _deletePetFromServer(int petId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_petApiUrl/$petId'),
      );

      if (response.statusCode == 200) {
        await _fetchPetData();
      }
    } catch (e) {
      debugPrint('삭제 실패: $e');
    }
  }

  void _scrollToTop() {
    final controller = _getCurrentPetScrollController();
    if (!controller.hasClients) return;

    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );

    if (!_isFilterVisible) {
      setState(() => _isFilterVisible = true);
    }
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

  String _imageAssetPath(String? image) {
    if (image == null || image.isEmpty) {
      return 'assets/images/default.png';
    }

    String fullPath =
    image.startsWith('assets/') ? image : 'assets/$image';

    final lower = fullPath.toLowerCase();
    if (!lower.endsWith('.webp') &&
        !lower.endsWith('.png') &&
        !lower.endsWith('.jpg') &&
        !lower.endsWith('.jpeg')) {
      fullPath = '$fullPath.webp';
    }

    return fullPath;
  }

  String _displayFishName(FishItem fish) {
    final ko = fish.nameKo?.trim();
    if (ko != null && ko.isNotEmpty) return ko;
    return fish.name.trim();
  }

  List<FishItem> _sortedFishListByName() {
    final list = List<FishItem>.from(_fishList);
    list.sort(
          (a, b) => _displayFishName(a).compareTo(_displayFishName(b)),
    );
    return list;
  }

  List<String> _snackSearchTokens(String query) {
    return query
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  int _snackMatchScore(FishItem fish, String query) {
    final tokens = _snackSearchTokens(query);
    if (tokens.isEmpty) return 0;

    final displayName = _displayFishName(fish).toLowerCase();
    final nameKo = (fish.nameKo ?? '').trim().toLowerCase();
    final name = fish.name.trim().toLowerCase();
    final id = fish.id.trim().toLowerCase().replaceAll('_', ' ');

    int score = 0;

    for (final token in tokens) {
      if (displayName == token) score += 120;
      if (nameKo == token) score += 110;
      if (name == token) score += 100;
      if (id == token) score += 95;

      if (displayName.startsWith(token)) score += 60;
      if (nameKo.startsWith(token)) score += 55;
      if (name.startsWith(token)) score += 50;
      if (id.startsWith(token)) score += 45;

      if (displayName.contains(token)) score += 24;
      if (nameKo.contains(token)) score += 22;
      if (name.contains(token)) score += 20;
      if (id.contains(token)) score += 18;
    }

    return score;
  }

  List<FishItem> _buildVisibleSnackFishList() {
    final query = _snackSearchQuery.trim();

    if (query.isEmpty) {
      return _sortedFishListByName();
    }

    final filtered = _fishList
        .where((fish) => _snackMatchScore(fish, query) > 0)
        .toList();

    filtered.sort((a, b) {
      final scoreCompare = _snackMatchScore(b, query)
          .compareTo(_snackMatchScore(a, query));
      if (scoreCompare != 0) return scoreCompare;
      return _displayFishName(a).compareTo(_displayFishName(b));
    });

    return filtered;
  }

  void _clearSnackHighlightLater(String fishId) {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_highlightedSnackFishId == fishId) {
        setState(() => _highlightedSnackFishId = null);
      }
    });
  }

  void _scrollSnackFishToTop(String fishId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_snackFishScrollController.hasClients) return;

      final visibleFishList = _buildVisibleSnackFishList();
      final index = visibleFishList.indexWhere(
            (fish) => fish.id == fishId,
      );

      if (index < 0) return;

      _snackFishScrollController.animateTo(
        index * 104.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _submitSnackSearch(StateSetter setSheetState) {
    final query = _snackSearchController.text.trim();

    setSheetState(() {
      _snackSearchQuery = query;
      _submittedSnackQuery = query;
    });

    final visibleFishList = _buildVisibleSnackFishList();
    if (visibleFishList.isEmpty) return;

    final targetFish = visibleFishList.first;

    setSheetState(() => _highlightedSnackFishId = targetFish.id);
    _scrollSnackFishToTop(targetFish.id);
    _clearSnackHighlightLater(targetFish.id);
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final double appBarHeight = topPadding + 170;

    final double scrollTopBottom = keyboardInset > 0
        ? 24
        : safeBottom + 88;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      floatingActionButton: _buildFabWithMenu(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
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

                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _showMyPetProfiles
                      ? Column(
                    children: [
                      _buildPetProfileInlinePanel(),
                      const SizedBox(height: 4),
                    ],
                  )
                      : const SizedBox.shrink(),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildTabContent(isCat: true),
                      _buildTabContent(isCat: false),
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
            bottom: scrollTopBottom,
            child: _buildScrollToTopButton(),
          ),
        ],
      ),
    );
  }

  String _getPetColor(Pet pet) {
    final breed = pet.breed.toLowerCase();
    final name = pet.name.toLowerCase();
    final image = (pet.imagePath ?? '').toLowerCase();

    final source = '$breed $name $image';

    if (source.contains('white') || source.contains('흰') || source.contains('화이트')) {
      return '화이트';
    }
    if (source.contains('black') || source.contains('검') || source.contains('블랙')) {
      return '블랙';
    }
    if (source.contains('cheese') || source.contains('치즈') || source.contains('yellow') || source.contains('노랑')) {
      return '치즈';
    }
    if (source.contains('tabby') || source.contains('얼룩') || source.contains('stripe') || source.contains('줄무늬')) {
      return '얼룩';
    }
    if (source.contains('tricolor') || source.contains('calico') || source.contains('삼색')) {
      return '삼색';
    }

    return '기타';
  }

  String _getPetEyeType(Pet pet) {
    final breed = pet.breed.toLowerCase();
    final name = pet.name.toLowerCase();
    final image = (pet.imagePath ?? '').toLowerCase();

    final source = '$breed $name $image';

    if (source.contains('콩눈')) return '콩눈';
    if (source.contains('땡눈')) return '땡눈';

    return '기타';
  }

  List<Pet> _applyPetFilters(List<Pet> list) {
    return list.where((pet) {
      final color = _getPetColor(pet);
      final eyeType = _getPetEyeType(pet);

      if (_selectedColor != '전체' && color != _selectedColor) {
        return false;
      }

      if (_selectedEyeType != '전체' && eyeType != _selectedEyeType) {
        return false;
      }

      return true;
    }).toList();
  }

  Widget _buildPetFilterActionButton() {
    final bool hasColorFilter = _selectedColor != '전체';
    final bool hasEyeFilter = _selectedEyeType != '전체';
    final bool hasAnyFilter = hasColorFilter || hasEyeFilter;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        bool isPressed = false;

        void setPressed(bool value) {
          setLocalState(() {
            isPressed = value;
          });
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setPressed(true),
          onTapCancel: () => setPressed(false),
          onTapUp: (_) {
            setPressed(false);
            _showPetFilterSheet();
          },
          child: AnimatedScale(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            scale: isPressed ? 0.97 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: hasAnyFilter
                    ? const Color(0xFFFFF3F0).withOpacity(isPressed ? 0.98 : 0.95)
                    : Colors.white.withOpacity(isPressed ? 0.98 : 0.92),
                borderRadius: BorderRadius.circular(20),

                // 👇 항상 코랄 테두리
                border: Border.all(
                  color: const Color(0xFFFFD6CC),
                  width: 1,
                ),

                boxShadow: [
                  BoxShadow(
                    color: hasAnyFilter
                        ? const Color(0xFFFF8E7C).withOpacity(
                      isPressed ? 0.06 : 0.12,
                    )
                        : const Color(0xFFFF8E7C).withOpacity(
                      isPressed ? 0.03 : 0.06,
                    ),
                    blurRadius: isPressed ? 6 : 10,
                    offset: Offset(0, isPressed ? 1 : 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: hasAnyFilter
                          ? const Color(0xFFFFE8E2)
                          : const Color(0xFFFFF6F3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFD4C9),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: hasAnyFilter
                          ? const Color(0xFFFF8E7C)
                          : const Color(0xFFE58F7C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasAnyFilter ? '필터 적용됨' : '필터 설정',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: hasAnyFilter
                          ? const Color(0xFFFF8E7C)
                          : const Color(0xFFE58F7C),
                    ),
                  ),
                  if (hasAnyFilter) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8E7C).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'ON',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF8E7C),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPetFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        String tempColor = _selectedColor;
        String tempEyeType = _selectedEyeType;

        final colorFilters = ['전체', '화이트', '블랙', '치즈', '얼룩', '삼색'];
        final eyeFilters = ['전체', '콩눈', '땡눈'];

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
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
                          '필터',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
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
                    const SizedBox(height: 8),
                    const Text(
                      '색상',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colorFilters.map((filter) {
                        final isSelected = tempColor == filter;
                        return _buildPopupFilterChip(
                          label: filter,
                          isSelected: isSelected,
                          onTap: () {
                            setSheetState(() {
                              tempColor = filter;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '눈 모양',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: eyeFilters.map((filter) {
                        final isSelected = tempEyeType == filter;
                        return _buildPopupFilterChip(
                          label: filter,
                          isSelected: isSelected,
                          onTap: () {
                            setSheetState(() {
                              tempEyeType = filter;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedColor = '전체';
                                _selectedEyeType = '전체';
                              });
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              side: const BorderSide(
                                color: Color(0xFFE9EEF4),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              '초기화',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedColor = tempColor;
                                _selectedEyeType = tempEyeType;
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              elevation: 0,
                              backgroundColor: const Color(0xFFFF8E7C),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              '적용',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
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

  Widget _buildPopupFilterChip({
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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFF1EC)
                : Colors.white,
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
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.8,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? const Color(0xFFFF8E7C)
                  : const Color(0xFF667085),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPetSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8E7C),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3436),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCollectionCard({
    required String title,
    required List<Map<String, String>> items,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildMiniPetCard(
                    id: item['id']!,
                    imagePath: item['image']!,
                    label: item['label']!,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleLikedPet(String id) {
    setState(() {
      if (_likedPetCardIds.contains(id)) {
        _likedPetCardIds.remove(id);
      } else {
        _likedPetCardIds.add(id);
      }
    });
  }

  Widget _buildMiniPetCard({
    required String id,
    required String imagePath,
    required String label,
  }) {
    final bool isFavorite = _likedPetCardIds.contains(id);

    return Container(
      width: 112,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // 필요하면 상세 열기
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => _toggleLikedPet(id),
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 18,
                      color: isFavorite
                          ? const Color(0xFFFF8E7C)
                          : const Color(0xFFC7CDD6),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.pets_rounded,
                            size: 34,
                            color: Color(0xFFD1D5DB),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSectionLabel(String label, {Color color = const Color(0xFF64748B)}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildIntegratedAppBar(BuildContext context, double topPadding) {
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
                      _buildPetProfileDropdown(),
                      const SizedBox(height: 8),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _isFilterVisible ? 1.0 : 0.0,
                          child: _isFilterVisible
                              ? Align(
                            alignment: Alignment.centerLeft,
                            child: _buildPetFilterActionButton(),
                          )
                              : const SizedBox.shrink(),
                        ),
                      ),
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
      '동물',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2D3436),
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildPetProfileDropdown() {
    final bool isCatTab = _tabController.index == 0;
    final pets = _applyPetFilters(
      _allPets.where((p) => p.isCat == isCatTab).toList(),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          setState(() {
            _showMyPetProfiles = !_showMyPetProfiles;
          });
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _showMyPetProfiles
                  ? const Color(0xFFFFB3A7)
                  : const Color(0xFFFFD8D0),
              width: _showMyPetProfiles ? 1.5 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _showMyPetProfiles
                    ? const Color(0xFFFF8E7C).withOpacity(0.10)
                    : Colors.black.withOpacity(0.04),
                blurRadius: _showMyPetProfiles ? 10 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFFD9D1),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  size: 16,
                  color: Color(0xFFFF8E7C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: pets.isEmpty
                    ? Text(
                  isCatTab ? '내 고양이 프로필을 추가해 보세요.' : '내 강아지 프로필을 추가해 보세요.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF3F3A37),
                    fontWeight: FontWeight.w700,
                  ),
                )
                    : RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF3F3A37),
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      TextSpan(text: isCatTab ? '내 고양이 ' : '내 강아지 '),
                      TextSpan(
                        text: '${pets.length}마리',
                        style: const TextStyle(
                          color: Color(0xFFFF7A67),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const TextSpan(text: ' 보기'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _showMyPetProfiles
                      ? const Color(0xFFFFF1ED)
                      : const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _showMyPetProfiles
                        ? const Color(0xFFFFD8D0)
                        : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _showMyPetProfiles ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _showMyPetProfiles
                          ? const Color(0xFFFF8E7C)
                          : const Color(0xFF94A3B8),
                      size: 16,
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
          Tab(text: '고양이'),
          Tab(text: '강아지'),
        ],
      ),
    );
  }

  Widget _buildTabContent({required bool isCat}) {
    final controller = isCat ? _catScrollController : _dogScrollController;

    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        if (!controller.hasClients) return false;

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
      child: RefreshIndicator(
        onRefresh: () async {
          await _fetchFishData();
          await _fetchPetData();
        },
        color: const Color(0xFFFF8E7C),
        backgroundColor: Colors.white,
        child: ListView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.only(
            top: 64,
            bottom: 120,
          ),
          children: [
            if (isCat)
              _buildPetGridContent()
            else
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: Text(
                    '강아지 리스트 준비 중',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetProfileInlinePanel() {
    final bool isCatTab = _tabController.index == 0;
    final List<Pet> filteredPets =
    _allPets.where((p) => p.isCat == isCatTab).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: filteredPets.isEmpty
          ? _buildEmptyPetPlaceholder(isCatTab)
          : _buildPetSummaryList(),
    );
  }

  Widget _buildPetGridContent() {
    final whiteItems = [
      {'id': 'white_1', 'image': 'assets/images/cat_white.png', 'label': '화이트 1'},
      {'id': 'white_2', 'image': 'assets/images/cat_white.png', 'label': '화이트 2'},
      {'id': 'white_3', 'image': 'assets/images/cat_white.png', 'label': '화이트 3'},
      {'id': 'white_4', 'image': 'assets/images/cat_white.png', 'label': '화이트 4'},
      {'id': 'white_5', 'image': 'assets/images/cat_white.png', 'label': '화이트 5'},
    ];

    final blackItems = [
      {'id': 'black_1', 'image': 'assets/images/cat_black_1.png', 'label': '블랙 1'},
      {'id': 'black_2', 'image': 'assets/images/cat_black_2.png', 'label': '블랙 2'},
      {'id': 'black_3', 'image': 'assets/images/cat_black_1.png', 'label': '블랙 3'},
      {'id': 'black_4', 'image': 'assets/images/cat_black_2.png', 'label': '블랙 4'},
      {'id': 'black_5', 'image': 'assets/images/cat_black_1.png', 'label': '블랙 5'},
      {'id': 'black_6', 'image': 'assets/images/cat_black_2.png', 'label': '블랙 6'},
    ];

    final testWhiteItems = [
      ...whiteItems,
      ...whiteItems,
    ];

    final testBlackItems = [
      ...blackItems,
      ...blackItems,
    ];

    final List<Map<String, dynamic>> sections = [
      {'title': '올화이트', 'items': testWhiteItems},
      {'title': '올블랙', 'items': testBlackItems},
      {'title': '화이트 테스트 1', 'items': testWhiteItems},
      {'title': '블랙 테스트 1', 'items': testBlackItems},
      {'title': '화이트 테스트 2', 'items': testWhiteItems},
      {'title': '블랙 테스트 2', 'items': testBlackItems},
      {'title': '화이트 테스트 3', 'items': testWhiteItems},
      {'title': '블랙 테스트 3', 'items': testBlackItems},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...sections.map(
              (section) => _buildPetCollectionCard(
            title: section['title'] as String,
            items: section['items'] as List<Map<String, String>>,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPetCollectionSection({required bool isCat}) {
    final pets = _allPets.where((p) => p.isCat == isCat).toList();

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 70),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF8E7C),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCat
                      ? Icons.pets_rounded
                      : Icons.cruelty_free_rounded,
                  size: 18,
                  color: const Color(0xFFFF8E7C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCat ? '우리 고양이' : '우리 강아지',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (pets.isEmpty)
          _buildEmptyPetStateCard(isCat: isCat)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: pets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pet = pets[index];
              return _buildPetDetailCard(pet);
            },
          ),
      ],
    );
  }

  Widget _buildEmptyPetStateCard({required bool isCat}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _showPetEditSheet(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 22,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFFFE2DB),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                isCat
                    ? Icons.pets_rounded
                    : Icons.cruelty_free_rounded,
                size: 34,
                color: const Color(0xFFFF8E7C).withOpacity(0.75),
              ),
              const SizedBox(height: 10),
              Text(
                isCat ? '등록된 고양이가 없어요' : '등록된 강아지가 없어요',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isCat
                    ? '오른쪽 아래 + 버튼으로 고양이를 추가해보세요'
                    : '오른쪽 아래 + 버튼으로 강아지를 추가해보세요',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF8E8E93),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPetPlaceholder(bool isCatTab) {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      child: GestureDetector(
        onTap: () => _showPetEditSheet(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.56),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF8E7C).withOpacity(0.25),
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pets,
                color: const Color(0xFFFF8E7C).withOpacity(0.55),
              ),
              const SizedBox(width: 10),
              Text(
                isCatTab
                    ? '등록된 고양이가 없어요. 추가해볼까요?'
                    : '등록된 강아지가 없어요. 추가해볼까요?',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetSummaryList() {
    final bool isCatTab = _tabController.index == 0;
    final List<Pet> filteredPets =
    _allPets.where((p) => p.isCat == isCatTab).toList();

    if (filteredPets.isEmpty) {
      return _buildEmptyPetPlaceholder(isCatTab);
    }

    return SizedBox(
      height: 110,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filteredPets.length,
        proxyDecorator: (
            Widget child,
            int index,
            Animation<double> animation,
            ) {
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              final double animValue =
              Curves.easeInOut.transform(animation.value);
              final double scale = lerpDouble(1, 1.02, animValue)!;
              final double elevation = lerpDouble(0, 3, animValue)!;

              return Transform.scale(
                scale: scale,
                child: Material(
                  elevation: elevation,
                  color: Colors.transparent,
                  shadowColor: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  child: child,
                ),
              );
            },
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final pet = filteredPets[index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey('pet_${pet.id}'),
            index: index,
            child: _buildPetSummaryCard(pet),
          );
        },
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (oldIndex < newIndex) newIndex -= 1;

            final movedPet = filteredPets.removeAt(oldIndex);
            filteredPets.insert(newIndex, movedPet);

            final otherTabPets =
            _allPets.where((p) => p.isCat != isCatTab).toList();

            if (isCatTab) {
              _allPets = [...filteredPets, ...otherTabPets];
            } else {
              _allPets = [...otherTabPets, ...filteredPets];
            }
          });

          _updatePetOrderOnServer();
        },
      ),
    );
  }

  Widget _buildPetSummaryCard(Pet pet) {
    return Container(
      width: 258,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFE7E1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(24),
                ),
                onTap: () => _showPetControlSheet(pet),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                  child: Row(
                    children: [
                      _buildPetAvatar(pet, size: 58),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              pet.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D3436),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius:
                                BorderRadius.circular(999),
                              ),
                              child: Text(
                                pet.breed,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF7C8796),
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: const Color(0xFFFFF4F1),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _showSnackLabSheet(pet),
                child: Container(
                  width: 74,
                  height: 74,
                  padding: const EdgeInsets.all(8),
                  child: _buildSnackIconArea(pet),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetDetailCard(Pet pet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFE5DE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showPetControlSheet(pet),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                _buildPetAvatar(pet, size: 68),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pet.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2D3436),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1ED),
                              borderRadius:
                              BorderRadius.circular(999),
                            ),
                            child: Text(
                              pet.isCat ? '고양이' : '강아지',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF8E7C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pet.breed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7C8796),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoMiniCard(
                              icon: Icons.phishing_rounded,
                              title: '먹어본 간식',
                              value: '${pet.triedSnacks.length}개',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoMiniCard(
                              icon: Icons.favorite_rounded,
                              title: '최애 간식',
                              value: pet.favoriteSnack.isEmpty
                                  ? '아직 없음'
                                  : pet.favoriteSnack,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFFF8E7C),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPetAvatar(Pet pet, {double size = 58}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        image: DecorationImage(
          image: (pet.imagePath != null &&
              File(pet.imagePath!).existsSync())
              ? FileImage(File(pet.imagePath!))
              : const AssetImage('assets/images/pets.webp')
          as ImageProvider,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildInfoMiniCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 16,
              color: const Color(0xFFFF8E7C),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3436),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnackIconArea(Pet pet) {
    if (pet.favoriteSnack.isNotEmpty) {
      final favFish = _fishList.firstWhere(
            (f) => (f.nameKo ?? f.name) == pet.favoriteSnack,
        orElse: () => FishItem(id: '', name: '', image: ''),
      );

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              favFish.image.isNotEmpty
                  ? Image.asset(
                _imageAssetPath(favFish.image),
                width: 24,
                height: 24,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.phishing,
                  size: 18,
                  color: Color(0xFFFF8E7C),
                ),
              )
                  : const Icon(
                Icons.phishing,
                size: 18,
                color: Color(0xFFFF8E7C),
              ),
              const Positioned(
                right: -4,
                top: -4,
                child: Icon(
                  Icons.favorite,
                  size: 10,
                  color: Color(0xFFFF6B81),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            pet.favoriteSnack,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF8E7C),
            ),
          ),
        ],
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.phishing,
          size: 18,
          color: Color(0xFFD9D9D9),
        ),
        SizedBox(height: 2),
        Text(
          '간식 실험실',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Color(0xFFA4A4A4),
          ),
        ),
      ],
    );
  }

  Widget _buildSnackActionButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required Color activeColor,
    required Color activeBgColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: active ? activeBgColor : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? activeColor.withOpacity(0.55)
                  : const Color(0xFFEAEAEA),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active
                    ? activeColor
                    : const Color(0xFF9A9A9A),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? activeColor
                      : const Color(0xFF7A7A7A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnackInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3436),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnackSearchBar(StateSetter setSheetState) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFD),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0x30FF7A65),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _snackSearchController,
        textAlignVertical: TextAlignVertical.center,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF333333),
          height: 1.15,
        ),
        decoration: const InputDecoration(
          hintText: '물고기 이름 검색',
          hintStyle: TextStyle(
            fontSize: 14,
            color: Color(0xFFB0B0B0),
            height: 1.15,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.all(11),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFFFF8E7C),
            ),
          ),
          prefixIconConstraints:
          BoxConstraints(minWidth: 40, minHeight: 40),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.fromLTRB(0, 14, 16, 14),
        ),
        onChanged: (value) {
          setSheetState(() {
            _snackSearchQuery = value;
            _highlightedSnackFishId = null;
          });
        },
        onSubmitted: (_) => _submitSnackSearch(setSheetState),
      ),
    );
  }

  Widget _buildFabWithMenu() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 120, right: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isMenuOpen)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.97),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFE2DB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPrettyMenuItem(
                    icon: Icons.pets_rounded,
                    title: '새 애완동물 추가',
                    onTap: () {
                      setState(() => _isMenuOpen = false);
                      _showPetEditSheet();
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF3F4F6),
                  ),
                  _buildPrettyMenuItem(
                    icon: Icons.edit_note_rounded,
                    title: '펫 통합 관리',
                    onTap: () {
                      setState(() => _isMenuOpen = false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManagePetsScreen(
                            pets: _allPets,
                            onUpdate: (updatedList) {
                              setState(() => _allPets = updatedList);
                              _updatePetOrderOnServer();
                            },
                            deletePet: _deletePetFromServer,
                            onEdit: (Pet pet) => _showPetEditSheet(pet: pet),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          FloatingActionButton(
            heroTag: null,
            onPressed: () => setState(() => _isMenuOpen = !_isMenuOpen),
            backgroundColor: const Color(0xFFFF8E7C),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _isMenuOpen ? 0.125 : 0,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrettyMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: const Color(0xFFFF8E7C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return AnimatedScale(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      scale: _showTopBtn ? 1.0 : 0.0,
      child: GestureDetector(
        onTap: _scrollToTop,
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

  Widget _buildMenuTile(
      IconData icon,
      String title,
      VoidCallback onTap, {
        bool isDestructive = false,
      }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? Colors.red[300]
            : const Color(0xFFFF8E7C),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: isDestructive ? Colors.red[300] : Colors.black87,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  InputDecoration _dialogInputDecoration({
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: const Color(0xFFF6F7F9),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFFF8E7C),
          width: 1.4,
        ),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFFB0B0B0),
        fontSize: 14,
      ),
    );
  }

  void _showPetControlSheet(Pet pet) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${pet.name} 관리',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildMenuTile(
              Icons.edit_rounded,
              '프로필 정보 변경',
                  () {
                Navigator.pop(context);
                _showPetEditSheet(pet: pet);
              },
            ),
            _buildMenuTile(
              Icons.science_rounded,
              '최애 간식 실험실',
                  () {
                Navigator.pop(context);
                _showSnackLabSheet(pet);
              },
            ),
            const Divider(
              height: 32,
              thickness: 0.5,
              color: Color(0xFFEEEEEE),
            ),
            _buildMenuTile(
              Icons.delete_outline_rounded,
              '반려동물 삭제',
                  () {
                Navigator.pop(context);
                if (pet.id != null) {
                  _showDeleteConfirm(pet);
                }
              },
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPetEditSheet({Pet? pet}) {
    final bool isEdit = pet != null;
    final nameController =
    TextEditingController(text: isEdit ? pet.name : '');
    final breedController =
    TextEditingController(text: isEdit ? pet.breed : '');
    String? tempImagePath = isEdit ? pet.imagePath : null;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final double bottomPadding =
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24;

        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
            padding: EdgeInsets.only(
              bottom: bottomPadding,
              left: 24,
              right: 24,
              top: 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    isEdit ? '정보 수정' : '새 친구 등록',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final XFile? image = await _picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (image != null) {
                          setSheetState(
                                () => tempImagePath = image.path,
                          );
                        }
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                ),
                              ],
                              image: DecorationImage(
                                image: tempImagePath != null &&
                                    File(tempImagePath!)
                                        .existsSync()
                                    ? FileImage(
                                  File(tempImagePath!),
                                )
                                    : const AssetImage(
                                    'assets/images/pets.webp')
                                as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF8E7C),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameController,
                    decoration: _dialogInputDecoration(
                      hintText: '이름',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: breedController,
                    decoration: _dialogInputDecoration(
                      hintText: '종류',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                      setSheetState(
                            () => _isSubmitting = true,
                      );
                      setState(
                            () => _isSubmitting = true,
                      );
                      try {
                        await _savePetToServer(
                          nameController.text.trim(),
                          breedController.text.trim(),
                          tempImagePath,
                          existingId: pet?.id,
                        );
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      } finally {
                        if (mounted) {
                          setSheetState(
                                () => _isSubmitting = false,
                          );
                          setState(
                                () => _isSubmitting = false,
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8E7C),
                      foregroundColor: Colors.white,
                      minimumSize:
                      const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      isEdit ? '저장하기' : '등록하기',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(Pet pet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('반려동물 삭제'),
        content: Text(
          '${pet.name} 정보를 삭제할까요?\n삭제 후에는 되돌릴 수 없어요.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(color: Color(0xFF8E8E93)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (pet.id != null) {
                await _deletePetFromServer(pet.id!);
              }
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackLabSheet(Pet pet) {
    _snackSearchController.clear();
    _snackSearchQuery = '';
    _submittedSnackQuery = null;
    _highlightedSnackFishId = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final triedCount = pet.triedSnacks.length;
          final favoriteSnack = pet.favoriteSnack;
          final visibleFishList = _buildVisibleSnackFishList();

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            height: MediaQuery.of(context).size.height * 0.82,
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFFDFDFD),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E2E2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1EE),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.phishing_rounded,
                          color: Color(0xFFFF8E7C),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pet.name}의 간식 실험실',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '먹여본 물고기를 체크하고 최애 간식을 골라주세요',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8E8E93),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildSnackInfoChip(
                        icon: Icons.check_circle_rounded,
                        label: '먹어본 간식',
                        value: '$triedCount개',
                        color: const Color(0xFFFF8E7C),
                        bgColor: const Color(0xFFFFF1EE),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSnackInfoChip(
                        icon: Icons.star_rounded,
                        label: '최애 간식',
                        value: favoriteSnack.isEmpty
                            ? '아직 없음'
                            : favoriteSnack,
                        color: const Color(0xFFFFC24B),
                        bgColor: const Color(0xFFFFF8E8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSnackSearchBar(setSheetState),
                const SizedBox(height: 12),
                Padding(
                  padding:
                  const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    _snackSearchQuery.trim().isNotEmpty
                        ? '관련순'
                        : '이름순',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                Expanded(
                  child: visibleFishList.isEmpty
                      ? const Center(
                    child: Text(
                      '검색 결과가 없어요',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  )
                      : ListView.separated(
                    controller: _snackFishScrollController,
                    physics: const BouncingScrollPhysics(),

                    itemCount: visibleFishList.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final fish = visibleFishList[index];
                      final displayName =
                      _displayFishName(fish);
                      final isTried = pet.triedSnacks
                          .contains(displayName);
                      final isFav =
                          pet.favoriteSnack == displayName;
                      final isHighlighted =
                          _highlightedSnackFishId == fish.id;

                      return AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 180,
                        ),
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? const Color(0xFFFFF4E8)
                              : isFav
                              ? const Color(0xFFFFFBF2)
                              : Colors.white,
                          borderRadius:
                          BorderRadius.circular(20),
                          border: Border.all(
                            color: isHighlighted
                                ? const Color(0xFFFFC8A2)
                                : isFav
                                ? const Color(0xFFFFD67A)
                                : isTried
                                ? const Color(
                                0xFFFFD8D1)
                                : const Color(
                                0xFFF0F0F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                              Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color(
                                    0xFFFFF4F1),
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: fish.image.isNotEmpty
                                  ? Image.asset(
                                _imageAssetPath(fish.image),
                                width: 28,
                                height: 28,
                                errorBuilder:
                                    (_, __, ___) =>
                                const Icon(
                                  Icons.phishing,
                                  color: Color(
                                      0xFFFF8E7C),
                                ),
                              )
                                  : const Icon(
                                Icons.phishing,
                                color: Color(0xFFFF8E7C),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          displayName,
                                          maxLines: 1,
                                          overflow:
                                          TextOverflow
                                              .ellipsis,
                                          style:
                                          const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight:
                                            FontWeight.w700,
                                            color: Color(
                                                0xFF2D3436),
                                          ),
                                        ),
                                      ),
                                      if (isFav)
                                        Container(
                                          padding:
                                          const EdgeInsets
                                              .symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration:
                                          BoxDecoration(
                                            color: const Color(
                                                0xFFFFF1D6),
                                            borderRadius:
                                            BorderRadius
                                                .circular(
                                                999),
                                          ),
                                          child: const Text(
                                            '최애',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight:
                                              FontWeight.w700,
                                              color: Color(
                                                  0xFFE0A100),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    fish.name,
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildSnackActionButton(
                                  icon: isTried
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                  label: isTried
                                      ? '먹음'
                                      : '기록',
                                  active: isTried,
                                  onTap: () async {
                                    setSheetState(() {
                                      if (isTried) {
                                        pet.triedSnacks
                                            .remove(displayName);
                                        if (pet.favoriteSnack ==
                                            displayName) {
                                          pet.favoriteSnack = '';
                                        }
                                      } else {
                                        pet.triedSnacks
                                            .add(displayName);
                                      }
                                    });
                                    await _updatePetSnacks(pet);
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  },
                                  activeColor: const Color(
                                      0xFFFF8E7C),
                                  activeBgColor:
                                  const Color(0xFFFFF1EE),
                                ),
                                const SizedBox(width: 8),
                                _buildSnackActionButton(
                                  icon: Icons.favorite_rounded,
                                  label: '최애',
                                  active: isFav,
                                  onTap: () async {
                                    setSheetState(() {
                                      pet.triedSnacks
                                          .add(displayName);
                                      pet.favoriteSnack =
                                      isFav
                                          ? ''
                                          : displayName;
                                    });
                                    await _updatePetSnacks(pet);
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  },
                                  activeColor: const Color(
                                      0xFFFFB938),
                                  activeBgColor:
                                  const Color(0xFFFFF8E8),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
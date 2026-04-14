import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'image_adjust_screen.dart';

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

  Pet? _draggingPet;
  bool _showDeleteDropZone = false;

  final String _petApiUrl = 'http://161.33.30.40:8080/api/pets';
  final String _fishApiUrl = 'http://161.33.30.40:8080/api/fish';
  final String _baseUrl = 'http://161.33.30.40:8080';

  String _resolvePetImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';

    final value = path.trim();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    if (value.startsWith('/')) {
      return '$_baseUrl$value';
    }

    return value;
  }

  bool _isRemotePetImage(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    final value = path.trim();
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('/uploads/');
  }

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
                (json) =>
                Pet(
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
      final bool isLocalFile =
          imagePath != null &&
              imagePath.isNotEmpty &&
              !_isRemotePetImage(imagePath) &&
              File(imagePath).existsSync();

      final Map<String, dynamic> petData = {
        'kakaoId': int.parse(_kakaoId!),
        'name': name,
        'breed': breed,
        'isCat': _tabController.index == 0,

        // 로컬 파일 경로는 서버에 그대로 보내지 않음
        'imagePath': isLocalFile ? null : imagePath,
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
        final Map<String, dynamic> savedPet =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        final int? savedPetId = (savedPet['id'] as num?)?.toInt();

        if (savedPetId != null && isLocalFile) {
          await _uploadPetImageToServer(
            petId: savedPetId,
            localImagePath: imagePath!,
          );
        }

        await _fetchPetData();
      } else {
        debugPrint('저장/수정 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('저장/수정 실패: $e');
    }
  }

  Future<String?> _uploadPetImageToServer({
    required int petId,
    required String localImagePath,
  }) async {
    try {
      final file = File(localImagePath);
      if (!file.existsSync()) return null;

      final uri = Uri.parse('$_petApiUrl/$petId/image');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['imagePath']?.toString();
      }

      debugPrint('펫 이미지 업로드 실패: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('펫 이미지 업로드 에러: $e');
      return null;
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

  Widget _buildPetImage(
      String? imagePath, {
        BoxFit fit = BoxFit.cover,
      }) {
    final bool hasLocalFile =
        imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync();
    final bool isRemote = _isRemotePetImage(imagePath);
    final String remoteUrl = _resolvePetImageUrl(imagePath);

    if (hasLocalFile) {
      return Image.file(
        File(imagePath!),
        fit: fit,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.pets_rounded,
          color: Color(0xFFFF8E7C),
        ),
      );
    }

    if (isRemote) {
      return Image.network(
        remoteUrl,
        fit: fit,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/pets.webp',
          fit: fit,
        ),
      );
    }

    return Image.asset(
      'assets/images/pets.webp',
      fit: fit,
    );
  }

  void _scrollToTop() {
    final controller = _getCurrentPetScrollController();
    if (!controller.hasClients) return;

    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _attachScrollListener(ScrollController controller) {
    controller.addListener(() {
      if (!mounted || !controller.hasClients) return;

      final double offset = controller.offset;
      final bool showBtn = offset > 100;

      if (showBtn != _showTopBtn) {
        setState(() => _showTopBtn = showBtn);
      }
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
    final double topPadding = MediaQuery
        .of(context)
        .padding
        .top;
    final double safeBottom = MediaQuery
        .of(context)
        .padding
        .bottom;
    final double keyboardInset = MediaQuery
        .of(context)
        .viewInsets
        .bottom;

    final bool showFilterInAppBar = _isFilterVisible;
    final double appBarHeight = topPadding + (showFilterInAppBar ? 110 : 126);

    // 펼침 패널은 실제 앱바 바로 아래에서 시작
    final double profilePanelTop = appBarHeight + 10;

    // 접힘 상태에서는 여백 0, 펼쳤을 때만 본문을 아래로 밀기
    final double profilePanelReservedHeight = _showMyPetProfiles ? 108 : 0;

    final double scrollTopBottom = keyboardInset > 0 ? 24 : safeBottom + 88;
    final double deletePopupBottom = safeBottom + 98;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
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
                SizedBox(height: appBarHeight + profilePanelReservedHeight),
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

          if (_isMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _isMenuOpen = false),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _showDeleteDropZone ? deletePopupBottom : -120,
            child: IgnorePointer(
              ignoring: !_showDeleteDropZone,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: _showDeleteDropZone ? 1.0 : 0.0,
                child: Center(
                  child: DragTarget<Pet>(
                    onWillAcceptWithDetails: (_) => true,
                    onAcceptWithDetails: (details) {
                      final pet = details.data;

                      setState(() {
                        _showDeleteDropZone = false;
                        _draggingPet = null;
                      });

                      if (pet.id != null) {
                        _showDeleteConfirm(pet);
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      final bool isHovering = candidateData.isNotEmpty;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutCubic,
                            width: isHovering ? 70 : 60,
                            height: isHovering ? 70 : 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isHovering
                                    ? const [
                                  Color(0xFFFF8E7C),
                                  Color(0xFFFF6F61),
                                ]
                                    : [
                                  const Color(0xFFFFB2A5),
                                  const Color(0xFFFF9688),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.78),
                                width: 1.3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF8E7C).withOpacity(
                                    isHovering ? 0.26 : 0.15,
                                  ),
                                  blurRadius: isHovering ? 20 : 14,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    isHovering ? 0.10 : 0.06,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                              size: isHovering ? 30 : 26,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.94),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFFFE3DB),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              isHovering ? '놓으면 삭제돼요' : '여기로 끌어오면 삭제',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isHovering
                                    ? const Color(0xFFFF6F61)
                                    : const Color(0xFFB36E60),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            right: 20,
            bottom: scrollTopBottom,
            child: _buildScrollToTopButton(),
          ),

          Positioned(
            right: 18,
            bottom: 160,
            child: _buildFabWithMenu(),
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

    if (source.contains('white') || source.contains('흰') ||
        source.contains('화이트')) {
      return '화이트';
    }
    if (source.contains('black') || source.contains('검') ||
        source.contains('블랙')) {
      return '블랙';
    }
    if (source.contains('cheese') || source.contains('치즈') ||
        source.contains('yellow') || source.contains('노랑')) {
      return '치즈';
    }
    if (source.contains('tabby') || source.contains('얼룩') ||
        source.contains('stripe') || source.contains('줄무늬')) {
      return '얼룩';
    }
    if (source.contains('tricolor') || source.contains('calico') ||
        source.contains('삼색')) {
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
                    ? const Color(0xFFFFF3F0).withOpacity(
                    isPressed ? 0.98 : 0.95)
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
    bool showSampleBadge = false,
    String? sampleDescription,
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
                if (showSampleBadge) ...[
                  _buildSampleBadge(),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (sampleDescription != null) ...[
              _buildSampleInfoBanner(sampleDescription),
              const SizedBox(height: 10),
            ],
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

  void _showPetImagePreview(Pet pet) {
    final String? imagePath = pet.imagePath;
    final bool hasLocalFile =
        imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync();
    final bool isRemote = _isRemotePetImage(imagePath);
    final String remoteUrl = _resolvePetImageUrl(imagePath);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Stack(
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: hasLocalFile
                              ? Image.file(
                            File(imagePath!),
                            fit: BoxFit.contain,
                          )
                              : isRemote
                              ? Image.network(
                            remoteUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/pets.webp',
                                fit: BoxFit.contain,
                              );
                            },
                          )
                              : Image.asset(
                            'assets/images/pets.webp',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        pet.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pet.breed,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.white.withOpacity(0.92),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
            color: Colors.black.withOpacity(0.025),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                      isFavorite ? Icons.favorite_rounded : Icons
                          .favorite_border_rounded,
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

  Widget _buildSampleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFA08F),
            Color(0xFFFF8E7C),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8E7C).withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 13,
            color: Colors.white,
          ),
          SizedBox(width: 5),
          Text(
            'SAMPLE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleInfoBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFE2DB),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEE9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.science_rounded,
              size: 14,
              color: Color(0xFFFF8E7C),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.2,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A6A66),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleHeroCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFDDD6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFFDED6),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFFFF8E7C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2D3436),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.8,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7B8794),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _SampleStatusPill(label: '샘플 데이터 노출 중'),
              _SampleStatusPill(label: '정식 도감 준비중'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDogSampleContent() {
    final dogItems = [
      {
        'id': 'dog_sample_1',
        'image': 'assets/images/dogs_1.png',
        'label': '강아지 샘플 1'
      },
      {
        'id': 'dog_sample_2',
        'image': 'assets/images/dogs_2.png',
        'label': '강아지 샘플 2'
      },
      {
        'id': 'dog_sample_3',
        'image': 'assets/images/dogs_3.png',
        'label': '강아지 샘플 3'
      },
      {
        'id': 'dog_sample_4',
        'image': 'assets/images/dogs_4.png',
        'label': '강아지 샘플 4'
      },
      {
        'id': 'dog_sample_5',
        'image': 'assets/images/dogs_5.png',
        'label': '강아지 샘플 5'
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSampleHeroCard(
          title: '지금은 펫 관리만 이용 가능해요!!',
          subtitle: '지금 보이는 항목은 정식 테스트를 위한 샘플 데이터예요.',
          icon: Icons.pets_rounded,
        ),
        _buildPetCollectionCard(
          title: '강아지 샘플 리스트',
          items: dogItems,
          sampleDescription: '현재 강아지 리스트는 샘플 데이터로 표시되고 있어요.',
        ),
        const SizedBox(height: 8),
      ],
    );
  }


  Widget _buildFilterSectionLabel(String label,
      {Color color = const Color(0xFF64748B)}) {
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
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
                            onTap: () =>
                                Navigator.push(
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

                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPetProfileDropdown(),
                          ),
                          const SizedBox(width: 8),
                          _buildPetFilterActionButton(),
                        ],
                      ),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) {
                          return SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: _showMyPetProfiles
                            ? Padding(
                          key: const ValueKey('pet_profile_panel'),
                          padding: const EdgeInsets.only(top: 10),
                          child: _buildPetProfileInlinePanel(),
                        )
                            : const SizedBox(
                          key: ValueKey('pet_profile_panel_empty'),
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
                  isCatTab ? '고양이 프로필 추가' : '강아지 프로필 추가',
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

    return RefreshIndicator(
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
          if (isCat) _buildPetGridContent() else
            _buildDogSampleContent(),
        ],
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
      {
        'id': 'white_1',
        'image': 'assets/images/cat_white.png',
        'label': '화이트 1'
      },
      {
        'id': 'white_2',
        'image': 'assets/images/cat_white.png',
        'label': '화이트 2'
      },
      {
        'id': 'white_3',
        'image': 'assets/images/cat_white.png',
        'label': '화이트 3'
      },
      {
        'id': 'white_4',
        'image': 'assets/images/cat_white.png',
        'label': '화이트 4'
      },
      {
        'id': 'white_5',
        'image': 'assets/images/cat_white.png',
        'label': '화이트 5'
      },
    ];

    final blackItems = [
      {
        'id': 'black_1',
        'image': 'assets/images/cat_black_1.png',
        'label': '블랙 1'
      },
      {
        'id': 'black_2',
        'image': 'assets/images/cat_black_2.png',
        'label': '블랙 2'
      },
      {
        'id': 'black_3',
        'image': 'assets/images/cat_black_1.png',
        'label': '블랙 3'
      },
      {
        'id': 'black_4',
        'image': 'assets/images/cat_black_2.png',
        'label': '블랙 4'
      },
      {
        'id': 'black_5',
        'image': 'assets/images/cat_black_1.png',
        'label': '블랙 5'
      },
      {
        'id': 'black_6',
        'image': 'assets/images/cat_black_2.png',
        'label': '블랙 6'
      },
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
      {
        'title': '올화이트',
        'items': testWhiteItems,
        'showSampleBadge': true,
        'sampleDescription': '올화이트 리스트는 샘플 데이터로 표시되고 있어요.',
      },
      {
        'title': '올블랙',
        'items': testBlackItems,
        'showSampleBadge': true,
        'sampleDescription': '올블랙 리스트는 샘플 데이터로 표시되고 있어요.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSampleHeroCard(
          title: '지금은 펫 관리만 이용 가능해요!',
          subtitle: '지금 보이는 항목은 정식 테스트를 위한 샘플 데이터예요.',
          icon: Icons.pets_rounded,
        ),
        ...sections.map(
              (section) =>
              _buildPetCollectionCard(
                title: section['title'] as String,
                items: List<Map<String, String>>.from(section['items'] as List),
                showSampleBadge: section['showSampleBadge'] as bool,
                sampleDescription: section['sampleDescription'] as String?,
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
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

    final double screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final double cardWidth = screenWidth < 390 ? 280 : 296;

    return SizedBox(
      height: 100,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 4, right: 10),
        itemCount: filteredPets.length,
        buildDefaultDragHandles: false,
        proxyDecorator: (Widget child,
            int index,
            Animation<double> animation,) {
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

          return SizedBox(
            key: ValueKey('pet_${pet.id}'),
            width: cardWidth,
            child: _buildPetSummaryCard(
              pet,
              width: cardWidth,
              reorderIndex: index,
              isFirst: index == 0,
              isDragging: _draggingPet?.id == pet.id,
              reorderHandle: ReorderableDragStartListener(
                index: index,
                child: _buildPetReorderHandle(),
              ),
            ),
          );
        },
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (oldIndex < newIndex) newIndex -= 1;

            final movedPet = filteredPets.removeAt(oldIndex);
            filteredPets.insert(newIndex, movedPet);

            final otherTabPets =
            _allPets.where((p) => p.isCat != isCatTab).toList();

            _allPets = isCatTab
                ? [...filteredPets, ...otherTabPets]
                : [...otherTabPets, ...filteredPets];
          });

          _updatePetOrderOnServer();
        },
      ),
    );
  }

  Widget _buildPetReorderHandle({bool disabled = false}) {
    return Container(
      width: 30,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: disabled
            ? Colors.white.withOpacity(0.86)
            : Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFE2DB),
          width: 1,
        ),
        boxShadow: disabled
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.drag_indicator_rounded,
        size: 18,
        color: disabled
            ? const Color(0xFFD8A79C)
            : const Color(0xFFE58F7C),
      ),
    );
  }

  Widget _buildDraggingPetFeedback(Pet pet) {
    return Transform.translate(
      offset: const Offset(-118, -78),
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 176,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFFFE3DB),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8E7C).withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildPetImage(
                      pet.imagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pet.breed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8B97A6),
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
    );
  }

  Widget _buildPetSummaryCard(Pet pet, {
    required double width,
    required int reorderIndex,
    bool isFirst = false,
    bool isDragging = false,
    bool showSnackLab = true,
    Widget? reorderHandle,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: isDragging ? 0.35 : 1.0,
      child: Container(
        width: width,
        margin: EdgeInsets.only(
          left: isFirst ? 0 : 6,
          right: 6,
          top: 6,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFE7E1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: LongPressDraggable<Pet>(
                  data: pet,
                  delay: const Duration(milliseconds: 220),
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  rootOverlay: true,
                  maxSimultaneousDrags: 1,
                  feedback: _buildDraggingPetFeedback(pet),
                  onDragStarted: () {
                    setState(() {
                      _draggingPet = pet;
                      _showDeleteDropZone = true;
                    });
                  },
                  onDragEnd: (_) {
                    if (!mounted) return;
                    setState(() {
                      _draggingPet = null;
                      _showDeleteDropZone = false;
                    });
                  },
                  childWhenDragging: _buildPetSummaryMainArea(
                    pet,
                    dragging: true,
                  ),
                  child: _buildPetSummaryMainArea(
                    pet,
                    dragging: false,
                  ),
                ),
              ),

              if (showSnackLab || reorderHandle != null) ...[
                const SizedBox(width: 8),

                if (showSnackLab)
                  ReorderableDelayedDragStartListener(
                    index: reorderIndex,
                    child: Material(
                      color: const Color(0xFFFFF4F1),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showSnackLabSheet(pet),
                        child: Container(
                          width: 74,
                          height: 50,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 5,
                          ),
                          alignment: Alignment.center,
                          child: _buildSnackIconArea(pet),
                        ),
                      ),
                    ),
                  ),

                if (reorderHandle != null) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 32,
                    height: 50,
                    child: Center(child: reorderHandle),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetSummaryMainArea(Pet pet, {
    bool dragging = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(20),
        ),
        onTap: () => _showPetControlSheet(pet),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
          child: Row(
            children: [
              // ⭐ 핵심: 아바타만 따로 터치 처리
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showPetImagePreview(pet),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _buildPetAvatar(pet, size: 48),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 108),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        pet.breed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
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
      ),
      child: ClipOval(
        child: _buildPetImage(
          pet.imagePath,
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
    final bool hasFavorite = pet.favoriteSnack.isNotEmpty;

    if (hasFavorite) {
      final favFish = _fishList.firstWhere(
            (f) => (f.nameKo ?? f.name) == pet.favoriteSnack,
        orElse: () => FishItem(id: '', name: '', image: ''),
      );

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              favFish.image.isNotEmpty
                  ? Image.asset(
                _imageAssetPath(favFish.image),
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              )
                  : const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Color(0xFFFFC83D),
              ),
              const Positioned(
                right: -3,
                top: -3,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 9,
                  color: Color(0xFFFF6B81),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            pet.favoriteSnack,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 8.8,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF8E7C),
              height: 1.0,
            ),
          ),
        ],
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          size: 16,
          color: Color(0xFFFFC83D),
        ),
        SizedBox(height: 3),
        Text(
          '최애?',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 8.8,
            fontWeight: FontWeight.w700,
            color: Color(0xFFBFA19B),
            height: 1.0,
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
    return StatefulBuilder(
      builder: (context, setFabState) {
        bool isPressed = false;

        void setPressed(bool value) {
          setFabState(() => isPressed = value);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedSlide(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              offset: _isMenuOpen ? Offset.zero : const Offset(0, 0.05),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                opacity: _isMenuOpen ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_isMenuOpen,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(bottom: 12),
                    width: 204,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFFFE7E1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: const Color(0xFFFF8E7C).withOpacity(0.07),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 14),
                              color: const Color(0xFFF4F4F5),
                            ),
                            _buildPrettyMenuItem(
                              icon: Icons.edit_note_rounded,
                              title: '펫 통합 관리',
                              onTap: () {
                                setState(() => _isMenuOpen = false);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ManagePetsScreen(
                                          pets: _allPets,
                                          onUpdate: (updatedList) {
                                            setState(() =>
                                            _allPets = updatedList);
                                            _updatePetOrderOnServer();
                                          },
                                          deletePet: _deletePetFromServer,
                                          onEdit: (Pet pet) =>
                                              _showPetEditSheet(pet: pet),
                                        ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setPressed(true),
              onTapCancel: () => setPressed(false),
              onTapUp: (_) => setPressed(false),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                scale: isPressed ? 0.94 : 1.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          isPressed ? 0.08 : 0.12,
                        ),
                        blurRadius: isPressed ? 10 : 16,
                        offset: Offset(0, isPressed ? 3 : 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF8E7C).withOpacity(
                          _isMenuOpen ? 0.28 : 0.22,
                        ),
                        blurRadius: _isMenuOpen ? 20 : 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: null,
                    onPressed: () {
                      setState(() => _isMenuOpen = !_isMenuOpen);
                    },
                    backgroundColor: const Color(0xFFFF8E7C),
                    elevation: 0,
                    shape: const CircleBorder(),
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      turns: _isMenuOpen ? 0.125 : 0,
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrettyMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        bool isPressed = false;

        void setPressed(bool value) {
          setLocalState(() => isPressed = value);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setPressed(true),
          onTapCancel: () => setPressed(false),
          onTapUp: (_) async {
            await Future.delayed(const Duration(milliseconds: 35));
            if (context.mounted) setPressed(false);
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            color: isPressed
                ? const Color(0xFFFFF7F4)
                : Colors.transparent,
            child: Row(
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 170),
                  curve: Curves.easeOutCubic,
                  scale: isPressed ? 0.97 : 1.0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EF),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: const Color(0xFFFFE4DC),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 17,
                      color: const Color(0xFFFF8E7C),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.6,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3436),
                      letterSpacing: -0.15,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 170),
                  curve: Curves.easeOutCubic,
                  offset: isPressed ? const Offset(0.04, 0) : Offset.zero,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  Widget _buildMenuTile(IconData icon,
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
      builder: (context) =>
          Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery
                  .of(context)
                  .padding
                  .bottom + 24,
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
            MediaQuery
                .of(context)
                .viewInsets
                .bottom +
                MediaQuery
                    .of(context)
                    .padding
                    .bottom +
                24;

        return StatefulBuilder(
          builder: (context, setSheetState) =>
              Container(
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
                            final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              setSheetState(() => tempImagePath = image.path);
                            }
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _buildPetImage(
                                    tempImagePath,
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
      builder: (context) =>
          AlertDialog(
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
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setSheetState) {
              final triedCount = pet.triedSnacks.length;
              final favoriteSnack = pet.favoriteSnack;
              final visibleFishList = _buildVisibleSnackFishList();

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                margin: EdgeInsets.only(
                  bottom: MediaQuery
                      .of(context)
                      .viewInsets
                      .bottom,
                ),
                height: MediaQuery
                    .of(context)
                    .size
                    .height * 0.82,
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery
                      .of(context)
                      .padding
                      .bottom + 10,
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
                        _snackSearchQuery
                            .trim()
                            .isNotEmpty
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
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF2D3436),
                                              ),
                                            ),
                                          ),
                                          if (isFav)
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF1D6),
                                                borderRadius: BorderRadius
                                                    .circular(999),
                                              ),
                                              child: const Text(
                                                '최애',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFE0A100),
                                                ),
                                              ),
                                            ),
                                        ],
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

class _SampleStatusPill extends StatelessWidget {
  final String label;

  const _SampleStatusPill({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFFE0D9),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF6E7683),
        ),
      ),
    );
  }
}



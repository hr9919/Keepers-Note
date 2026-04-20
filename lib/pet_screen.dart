import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'image_adjust_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'manage_pet_screen.dart';
import 'models/global_search_item.dart';
import 'models/pet_model.dart';
import 'setting_screen.dart';

class PetCatalogVariant {
  final String id;
  final bool isCat;
  final String breedId;
  final String breedName;
  final String colorId;
  final String colorName;
  final String eyeId;
  final String eyeName;
  final String eyeStyle;
  final String eyeStyleKo;
  final String? eyeColorId;
  final String? eyeColorNameKo;
  final int variantNo;
  final String? imagePath;
  final bool isUploaded;

  // ✅ backend rule fields
  final bool isColorFixed;
  final String? fixedColorId;
  final String? fixedColorNameKo;

  final bool isEyeColorFixed;
  final String? fixedEyeColorId;
  final String? fixedEyeColorNameKo;

  const PetCatalogVariant({
    required this.id,
    required this.isCat,
    required this.breedId,
    required this.breedName,
    required this.colorId,
    required this.colorName,
    required this.eyeId,
    required this.eyeName,
    required this.eyeStyle,
    required this.eyeStyleKo,
    required this.eyeColorId,
    required this.eyeColorNameKo,
    required this.variantNo,
    required this.imagePath,
    required this.isUploaded,
    required this.isColorFixed,
    required this.fixedColorId,
    required this.fixedColorNameKo,
    required this.isEyeColorFixed,
    required this.fixedEyeColorId,
    required this.fixedEyeColorNameKo,
  });

  factory PetCatalogVariant.fromCatJson(Map<String, dynamic> json) {
    return PetCatalogVariant(
      id: (json['id'] ?? '').toString(),
      isCat: true,
      breedId: (json['catTypeId'] ?? '').toString(),
      breedName: (json['catTypeNameKo'] ?? json['catTypeId'] ?? '').toString(),
      colorId: (json['colorId'] ?? '').toString(),
      colorName: (json['colorNameKo'] ?? json['colorId'] ?? '').toString(),
      eyeId: (json['eyeId'] ?? '').toString(),
      eyeName: (json['eyeNameKo'] ?? json['eyeId'] ?? '').toString(),
      eyeStyle: (json['eyeStyle'] ?? '').toString(),
      eyeStyleKo: (json['eyeStyleKo'] ?? '').toString(),
      eyeColorId: json['eyeColorId']?.toString(),
      eyeColorNameKo: json['eyeColorNameKo']?.toString(),
      variantNo: int.tryParse('${json['variantNo'] ?? 1}') ?? 1,
      imagePath: json['imagePath']?.toString(),
      isUploaded: (json['isUploaded'] ?? false) == true,

      isColorFixed: (json['isColorFixed'] ?? false) == true,
      fixedColorId: json['fixedColorId']?.toString(),
      fixedColorNameKo: json['fixedColorNameKo']?.toString(),

      isEyeColorFixed: (json['isEyeColorFixed'] ?? false) == true,
      fixedEyeColorId: json['fixedEyeColorId']?.toString(),
      fixedEyeColorNameKo: json['fixedEyeColorNameKo']?.toString(),
    );
  }

  factory PetCatalogVariant.fromDogJson(Map<String, dynamic> json) {
    return PetCatalogVariant(
      id: (json['id'] ?? '').toString(),
      isCat: false,
      breedId: (json['dogTypeId'] ?? '').toString(),
      breedName: (json['dogTypeNameKo'] ?? json['dogTypeId'] ?? '').toString(),
      colorId: (json['colorId'] ?? '').toString(),
      colorName: (json['colorNameKo'] ?? json['colorId'] ?? '').toString(),
      eyeId: (json['eyeId'] ?? '').toString(),
      eyeName: (json['eyeNameKo'] ?? json['eyeId'] ?? '').toString(),
      eyeStyle: (json['eyeStyle'] ?? '').toString(),
      eyeStyleKo: (json['eyeStyleKo'] ?? '').toString(),
      eyeColorId: json['eyeColorId']?.toString(),
      eyeColorNameKo: json['eyeColorNameKo']?.toString(),
      variantNo: int.tryParse('${json['variantNo'] ?? 1}') ?? 1,
      imagePath: json['imagePath']?.toString(),
      isUploaded: (json['isUploaded'] ?? false) == true,

      isColorFixed: (json['isColorFixed'] ?? false) == true,
      fixedColorId: json['fixedColorId']?.toString(),
      fixedColorNameKo: json['fixedColorNameKo']?.toString(),

      isEyeColorFixed: (json['isEyeColorFixed'] ?? false) == true,
      fixedEyeColorId: json['fixedEyeColorId']?.toString(),
      fixedEyeColorNameKo: json['fixedEyeColorNameKo']?.toString(),
    );
  }

  String get miniLabel {
    final pieces = <String>[
      if (eyeStyleKo.trim().isNotEmpty) eyeStyleKo,
      if (colorName.trim().isNotEmpty) colorName,
      if ((eyeColorNameKo ?? '').trim().isNotEmpty) eyeColorNameKo!,
    ];
    return pieces.join(' · ');
  }

  String get detailKey {
    final pieces = <String>[
      if (colorName.trim().isNotEmpty) colorName,
      if (eyeStyleKo.trim().isNotEmpty) eyeStyleKo,
      if ((eyeColorNameKo ?? '').trim().isNotEmpty) eyeColorNameKo!,
    ];
    return pieces.join(' · ');
  }
}

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

enum PetSortType {
  name,
  collectedCount,
  liked,
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
  bool _showMyPetProfiles = true;
  final Set<String> _likedPetCardIds = {};

  final ScrollController _catScrollController = ScrollController();
  final ScrollController _dogScrollController = ScrollController();
  bool _showTopBtn = false;

  final String _catVariantApiUrl =
      'https://api.keepers-note.o-r.kr/api/cat-variants?uploadedOnly=true';
  final String _dogVariantApiUrl =
      'https://api.keepers-note.o-r.kr/api/dog-variants?uploadedOnly=true';
  final String _baseUrl = 'https://api.keepers-note.o-r.kr';

  List<PetCatalogVariant> _catVariants = [];
  List<PetCatalogVariant> _dogVariants = [];

  final Set<String> _selectedBreedFilters = {};
  final Set<String> _selectedColorFilters = {};
  final Set<String> _selectedEyeStyleFilters = {};
  final Set<String> _selectedEyeColorFilters = {};

  PetSortType _selectedPetSort = PetSortType.name;

  final Set<String> _likedVariantIds = {};

  final Map<String, int> _variantLikeCounts = {};
  bool _isLikeSubmitting = false;

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
  String? _serverUserId;

  Pet? _draggingPet;
  bool _showDeleteDropZone = false;

  final String _petApiUrl = 'https://api.keepers-note.o-r.kr/api/pets';
  final String _fishApiUrl = 'https://api.keepers-note.o-r.kr/api/fish';
  final String _petLikeApiUrl = 'https://api.keepers-note.o-r.kr/api/pet-likes';

  final String _catSnackOptionsApiUrl =
      'https://api.keepers-note.o-r.kr/api/pets/cat-snack-options';
  final String _dogSnackOptionsApiUrl =
      'https://api.keepers-note.o-r.kr/api/pets/dog-snack-options';

  List<PetSnackOption> _catSnackOptions = [];
  List<PetSnackOption> _dogSnackOptions = [];

  String _resolvePetImageUrl(String? path) {
    if (path == null || path
        .trim()
        .isEmpty) return '';

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
    if (path == null || path
        .trim()
        .isEmpty) return false;
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
        _fetchLikedVariantIds();
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
    setState(() => _isLoading = true);

    await _loadUserInfo();

    await Future.wait([
      _fetchPetSnackOptions(),
      _fetchFishData(),
      _fetchCatalogData(),
    ]);

    await _fetchPetData();
    await _fetchLikedVariantIds();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPetSnackOptions() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse(_catSnackOptionsApiUrl)),
        http.get(Uri.parse(_dogSnackOptionsApiUrl)),
      ]);

      final catResponse = responses[0];
      final dogResponse = responses[1];

      if (catResponse.statusCode == 200) {
        final List<dynamic> data =
        jsonDecode(utf8.decode(catResponse.bodyBytes)) as List<dynamic>;

        _catSnackOptions = data
            .map((e) => PetSnackOption.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        void ensureCatSnackOption({
          required String itemId,
          required String nameKo,
          required String imagePath,
        }) {
          final exists = _catSnackOptions.any(
                (e) => e.sourceType == 'snack' && e.itemId == itemId,
          );

          if (!exists) {
            _catSnackOptions.add(
              PetSnackOption(
                sourceType: 'snack',
                itemId: itemId,
                nameKo: nameKo,
                imagePath: imagePath,
                category: 'snack',
              ),
            );
          }
        }

        ensureCatSnackOption(
          itemId: 'cat_food',
          nameKo: '고양이 사료',
          imagePath: 'assets/images/snacks/feed_cat.png',
        );

        ensureCatSnackOption(
          itemId: 'common_food',
          nameKo: '공용 사료',
          imagePath: 'assets/images/snacks/feed_common.png',
        );

        _catSnackOptions.sort(
              (a, b) =>
              _snackOptionDisplayName(a).compareTo(_snackOptionDisplayName(b)),
        );
      } else {
        debugPrint('고양이 간식 옵션 조회 실패: ${catResponse.statusCode}');
        _catSnackOptions = [
          PetSnackOption(
            sourceType: 'snack',
            itemId: 'cat_food',
            nameKo: '고양이 사료',
            imagePath: 'assets/images/snacks/feed_cat.png',
            category: 'snack',
          ),
          PetSnackOption(
            sourceType: 'snack',
            itemId: 'common_food',
            nameKo: '공용 사료',
            imagePath: 'assets/images/snacks/feed_common.png',
            category: 'snack',
          ),
        ];
      }

      if (dogResponse.statusCode == 200) {
        final List<dynamic> data =
        jsonDecode(utf8.decode(dogResponse.bodyBytes)) as List<dynamic>;

        _dogSnackOptions = data
            .map((e) => PetSnackOption.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        _dogSnackOptions.sort(
              (a, b) =>
              _snackOptionDisplayName(a).compareTo(_snackOptionDisplayName(b)),
        );
      } else {
        debugPrint('강아지 간식 옵션 조회 실패: ${dogResponse.statusCode}');
        _dogSnackOptions = [];
      }
    } catch (e) {
      debugPrint('간식 옵션 로드 실패: $e');

      _catSnackOptions = [
        PetSnackOption(
          sourceType: 'snack',
          itemId: 'cat_food',
          nameKo: '고양이 사료',
          imagePath: 'assets/images/snacks/feed_cat.png',
          category: 'snack',
        ),
        PetSnackOption(
          sourceType: 'snack',
          itemId: 'common_food',
          nameKo: '공용 사료',
          imagePath: 'assets/images/snacks/feed_common.png',
          category: 'snack',
        ),
      ];

      _dogSnackOptions = [];
    }
  }

  Map<String, dynamic> _buildPetUpsertBody(Pet pet, {
    String? overrideImagePath,
  }) {
    return {
      "userId": int.parse(_serverUserId!),
      "name": pet.name,
      "memo": pet.memo,
      "color": pet.color,
      "catVariantId": pet.catVariantId,
      "dogVariantId": pet.dogVariantId,
      "favoriteSnacks": pet.favoriteSnacks.map((e) => e.toJson()).toList(),
      "dislikedSnacks": pet.dislikedSnacks.map((e) => e.toJson()).toList(),
      "triedSnacks": pet.triedSnacks.map((e) => e.toJson()).toList(),
      "isCat": pet.isCat,
      "imagePath": overrideImagePath ?? pet.imagePath,
    };
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1) 이미 저장된 server userId가 있으면 먼저 사용
      final cachedUserId = prefs.getString('userId');
      if (cachedUserId != null && cachedUserId.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _serverUserId = cachedUserId;
        });
        return;
      }

      // 2) 없을 때만 provider 기반으로 서버 재동기화
      final provider = prefs.getString('authProvider');
      final providerUserId = prefs.getString('providerUserId');
      final nickname = prefs.getString('nickname') ?? '사용자';
      final profileImageUrl = prefs.getString('profileImageUrl');

      if (provider == null || provider.isEmpty) {
        throw Exception('authProvider 없음');
      }

      if (providerUserId == null || providerUserId.isEmpty) {
        throw Exception('providerUserId 없음');
      }

      final response = await http.post(
        Uri.parse('https://api.keepers-note.o-r.kr/api/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider': provider,
          'providerUserId': providerUserId,
          'nickname': nickname,
          'profileImageUrl': profileImageUrl,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('userId 조회 실패: ${response.statusCode}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final serverUserId = data['id']?.toString();

      if (serverUserId == null || serverUserId.isEmpty) {
        throw Exception('serverUserId 없음');
      }

      await prefs.setString('userId', serverUserId);

      if (!mounted) return;
      setState(() {
        _serverUserId = serverUserId;
      });
    } catch (e) {
    }
  }

  Future<void> _fetchCatalogData() async {
    try {
      final results = await Future.wait([
        http.get(Uri.parse(_catVariantApiUrl)),
        http.get(Uri.parse(_dogVariantApiUrl)),
      ]);

      final catResponse = results[0];
      final dogResponse = results[1];

      if (catResponse.statusCode == 200) {
        final List<dynamic> raw =
        jsonDecode(utf8.decode(catResponse.bodyBytes)) as List<dynamic>;
        _catVariants = raw
            .map((e) =>
            PetCatalogVariant.fromCatJson(e as Map<String, dynamic>))
            .where((e) =>
        e.isUploaded && (e.imagePath ?? '')
            .trim()
            .isNotEmpty)
            .toList();
      } else {
        _catVariants = [];
      }

      if (dogResponse.statusCode == 200) {
        final List<dynamic> raw =
        jsonDecode(utf8.decode(dogResponse.bodyBytes)) as List<dynamic>;
        _dogVariants = raw
            .map((e) =>
            PetCatalogVariant.fromDogJson(e as Map<String, dynamic>))
            .where((e) =>
        e.isUploaded && (e.imagePath ?? '')
            .trim()
            .isNotEmpty)
            .toList();
      } else {
        _dogVariants = [];
      }
    } catch (e) {
      _catVariants = [];
      _dogVariants = [];
    }
  }

  Future<void> _fetchPetData() async {
    if (_serverUserId == null || _serverUserId!.isEmpty) return;

    try {
      setState(() => _isLoading = true);

      final response = await http.get(
        Uri.parse('$_petApiUrl/user/$_serverUserId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));

        setState(() {
          _allPets = data.map((json) => Pet.fromJson(json)).toList();
          _allPets.sort(
                (a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0),
          );
        });
      } else {
      }
    } catch (e) {
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
    }
  }

  Future<void> _fetchLikedVariantIds() async {
    if (_serverUserId == null || _serverUserId!.isEmpty) {
      await _loadUserInfo();
    }

    final bool isCatTab = _tabController.index == 0;
    final String petType = isCatTab ? 'cat' : 'dog';

    try {
      final response = await http.get(
        Uri.parse('$_petLikeApiUrl?userId=$_serverUserId&petType=$petType'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        final List<dynamic> rawIds =
        (data['likedVariantIds'] ?? []) as List<dynamic>;

        if (!mounted) return;

        setState(() {
          _likedVariantIds
            ..clear()
            ..addAll(rawIds.map((e) => e.toString()));
        });
      } else {
      }
    } catch (e) {
    }
  }

  String _petSortLabel(PetSortType type) {
    switch (type) {
      case PetSortType.name:
        return '이름순';
      case PetSortType.collectedCount:
        return '많은순';
      case PetSortType.liked:
        return '좋아요순';
    }
  }

  int _breedLikeScore(String breedName, List<PetCatalogVariant> items) {
    return items
        .where((item) => _likedVariantIds.contains(item.id))
        .length;
  }

  Future<void> _updatePetOrderOnServer() async {
    if (_serverUserId == null || _allPets.isEmpty) return;

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
    } catch (e) {
    }
  }

  Future<void> _savePetToServer(
      String name,
      String color,
      String memo,
      PetCatalogVariant selectedVariant,
      String? imagePath, {
        int? existingId,
        Set<PetSnackChoice>? favoriteSnacks,
        Set<PetSnackChoice>? dislikedSnacks,
        Set<PetSnackChoice>? triedSnacks,
      }) async {
    try {
      if (_serverUserId == null || _serverUserId!.isEmpty) {
        await _loadUserInfo();
      }

      if (_serverUserId == null || _serverUserId!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용자 정보를 불러오는 중이에요. 잠시 후 다시 시도해주세요.'),
            ),
          );
        }
        return;
      }

      final bool isCat = selectedVariant.isCat;
      final String trimmedImagePath = imagePath?.trim() ?? '';

      final bool isRemoteImage =
          trimmedImagePath.startsWith('http://') ||
              trimmedImagePath.startsWith('https://') ||
              trimmedImagePath.startsWith('/uploads/');

      final bool isExistingLocalFile =
          trimmedImagePath.isNotEmpty && File(trimmedImagePath).existsSync();

      final bool isLocalFile = !isRemoteImage && isExistingLocalFile;

      final Map<String, dynamic> body = {
        "userId": int.parse(_serverUserId!),
        "name": name,
        "memo": memo,
        "color": color,
        "catVariantId": isCat ? selectedVariant.id : null,
        "dogVariantId": !isCat ? selectedVariant.id : null,
        "favoriteSnacks":
        (favoriteSnacks ?? <PetSnackChoice>{}).map((e) => e.toJson()).toList(),
        "dislikedSnacks":
        (dislikedSnacks ?? <PetSnackChoice>{}).map((e) => e.toJson()).toList(),
        "triedSnacks":
        (triedSnacks ?? <PetSnackChoice>{}).map((e) => e.toJson()).toList(),
        "isCat": isCat,
        "imagePath": isLocalFile
            ? null
            : (trimmedImagePath.isEmpty ? null : trimmedImagePath),
      };

      final Uri uri = existingId == null
          ? Uri.parse(_petApiUrl)
          : Uri.parse('$_petApiUrl/$existingId');

      final http.Response response = existingId == null
          ? await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      )
          : await http.put(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('펫 저장 실패: ${response.statusCode} ${response.body}');
      }

      final Map<String, dynamic> savedData =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      Pet savedPet = Pet.fromJson(savedData);

      if (isLocalFile && savedPet.id != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_petApiUrl/${savedPet.id}/image'),
        );

        request.files.add(
          await http.MultipartFile.fromPath('file', trimmedImagePath),
        );

        final streamed = await request.send();
        final imageResponse = await http.Response.fromStream(streamed);

        if (imageResponse.statusCode >= 200 && imageResponse.statusCode < 300) {
          final Map<String, dynamic> imageSaved =
          jsonDecode(utf8.decode(imageResponse.bodyBytes))
          as Map<String, dynamic>;
          savedPet = Pet.fromJson(imageSaved);
        } else {
          debugPrint(
            '펫 이미지 업로드 실패: ${imageResponse.statusCode} ${imageResponse.body}',
          );
        }
      }

      if (!mounted) return;

      await _fetchPetData();
    } catch (e) {
      debugPrint('펫 저장 에러: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('펫 저장 중 오류가 발생했어요.')),
      );
      rethrow;
    }
  }

  Future<void> _updatePetSnacks(Pet pet) async {
    if (_serverUserId == null || pet.id == null) return;

    try {
      await http.put(
        Uri.parse('$_petApiUrl/${pet.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_buildPetUpsertBody(pet)),
      );
    } catch (e) {
    }
  }

  List<PetSnackOption> _snackOptionsForPet(Pet pet) {
    return pet.isCat ? _catSnackOptions : _dogSnackOptions;
  }

  bool _containsSnackChoice(Set<PetSnackChoice> set, PetSnackOption option) {
    return set.any(
          (e) => e.sourceType == option.sourceType && e.itemId == option.itemId,
    );
  }

  Set<PetSnackChoice> _toggleSnackChoice(Set<PetSnackChoice> source,
      PetSnackOption option,) {
    final next = Set<PetSnackChoice>.from(source);
    final target = PetSnackChoice(
      sourceType: option.sourceType,
      itemId: option.itemId,
    );

    if (next.contains(target)) {
      next.remove(target);
    } else {
      next.add(target);
    }
    return next;
  }

  String _snackOptionDisplayName(PetSnackOption option) {
    return option.nameKo
        .trim()
        .isNotEmpty ? option.nameKo.trim() : option.itemId;
  }

  String _displaySnackChoiceLabel(PetSnackChoice choice) {
    final List<PetSnackOption> allOptions = [
      ..._catSnackOptions,
      ..._dogSnackOptions,
    ];

    for (final option in allOptions) {
      if (option.sourceType == choice.sourceType &&
          option.itemId == choice.itemId) {
        return _snackOptionDisplayName(option);
      }
    }

    return choice.itemId;
  }

  String _primaryFavoriteSnackLabel(Pet pet) {
    if (pet.favoriteSnacks.isEmpty) return '아직 없음';
    return _displaySnackChoiceLabel(pet.favoriteSnacks.first);
  }

  String _favoriteSnackSummaryLabel(Pet pet) {
    if (pet.favoriteSnacks.isEmpty) return '아직 없음';
    if (pet.favoriteSnacks.length == 1) {
      return _displaySnackChoiceLabel(pet.favoriteSnacks.first);
    }
    return '${_displaySnackChoiceLabel(pet.favoriteSnacks.first)} 외 ${pet
        .favoriteSnacks.length - 1}개';
  }

  String _petProfileTypeLabel(Pet pet) {
    final variantId = pet.catVariantId ?? pet.dogVariantId;

    if (variantId == null || variantId.isEmpty) {
      final color = (pet.color ?? '').trim();
      return color.isEmpty ? '선택 안됨' : color;
    }

    final variantList = pet.isCat ? _catVariants : _dogVariants;

    try {
      final variant = variantList.firstWhere((v) => v.id == variantId);

      final breed = variant.breedName.trim();
      final color = variant.colorName.trim().isNotEmpty
          ? variant.colorName.trim()
          : (pet.color ?? '').trim();

      if (breed.isEmpty && color.isEmpty) return '선택 안됨';
      if (breed.isEmpty) return color;

      final normalizedBreed = breed.replaceAll(' ', '');
      final normalizedColor = color.replaceAll(' ', '');

      if (normalizedColor.isNotEmpty &&
          normalizedBreed.contains(normalizedColor)) {
        return breed;
      }

      const fixedBreedOnlyKeywords = [
        '올블랙',
        '올화이트',
        '올그레이',
        '올브라운',
        '러시안블루',
      ];

      if (fixedBreedOnlyKeywords.any((e) => normalizedBreed.contains(e))) {
        if (normalizedBreed.contains('러시안블루')) {
          return '러시안 블루';
        }
        return breed;
      }

      if (normalizedBreed.contains('골든리트리버')) {
        return '골든 리트리버';
      }
      if (normalizedBreed.contains('래브라도리트리버')) {
        return '래브라도 리트리버';
      }

      return color.isEmpty ? breed : '$color $breed';
    } catch (_) {
      final color = (pet.color ?? '').trim();
      return color.isEmpty ? '선택 안됨' : color;
    }
  }

  Widget _buildPetImage(String? imagePath, {
    BoxFit fit = BoxFit.cover,
  }) {
    final bool hasLocalFile =
        imagePath != null && imagePath.isNotEmpty &&
            File(imagePath).existsSync();
    final bool isRemote = _isRemotePetImage(imagePath);
    final String remoteUrl = _resolvePetImageUrl(imagePath);

    if (hasLocalFile) {
      return Image.file(
        File(imagePath!),
        fit: fit,
        errorBuilder: (_, __, ___) =>
        const Icon(
          Icons.pets_rounded,
          color: Color(0xFFFF8E7C),
        ),
      );
    }

    if (isRemote) {
      return Image.network(
        remoteUrl,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            Image.asset(
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

  List<PetCatalogVariant> _currentVariantList(bool isCat) {
    return isCat ? _catVariants : _dogVariants;
  }

  bool _matchesVariantFilters(PetCatalogVariant item) {
    final bool breedAll =
        _selectedBreedFilters.isEmpty || _selectedBreedFilters.contains('전체');
    final bool colorAll =
        _selectedColorFilters.isEmpty || _selectedColorFilters.contains('전체');
    final bool eyeStyleAll =
        _selectedEyeStyleFilters.isEmpty ||
            _selectedEyeStyleFilters.contains('전체');
    final bool eyeColorAll =
        _selectedEyeColorFilters.isEmpty ||
            _selectedEyeColorFilters.contains('전체');

    if (!breedAll && !_selectedBreedFilters.contains(item.breedName)) {
      return false;
    }
    if (!colorAll && !_selectedColorFilters.contains(item.colorName)) {
      return false;
    }
    if (!eyeStyleAll && !_selectedEyeStyleFilters.contains(item.eyeStyleKo)) {
      return false;
    }

    final eyeColor = (item.eyeColorNameKo ?? '미지정');
    if (!eyeColorAll && !_selectedEyeColorFilters.contains(eyeColor)) {
      return false;
    }

    return true;
  }

  Map<String, List<PetCatalogVariant>> _groupVariantsByBreed({
    required bool isCat,
  }) {
    const eyeOrder = ['콩눈', '땡눈', '고양이눈', '졸린눈'];

    int eyeStyleRank(String value) {
      final index = eyeOrder.indexOf(value.trim());
      return index == -1 ? 999 : index;
    }

    List<PetCatalogVariant> interleaveByColor(List<PetCatalogVariant> items) {
      final Map<String, List<PetCatalogVariant>> byColor = {};

      for (final item in items) {
        final colorKey = item.colorName
            .trim()
            .isEmpty ? '기본' : item.colorName.trim();
        byColor.putIfAbsent(colorKey, () => []);
        byColor[colorKey]!.add(item);
      }

      final colorKeys = byColor.keys.toList()
        ..sort();

      for (final color in colorKeys) {
        byColor[color]!.sort((a, b) {
          final eyeColorCompare =
          (a.eyeColorNameKo ?? '').compareTo(b.eyeColorNameKo ?? '');
          if (eyeColorCompare != 0) return eyeColorCompare;

          final noCompare = a.variantNo.compareTo(b.variantNo);
          if (noCompare != 0) return noCompare;

          return a.id.compareTo(b.id);
        });
      }

      final List<PetCatalogVariant> arranged = [];
      int addedCount = 0;

      while (true) {
        bool addedInRound = false;

        for (final color in colorKeys) {
          final list = byColor[color]!;
          if (addedCount < list.length) {
            arranged.add(list[addedCount]);
            addedInRound = true;
          }
        }

        if (!addedInRound) break;
        addedCount++;
      }

      return arranged;
    }

    final filtered = _currentVariantList(isCat)
        .where(_matchesVariantFilters)
        .toList();

    final Map<String, List<PetCatalogVariant>> groupedByBreed = {};

    for (final item in filtered) {
      groupedByBreed.putIfAbsent(item.breedName, () => []);
      groupedByBreed[item.breedName]!.add(item);
    }

    final Map<String, List<PetCatalogVariant>> result = {};

    final breedNames = groupedByBreed.keys.toList()
      ..sort((a, b) {
        switch (_selectedPetSort) {
          case PetSortType.name:
            return a.compareTo(b);

          case PetSortType.collectedCount:
            final countCompare =
            groupedByBreed[b]!.length.compareTo(groupedByBreed[a]!.length);
            if (countCompare != 0) return countCompare;
            return a.compareTo(b);

          case PetSortType.liked:
            final likeA = _breedLikeScore(a, groupedByBreed[a]!);
            final likeB = _breedLikeScore(b, groupedByBreed[b]!);
            final likeCompare = likeB.compareTo(likeA);
            if (likeCompare != 0) return likeCompare;

            final countCompare =
            groupedByBreed[b]!.length.compareTo(groupedByBreed[a]!.length);
            if (countCompare != 0) return countCompare;

            return a.compareTo(b);
        }
      });

    for (final breedName in breedNames) {
      final items = groupedByBreed[breedName]!;

      final Map<String, List<PetCatalogVariant>> byEyeStyle = {
        for (final eye in eyeOrder) eye: [],
      };
      final List<PetCatalogVariant> others = [];

      for (final item in items) {
        final eye = item.eyeStyleKo.trim();
        if (byEyeStyle.containsKey(eye)) {
          byEyeStyle[eye]!.add(item);
        } else {
          others.add(item);
        }
      }

      final Map<String, List<PetCatalogVariant>> arrangedByEye = {};
      for (final eye in eyeOrder) {
        arrangedByEye[eye] = interleaveByColor(byEyeStyle[eye]!);
      }

      others.sort((a, b) {
        final eyeCompare =
        eyeStyleRank(a.eyeStyleKo).compareTo(eyeStyleRank(b.eyeStyleKo));
        if (eyeCompare != 0) return eyeCompare;

        final colorCompare = a.colorName.compareTo(b.colorName);
        if (colorCompare != 0) return colorCompare;

        final eyeColorCompare =
        (a.eyeColorNameKo ?? '').compareTo(b.eyeColorNameKo ?? '');
        if (eyeColorCompare != 0) return eyeColorCompare;

        final noCompare = a.variantNo.compareTo(b.variantNo);
        if (noCompare != 0) return noCompare;

        return a.id.compareTo(b.id);
      });

      final List<PetCatalogVariant> arranged = [];
      int rowIndex = 0;

      while (true) {
        bool addedInRound = false;

        for (final eye in eyeOrder) {
          final list = arrangedByEye[eye]!;
          if (rowIndex < list.length) {
            arranged.add(list[rowIndex]);
            addedInRound = true;
          }
        }

        if (!addedInRound) break;
        rowIndex++;
      }

      arranged.addAll(others);
      result[breedName] = arranged;
    }

    return result;
  }

  List<String> _availableBreedFilters({required bool isCat}) {
    final items = _currentVariantList(isCat)
        .map((e) => e.breedName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ['전체', ...items];
  }

  List<String> _availableColorFilters({required bool isCat}) {
    final items = _currentVariantList(isCat)
        .map((e) => e.colorName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ['전체', ...items];
  }

  List<String> _availableEyeStyleFilters({required bool isCat}) {
    final items = _currentVariantList(isCat)
        .map((e) => e.eyeStyleKo.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ['전체', ...items];
  }

  List<String> _availableEyeColorFilters({required bool isCat}) {
    final items = _currentVariantList(isCat)
        .map((e) => (e.eyeColorNameKo ?? '미지정').trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ['전체', ...items];
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

  List<PetSnackOption> _buildVisibleSnackOptions(Pet pet) {
    final query = _snackSearchQuery.trim().toLowerCase();
    final options = List<PetSnackOption>.from(_snackOptionsForPet(pet));

    if (query.isEmpty) {
      options.sort(
            (a, b) => _snackOptionDisplayName(a)
            .compareTo(_snackOptionDisplayName(b)),
      );
      return options;
    }

    int score(PetSnackOption option) {
      final name = _snackOptionDisplayName(option).toLowerCase();
      final itemId = option.itemId.toLowerCase().replaceAll('_', ' ');
      int s = 0;

      if (name == query) s += 120;
      if (itemId == query) s += 100;
      if (name.startsWith(query)) s += 60;
      if (itemId.startsWith(query)) s += 45;
      if (name.contains(query)) s += 24;
      if (itemId.contains(query)) s += 18;

      return s;
    }

    final filtered = options.where((option) {
      final name = _snackOptionDisplayName(option).toLowerCase();
      final itemId = option.itemId.toLowerCase().replaceAll('_', ' ');
      return name.contains(query) || itemId.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final scoreCompare = score(b).compareTo(score(a));
      if (scoreCompare != 0) return scoreCompare;
      return _snackOptionDisplayName(a).compareTo(_snackOptionDisplayName(b));
    });

    return filtered;
  }

  void _clearSnackHighlightLater(String optionKey) {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_highlightedSnackFishId == optionKey) {
        setState(() => _highlightedSnackFishId = null);
      }
    });
  }

  void _scrollSnackOptionToTop(Pet pet, String optionKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_snackFishScrollController.hasClients) return;

      final visibleOptions = _buildVisibleSnackOptions(pet);
      final index = visibleOptions.indexWhere((option) => option.key == optionKey);
      if (index < 0) return;

      _snackFishScrollController.animateTo(
        index * 104.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _submitSnackSearch(Pet pet, StateSetter setSheetState) {
    final query = _snackSearchController.text.trim();

    setSheetState(() {
      _snackSearchQuery = query;
      _submittedSnackQuery = query.isEmpty ? null : query;
    });

    final visibleOptions = _buildVisibleSnackOptions(pet);
    if (visibleOptions.isEmpty) return;

    final target = visibleOptions.first;

    setSheetState(() => _highlightedSnackFishId = target.key);
    _scrollSnackOptionToTop(pet, target.key);
    _clearSnackHighlightLater(target.key);
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

  Widget _buildPetFilterActionButton() {
    bool hasRealFilter(Set<String> values) {
      return values.isNotEmpty && !values.contains('전체');
    }

    final bool hasAnyFilter =
        hasRealFilter(_selectedBreedFilters) ||
            hasRealFilter(_selectedColorFilters) ||
            hasRealFilter(_selectedEyeStyleFilters) ||
            hasRealFilter(_selectedEyeColorFilters);

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
                  isPressed ? 0.98 : 0.95,
                )
                    : Colors.white.withOpacity(isPressed ? 0.98 : 0.92),
                borderRadius: BorderRadius.circular(20),
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
                    hasAnyFilter ? '필터 / 정렬 적용' : '필터 / 정렬',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: hasAnyFilter
                          ? const Color(0xFFFF8E7C)
                          : const Color(0xFFE58F7C),
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

  void _showPetFilterSheet() {
    final bool isCatTab = _tabController.index == 0;

    final tempBreed = Set<String>.from(_selectedBreedFilters);
    final tempColor = Set<String>.from(_selectedColorFilters);
    final tempEyeStyle = Set<String>.from(_selectedEyeStyleFilters);
    final tempEyeColor = Set<String>.from(_selectedEyeColorFilters);
    PetSortType tempSort = _selectedPetSort;

    if (tempBreed.isEmpty) tempBreed.add('전체');
    if (tempColor.isEmpty) tempColor.add('전체');
    if (tempEyeStyle.isEmpty) tempEyeStyle.add('전체');
    if (tempEyeColor.isEmpty) tempEyeColor.add('전체');

    final breedFilters = _availableBreedFilters(isCat: isCatTab);
    final colorFilters = _availableColorFilters(isCat: isCatTab);
    final eyeStyleFilters = _availableEyeStyleFilters(isCat: isCatTab);
    final eyeColorFilters = _availableEyeColorFilters(isCat: isCatTab);

    void syncDependentLocks() {
      final bool lockColor = _shouldLockColorFilter(
        isCat: isCatTab,
        selectedBreeds: tempBreed,
      );

      if (lockColor) {
        final fixedColor = _fixedColorForBreed(
          isCat: isCatTab,
          breedName: tempBreed.first,
        );

        tempColor..clear();

        if (fixedColor != null && fixedColor.isNotEmpty) {
          tempColor.add(fixedColor);
        }
      }

      final bool lockEyeColor = _shouldLockEyeColorFilter(
        isCat: isCatTab,
        selectedEyeStyles: tempEyeStyle,
      );

      if (lockEyeColor) {
        final fixedEyeColor = _fixedEyeColorForEyeStyle(
          isCat: isCatTab,
          eyeStyleKo: tempEyeStyle.first,
        );

        tempEyeColor..clear();

        if (fixedEyeColor != null && fixedEyeColor.isNotEmpty) {
          tempEyeColor.add(fixedEyeColor);
        }
      }
    }

    syncDependentLocks();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bool lockColor = _shouldLockColorFilter(
              isCat: isCatTab,
              selectedBreeds: tempBreed,
            );

            final bool lockEyeColor = _shouldLockEyeColorFilter(
              isCat: isCatTab,
              selectedEyeStyles: tempEyeStyle,
            );

            final String? fixedColorLabel = lockColor
                ? _fixedColorForBreed(
              isCat: isCatTab,
              breedName: tempBreed.first,
            )
                : null;

            final String? fixedEyeColorLabel = lockEyeColor
                ? _fixedEyeColorForEyeStyle(
              isCat: isCatTab,
              eyeStyleKo: tempEyeStyle.first,
            )
                : null;

            Widget buildSection(String title,
                List<String> filters,
                Set<String> selected, {
                  bool disabled = false,
                  String? helperText,
                  VoidCallback? onAnyTapAfter,
                }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: filters.map((filter) {
                      final isSelected = selected.contains(filter);

                      return Opacity(
                        opacity: disabled ? 0.45 : 1.0,
                        child: IgnorePointer(
                          ignoring: disabled,
                          child: _buildPopupFilterChip(
                            label: filter,
                            isSelected: isSelected,
                            onTap: () {
                              setSheetState(() {
                                if (filter == '전체') {
                                  selected
                                    ..clear()
                                    ..add('전체');
                                } else {
                                  selected.remove('전체');

                                  if (isSelected) {
                                    selected.remove(filter);
                                  } else {
                                    selected.add(filter);
                                  }

                                  if (selected.isEmpty) {
                                    selected.add('전체');
                                  }
                                }

                                onAnyTapAfter?.call();
                              });
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (helperText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      helperText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAA8E86),
                      ),
                    ),
                  ],
                ],
              );
            }

            Widget buildSortSection() {
              Widget buildSortChip(PetSortType type) {
                final bool isSelected = tempSort == type;

                return _buildPopupFilterChip(
                  label: _petSortLabel(type),
                  isSelected: isSelected,
                  onTap: () {
                    setSheetState(() {
                      tempSort = type;
                    });
                  },
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '정렬',
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
                    children: [
                      buildSortChip(PetSortType.name),
                      buildSortChip(PetSortType.collectedCount),
                      buildSortChip(PetSortType.liked),
                    ],
                  ),
                ],
              );
            }

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
                child: SingleChildScrollView(
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

                      buildSortSection(),

                      const SizedBox(height: 22),

                      buildSection(
                        isCatTab ? '종류' : '견종',
                        breedFilters,
                        tempBreed,
                        onAnyTapAfter: syncDependentLocks,
                      ),

                      const SizedBox(height: 18),

                      buildSection(
                        '털색',
                        colorFilters,
                        tempColor,
                        disabled: lockColor,
                        helperText: lockColor
                            ? '선택한 종은 단색 외형이라 털색이 ${fixedColorLabel ??
                            '자동'}으로 고정돼요.'
                            : null,
                      ),

                      const SizedBox(height: 18),

                      buildSection(
                        '눈 모양',
                        eyeStyleFilters,
                        tempEyeStyle,
                        onAnyTapAfter: syncDependentLocks,
                      ),

                      const SizedBox(height: 18),

                      buildSection(
                        '눈 색',
                        eyeColorFilters,
                        tempEyeColor,
                        disabled: lockEyeColor,
                        helperText: lockEyeColor
                            ? '선택한 눈 모양은 눈 색이 ${fixedEyeColorLabel ??
                            '자동'}으로 고정돼요.'
                            : null,
                      ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedPetSort = PetSortType.name;
                                  _selectedBreedFilters
                                    ..clear()
                                    ..add('전체');
                                  _selectedColorFilters
                                    ..clear()
                                    ..add('전체');
                                  _selectedEyeStyleFilters
                                    ..clear()
                                    ..add('전체');
                                  _selectedEyeColorFilters
                                    ..clear()
                                    ..add('전체');
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
                                  _selectedPetSort = tempSort;

                                  _selectedBreedFilters
                                    ..clear()
                                    ..addAll(
                                        tempBreed.isEmpty ? {'전체'} : tempBreed);

                                  _selectedColorFilters
                                    ..clear()
                                    ..addAll(
                                        tempColor.isEmpty ? {'전체'} : tempColor);

                                  _selectedEyeStyleFilters
                                    ..clear()
                                    ..addAll(
                                      tempEyeStyle.isEmpty
                                          ? {'전체'}
                                          : tempEyeStyle,
                                    );

                                  _selectedEyeColorFilters
                                    ..clear()
                                    ..addAll(
                                      tempEyeColor.isEmpty
                                          ? {'전체'}
                                          : tempEyeColor,
                                    );
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
              ),
            );
          },
        );
      },
    );
  }

  PetCatalogVariant? _firstVariantForEyeStyle({
    required bool isCat,
    required String eyeStyleKo,
  }) {
    try {
      return _currentVariantList(isCat).firstWhere(
            (v) => v.eyeStyleKo.trim() == eyeStyleKo.trim(),
      );
    } catch (_) {
      return null;
    }
  }


  bool _isSingleColorEyeStyle({
    required bool isCat,
    required String eyeStyleKo,
  }) {
    final variant = _firstVariantForEyeStyle(
      isCat: isCat,
      eyeStyleKo: eyeStyleKo,
    );
    return variant?.isEyeColorFixed ?? false;
  }

  String? _fixedEyeColorForEyeStyle({
    required bool isCat,
    required String eyeStyleKo,
  }) {
    final variant = _firstVariantForEyeStyle(
      isCat: isCat,
      eyeStyleKo: eyeStyleKo,
    );

    if (variant == null || !variant.isEyeColorFixed) return null;

    final fixedName = (variant.fixedEyeColorNameKo ?? '').trim();
    if (fixedName.isNotEmpty) return fixedName;

    final fallback = (variant.eyeColorNameKo ?? '').trim();
    return fallback.isEmpty ? null : fallback;
  }

  bool _shouldLockColorFilter({
    required bool isCat,
    required Set<String> selectedBreeds,
  }) {
    if (selectedBreeds.length != 1) return false;
    if (selectedBreeds.contains('전체')) return false;

    return _isSingleColorBreed(
      isCat: isCat,
      breedName: selectedBreeds.first,
    );
  }

  bool _shouldLockEyeColorFilter({
    required bool isCat,
    required Set<String> selectedEyeStyles,
  }) {
    if (selectedEyeStyles.length != 1) return false;
    if (selectedEyeStyles.contains('전체')) return false;

    return _isSingleColorEyeStyle(
      isCat: isCat,
      eyeStyleKo: selectedEyeStyles.first,
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

  void _openBreedDetail(String breed, List<PetCatalogVariant> items) {
    final bool isCat = items.isNotEmpty ? items.first.isCat : _tabController.index == 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetBreedDetailScreen(
          breed: breed,
          items: items,
          onPreview: _showVariantImagePreview,
          imageBuilder: _buildPetImage,
          likedIds: _likedVariantIds,
          onToggleLike: _toggleLikedVariant,
          catalogLabel: isCat ? '고양이 도감' : '강아지 도감',
        ),
      ),
    );
  }


  Widget _buildBreedCard({
    required String title,
    required List<PetCatalogVariant> items,
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
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openBreedDetail(title, items),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF8E7C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                    return _buildMiniVariantCard(item);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniVariantCard(PetCatalogVariant item) {
    final bool isFavorite = _likedVariantIds.contains(item.id);

    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F6).withOpacity(0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD8CF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8E7C).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showVariantImagePreview(item),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.36),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: _buildPetImage(
                          item.imagePath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    Positioned(
                      top: -4,
                      right: -4,
                      child: _buildFloatingHeartButton(
                        isLiked: isFavorite,
                        onTap: () => _toggleLikedVariant(item.id),
                        size: 30,
                        iconSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showVariantImagePreview(PetCatalogVariant item) {
    final String? imagePath = item.imagePath;
    final bool hasLocalFile =
        imagePath != null && imagePath.isNotEmpty &&
            File(imagePath).existsSync();
    final bool isRemote = _isRemotePetImage(imagePath);
    final String remoteUrl = _resolvePetImageUrl(imagePath);

    final detailText = [
      if (item.colorName
          .trim()
          .isNotEmpty) item.colorName,
      if (item.eyeStyleKo
          .trim()
          .isNotEmpty) item.eyeStyleKo,
      if ((item.eyeColorNameKo ?? '')
          .trim()
          .isNotEmpty) item.eyeColorNameKo!,
    ].join(' · ');

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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 20),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      AspectRatio(
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
                          errorBuilder: (_, __, ___) {
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
                      Positioned(
                        left: 82,
                        right: 82,
                        bottom: -48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.breedName,
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
                                  if (detailText.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      detailText,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.8,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF5F6B7A),
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ],
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

  void _showPetImagePreview(Pet pet) {
    final String? imagePath = pet.imagePath;
    final bool hasLocalFile =
        imagePath != null && imagePath.isNotEmpty &&
            File(imagePath).existsSync();
    final bool isRemote = _isRemotePetImage(imagePath);
    final String remoteUrl = _resolvePetImageUrl(imagePath);

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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 20),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      AspectRatio(
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
                          errorBuilder: (_, __, ___) {
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
                      Positioned(
                        left: 82,
                        right: 82,
                        bottom: -48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    pet.name,
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
                                  const SizedBox(height: 2),
                                  Text(
                                    _petProfileTypeLabel(pet),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.8,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF5F6B7A),
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
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
    final pets = _allPets.where((p) => p.isCat == isCatTab).toList();

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
        await _fetchCatalogData();
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
          _buildPetGridContent(),
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
    final bool isCatTab = _tabController.index == 0;
    final sections = _groupVariantsByBreed(isCat: isCatTab);

    if (sections.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
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
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 36,
              color: const Color(0xFFFF8E7C).withOpacity(0.75),
            ),
            const SizedBox(height: 10),
            Text(
              isCatTab ? '해당 고양이는 데이터 수집 중이에요!' : '해당 강아지는 데이터 수집 중이에요!',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '데이터가 보이면 도감에 추가할 예정이에요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF8E8E93),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sections.entries.map(
              (entry) =>
              _buildPetCollectionCard(
                title: entry.key,
                items: entry.value,
              ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _toggleLikedVariant(String variantId) async {
    if (_isLikeSubmitting) return;

    if (_serverUserId == null || _serverUserId!.isEmpty) {
      await _loadUserInfo();
    }

    if (_serverUserId == null || _serverUserId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사용자 정보를 불러오는 중이에요. 잠시 후 다시 시도해주세요.'),
          ),
        );
      }
      return;
    }

    final bool isCatTab = _tabController.index == 0;
    final String petType = isCatTab ? 'cat' : 'dog';
    final bool wasLiked = _likedVariantIds.contains(variantId);

    if (mounted) {
      setState(() {
        if (wasLiked) {
          _likedVariantIds.remove(variantId);
        } else {
          _likedVariantIds.add(variantId);
        }
        _isLikeSubmitting = true;
      });
    }

    try {
      final Uri uri = Uri.parse(
        '$_petLikeApiUrl/toggle'
            '?userId=$_serverUserId'
            '&petType=$petType'
            '&variantId=$variantId',
      );

      final response = await http.post(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        final bool liked = data['liked'] == true;
        final int likeCount = (data['likeCount'] as num?)?.toInt() ?? 0;

        if (!mounted) return;

        setState(() {
          if (liked) {
            _likedVariantIds.add(variantId);
          } else {
            _likedVariantIds.remove(variantId);
          }
          _variantLikeCounts[variantId] = likeCount;
        });
      } else {
        throw Exception('좋아요 토글 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {

      if (!mounted) return;

      setState(() {
        if (wasLiked) {
          _likedVariantIds.add(variantId);
        } else {
          _likedVariantIds.remove(variantId);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('좋아요 처리 중 오류가 발생했어요.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLikeSubmitting = false;
        });
      }
    }
  }

  Widget _buildPetCollectionCard({
    required String title,
    required List<PetCatalogVariant> items,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openBreedDetail(title, items),
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
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF8E7C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildMiniVariantCard(item);
                  },
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

    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth < 390 ? 280 : 296;

    return SizedBox(
      height: 100,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 4, right: 10),
        itemCount: filteredPets.length,
        buildDefaultDragHandles: false,
        proxyDecorator: (Widget child, int index, Animation<double> animation) {
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
              reorderHandle: ReorderableDelayedDragStartListener(
                index: index,
                child: _buildPetReorderHandle(),
              ),
            ),
          );
        },
        onReorderStart: (index) {
          if (index < 0 || index >= filteredPets.length) return;
          setState(() {
            _draggingPet = filteredPets[index];
            _showDeleteDropZone = false;
          });
        },
        onReorderEnd: (index) {
          if (!mounted) return;
          setState(() {
            _draggingPet = null;
            _showDeleteDropZone = false;
          });
        },
        onReorder: (oldIndex, newIndex) async {
          if (newIndex > oldIndex) newIndex -= 1;

          setState(() {
            final movedPet = filteredPets.removeAt(oldIndex);
            filteredPets.insert(newIndex, movedPet);

            final otherTabPets = _allPets.where((p) => p.isCat != isCatTab).toList();

            if (isCatTab) {
              _allPets = [...filteredPets, ...otherTabPets];
            } else {
              _allPets = [...otherTabPets, ...filteredPets];
            }
          });

          await _updatePetOrderOnServer();
        },
      ),
    );
  }

  Widget _buildPetReorderHandle({bool disabled = false}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: disabled ? 0.38 : 1.0,
      child: Container(
        width: 26,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.62),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFFFFDDD4).withOpacity(0.95),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8E7C).withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
                (_) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      _PetHandleDot(),
                      SizedBox(width: 3),
                      _PetHandleDot(),
                    ],
                  ),
                ),
          ),
        ),
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
                        ((pet.color ?? '')
                            .trim()
                            .isEmpty)
                            ? '선택 안됨'
                            : (pet.color ?? '').trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
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

  Widget _buildPetSummaryCard(
      Pet pet, {
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFDDD4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
                  onDraggableCanceled: (_, __) {
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
                  Material(
                    color: const Color(0xFFFFF4F1),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _showSnackLabSheet(pet),
                      child: Container(
                        width: 62,
                        height: 62,
                        padding: const EdgeInsets.all(6),
                        alignment: Alignment.center,
                        child: _buildSnackIconArea(pet),
                      ),
                    ),
                  ),
                if (reorderHandle != null) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 32,
                    height: 56,
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

  List<String> _pickerBreedOptions({required bool isCat}) {
    final items = _currentVariantList(isCat)
        .map((e) => e.breedName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (items.isEmpty) {
      return ['선택 안됨'];
    }

    return items;
  }

  List<String> _pickerColorOptions({required bool isCat, String? breedName}) {
    Iterable<PetCatalogVariant> variants = _currentVariantList(isCat);

    if (breedName != null && breedName.isNotEmpty && breedName != '선택 안됨') {
      variants = variants.where((v) => v.breedName.trim() == breedName.trim());
    }

    final items = variants
        .map((e) => e.colorName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (items.isEmpty) {
      return ['선택 안됨'];
    }

    return items;
  }

  Widget _buildPetSummaryMainArea(
      Pet pet, {
        bool dragging = false,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(20),
        ),
        onTap: () => _showPetEditSheet(pet: pet),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 0, 2),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showPetImagePreview(pet),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFD8CF),
                      width: 1.4,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: _buildPetImage(
                      pet.imagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AutoSizeText(
                      pet.name,
                      maxLines: 1,
                      minFontSize: 10,
                      stepGranularity: 0.5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: dragging
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1EC),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFFFD5CB),
                            width: 1,
                          ),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 16,
                            maxWidth: 190,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _petProfileTypeLabel(pet),
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7A6E69),
                              ),
                            ),
                          ),
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

  Widget _buildSnackIconArea(Pet pet) {
    final PetSnackChoice? firstFavorite =
    pet.favoriteSnacks.isNotEmpty ? pet.favoriteSnacks.first : null;

    PetSnackOption? favoriteOption;
    if (firstFavorite != null) {
      final allOptions = [
        ..._catSnackOptions,
        ..._dogSnackOptions,
      ];

      for (final option in allOptions) {
        if (option.sourceType == firstFavorite.sourceType &&
            option.itemId == firstFavorite.itemId) {
          favoriteOption = option;
          break;
        }
      }
    }

    final String favoriteLabel =
    firstFavorite == null ? '아직 없음' : _displaySnackChoiceLabel(firstFavorite);

    final bool hasFavorite = firstFavorite != null;

    if (hasFavorite) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFFDDD4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: favoriteOption != null &&
                      favoriteOption.imagePath != null &&
                      favoriteOption.imagePath!.trim().isNotEmpty
                      ? Image.asset(
                    _imageAssetPath(favoriteOption.imagePath),
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.favorite_rounded,
                      size: 22,
                      color: Color(0xFFFFB938),
                    ),
                  )
                      : const Icon(
                    Icons.favorite_rounded,
                    size: 22,
                    color: Color(0xFFFFB938),
                  ),
                ),
                const Positioned(
                  right: -1,
                  top: -1,
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 14,
                    color: Color(0xFFFF6B81),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            favoriteLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.0,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF8E7C),
              height: 1.0,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Expanded(
          child: Center(
            child: Icon(
              Icons.favorite_border_rounded,
              size: 24,
              color: Color(0xFFD0D5DD),
            ),
          ),
        ),
        SizedBox(height: 3),
        Text(
          '아직 없음',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9.0,
            fontWeight: FontWeight.w800,
            color: Color(0xFFB0B8C1),
            height: 1.0,
          ),
        ),
      ],
    );
  }

  List<String> _favoriteSnackNames(Pet pet) {
    return pet.favoriteSnacks
        .map(_displaySnackChoiceLabel)
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  List<String> _dislikedSnackNames(Pet pet) {
    return pet.dislikedSnacks
        .map(_displaySnackChoiceLabel)
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  String _snackNamesMultiline(
      List<String> names, {
        int maxLines = 3,
      }) {
    if (names.isEmpty) return '아직 없음';

    final visible = names.take(maxLines).toList();
    return visible.join('\n');
  }

  Widget _buildSnackActionButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    Color activeColor = const Color(0xFFFF8E7C),
    Color activeBgColor = const Color(0xFFFFF1EE),
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? activeBgColor : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? activeColor.withOpacity(0.28)
                  : const Color(0xFFEAECEF),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? activeColor : const Color(0xFF98A2B3),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: active ? activeColor : const Color(0xFF98A2B3),
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
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.10),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.3,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 3,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D3436),
                    height: 1.18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnackSearchBar(Pet pet, StateSetter setSheetState) {
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
        decoration: InputDecoration(
          hintText: '간식 이름 검색',
          hintStyle: const TextStyle(
            fontSize: 14,
            color: Color(0xFFB0B0B0),
            height: 1.15,
          ),
          prefixIcon: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _submitSnackSearch(pet, setSheetState),
            child: const Padding(
              padding: EdgeInsets.all(11),
              child: Icon(
                Icons.search_rounded,
                size: 20,
                color: Color(0xFFFF8E7C),
              ),
            ),
          ),
          prefixIconConstraints:
          const BoxConstraints(minWidth: 40, minHeight: 40),
          suffixIcon: _snackSearchQuery.trim().isEmpty
              ? null
              : IconButton(
            splashRadius: 18,
            onPressed: () {
              _snackSearchController.clear();
              setSheetState(() {
                _snackSearchQuery = '';
                _submittedSnackQuery = null;
                _highlightedSnackFishId = null;
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Color(0xFFB0B0B0),
            ),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
        ),
        onChanged: (value) {
          setSheetState(() {
            _snackSearchQuery = value;
            _highlightedSnackFishId = null;
          });
        },
        onSubmitted: (_) => _submitSnackSearch(pet, setSheetState),
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
                              title: '새 반려동물 추가',
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
                              onTap: () async {
                                setState(() => _isMenuOpen = false);

                                await Navigator.push(
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
                                          onEdit: (Pet pet) async {
                                            await _showPetEditSheet(pet: pet);
                                            if (!mounted) return;
                                            await _fetchPetData();
                                          },
                                        ),
                                  ),
                                );

                                if (!mounted) return;
                                await _fetchPetData();
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

  Widget _buildPetAvatar(Pet pet, {double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF4F6F8),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: _buildPetImage(
          pet.imagePath,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Future<void> _deletePetFromServer(int petId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_petApiUrl/$petId'),
      );

      if (response.statusCode == 200) {
        await _fetchPetData();
      } else {
      }
    } catch (e) {
    }
  }

  Future<void> _showDeleteConfirm(Pet pet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 아이콘
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1EE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFFF8E7C),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 제목
                  const Text(
                    "정말 삭제할까요?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 설명
                  Text(
                    "${pet.name} 정보를 삭제하면 되돌릴 수 없어요",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C8796),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 버튼
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "취소",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF636E72),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8E7C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "삭제",
                            style: TextStyle(
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
          ),
    );

    if (confirm == true) {
      await _deletePetFromServer(pet.id!);

      if (!mounted) return;

      await _fetchPetData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("삭제되었습니다 🗑️")),
      );
    }
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
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: const Color(0xFFFFFBFA),
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: Color(0xFFFFE1D9),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: Color(0xFFFFE1D9),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: Color(0xFFFF8E7C),
          width: 1.5,
        ),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFFB7AAA5),
        fontSize: 14,
        fontWeight: FontWeight.w600,
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
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery
                  .of(context)
                  .padding
                  .bottom + 18,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.98),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6E1DE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFF6F2),
                        Color(0xFFFFFCFB),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFFFE1D9),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1EC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFFFDDD4),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: _buildPetImage(
                            pet.imagePath,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AutoSizeText(
                              pet.name,
                              maxLines: 1,
                              minFontSize: 12,
                              stepGranularity: 0.5,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2D3436),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFFFE2DA),
                                ),
                              ),
                              child: AutoSizeText(
                                _petProfileTypeLabel(pet),
                                maxLines: 1,
                                minFontSize: 9,
                                stepGranularity: 0.5,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF7A6E69),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildPetMenuTile(
                  icon: Icons.edit_rounded,
                  title: '프로필 정보 변경',
                  subtitle: '이름, 외형, 설명을 수정해요',
                  onTap: () {
                    Navigator.pop(context);
                    _showPetEditSheet(pet: pet);
                  },
                ),
                const SizedBox(height: 10),
                _buildPetMenuTile(
                  icon: Icons.manage_accounts_rounded,
                  title: '통합 관리에서 보기',
                  subtitle: '순서 변경, 편집, 삭제를 한 번에',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ManagePetsScreen(
                              pets: _allPets,
                              onUpdate: (updatedList) =>
                                  setState(() => _allPets = updatedList),
                              deletePet: (id) => _deletePetFromServer(id),
                              onEdit: (pet) async {
                                await _showPetEditSheet(pet: pet);
                              },
                            ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildPetMenuTile(
                  icon: Icons.delete_rounded,
                  title: '프로필 삭제',
                  subtitle: '이 펫 프로필을 목록에서 제거해요',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirm(pet);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildPetMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: isDestructive
                ? const Color(0xFFFFF5F4)
                : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDestructive
                  ? const Color(0xFFFFD6D2)
                  : const Color(0xFFFFE5DE),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? const Color(0xFFFFEDEC)
                      : const Color(0xFFFFF1EC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDestructive
                      ? const Color(0xFFE26D63)
                      : const Color(0xFFFF8E7C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.2,
                        fontWeight: FontWeight.w900,
                        color: isDestructive
                            ? const Color(0xFFD55C52)
                            : const Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8F8A87),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDestructive
                    ? const Color(0xFFE0AAA4)
                    : const Color(0xFFC8B8B3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPetEditSheet({Pet? pet}) {
    final bool isEdit = pet != null;
    final bool isCatTab = isEdit ? pet.isCat : _tabController.index == 0;

    final nameController =
    TextEditingController(text: isEdit ? pet.name : '');
    final memoController = TextEditingController(
      text: isEdit ? (pet.memo ?? '') : '',
    );

    String selectedBreed = '';
    String selectedColor = (isEdit ? (pet.color ?? '') : '').trim();
    String? tempImagePath = isEdit ? pet.imagePath : null;
    bool isSaving = false;

    final List<PetCatalogVariant> variantPool = _currentVariantList(isCatTab);
    final List<String> breedOptions = _pickerBreedOptions(isCat: isCatTab);

    PetCatalogVariant? selectedVariant;

    if (isEdit) {
      final String savedVariantId =
      isCatTab ? (pet.catVariantId ?? '') : (pet.dogVariantId ?? '');

      if (savedVariantId.isNotEmpty) {
        try {
          selectedVariant =
              variantPool.firstWhere((v) => v.id == savedVariantId);
        } catch (_) {
          selectedVariant = null;
        }
      }
    }

    if (selectedVariant != null) {
      selectedBreed = selectedVariant!.breedName.trim();
      selectedColor = selectedVariant!.colorName.trim();
    }

    if (selectedBreed.isEmpty || !breedOptions.contains(selectedBreed)) {
      selectedBreed = breedOptions.isNotEmpty ? breedOptions.first : '';
    }

    List<String> colorOptions = _pickerColorOptions(
      isCat: isCatTab,
      breedName: selectedBreed,
    );

    Future<void> syncSelectedVariant() async {
      final forcedColor = _fixedColorForBreed(
        isCat: isCatTab,
        breedName: selectedBreed,
      );

      colorOptions = _pickerColorOptions(
        isCat: isCatTab,
        breedName: selectedBreed,
      );

      if (forcedColor != null) {
        selectedColor = forcedColor;
      } else if (!colorOptions.contains(selectedColor)) {
        selectedColor = colorOptions.isNotEmpty ? colorOptions.first : '';
      }

      try {
        selectedVariant = variantPool.firstWhere(
              (v) =>
          v.breedName.trim() == selectedBreed.trim() &&
              v.colorName.trim() == selectedColor.trim(),
        );
      } catch (_) {
        selectedVariant = null;
      }
    }

    syncSelectedVariant();

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        final double bottomPadding =
            MediaQuery
                .of(dialogContext)
                .viewInsets
                .bottom +
                MediaQuery
                    .of(dialogContext)
                    .padding
                    .bottom +
                24;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> handleSave() async {
              final String name = nameController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('이름을 입력해 주세요.')),
                );
                return;
              }

              await syncSelectedVariant();

              if (selectedVariant == null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('선택한 종과 색상에 맞는 외형 데이터를 찾을 수 없어요.'),
                  ),
                );
                return;
              }

              if (dialogContext.mounted) {
                setSheetState(() => isSaving = true);
              }

              bool shouldClose = false;

              try {
                await _savePetToServer(
                  name,
                  selectedColor,
                  memoController.text.trim(),
                  selectedVariant!,
                  tempImagePath,
                  existingId: pet?.id,
                );
                shouldClose = true;
              } finally {
                if (shouldClose) {
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                } else {
                  if (dialogContext.mounted) {
                    setSheetState(() => isSaving = false);
                  }
                }
              }
            }

            final bool isSingleColorBreed = _isSingleColorBreed(
              isCat: isCatTab,
              breedName: selectedBreed,
            );

            colorOptions = _pickerColorOptions(
              isCat: isCatTab,
              breedName: selectedBreed,
            );

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: bottomPadding,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.98),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6E1DE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
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
                            Icons.pets_rounded,
                            size: 19,
                            color: Color(0xFFFF8E7C),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isEdit ? '프로필 정보 변경' : '새 펫 등록',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFF7F3),
                            Color(0xFFFFFCFB),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFFFE1D9),
                        ),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final XFile? image = await _picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 2048,
                              );
                              if (image == null) return;

                              final ImageAdjustResult? adjusted =
                              await Navigator.push<ImageAdjustResult>(
                                dialogContext,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ImageAdjustScreen(
                                        imagePath: image.path,
                                        title: isCatTab
                                            ? '고양이 사진 조정'
                                            : '강아지 사진 조정',
                                        shape: ImageAdjustShape.circle,
                                        viewportAspectRatio: 1.0,
                                      ),
                                ),
                              );

                              if (adjusted == null) return;

                              final tempDir = await getTemporaryDirectory();
                              final filePath =
                                  '${tempDir.path}/pet_${DateTime
                                  .now()
                                  .millisecondsSinceEpoch}.${adjusted
                                  .extension}';
                              final file = File(filePath);
                              await file.writeAsBytes(adjusted.bytes);

                              if (dialogContext.mounted) {
                                setSheetState(() {
                                  tempImagePath = file.path;
                                });
                              }
                            },
                            child: Stack(
                              children: [
                                Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1EC),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF8E7C)
                                            .withOpacity(0.10),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                    image: DecorationImage(
                                      image: tempImagePath != null &&
                                          tempImagePath!.isNotEmpty &&
                                          File(tempImagePath!).existsSync()
                                          ? FileImage(File(tempImagePath!))
                                          : (tempImagePath != null &&
                                          tempImagePath!.isNotEmpty &&
                                          _isRemotePetImage(tempImagePath)
                                          ? NetworkImage(
                                          _resolvePetImageUrl(tempImagePath))
                                          : const AssetImage(
                                          'assets/images/pets.webp'))
                                      as ImageProvider,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF8E7C),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '프로필 사진',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF645A57),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  '반려동물의 프로필 사진을 등록해 보세요.',
                                  style: TextStyle(
                                    fontSize: 12.2,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF9A8F8A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFFFE4DD),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: _dialogInputDecoration(
                              hintText: '이름 입력',
                              prefixIcon: const Icon(
                                Icons.badge_rounded,
                                color: Color(0xFFFF8E7C),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 🔥 종 왼쪽 / 색상 오른쪽
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniWheelPicker(
                                  title: '종',
                                  items: breedOptions,
                                  selectedValue: selectedBreed,
                                  onChanged: (value) async {
                                    setSheetState(() {
                                      selectedBreed = value;
                                    });
                                    await syncSelectedVariant();
                                    if (dialogContext.mounted) {
                                      setSheetState(() {});
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Opacity(
                                  opacity: isSingleColorBreed ? 0.55 : 1.0,
                                  child: IgnorePointer(
                                    ignoring: isSingleColorBreed,
                                    child: _buildMiniWheelPicker(
                                      title: isSingleColorBreed
                                          ? '색상 고정'
                                          : '색상',
                                      items: colorOptions,
                                      selectedValue: selectedColor,
                                      onChanged: (value) async {
                                        setSheetState(() {
                                          selectedColor = value;
                                        });
                                        await syncSelectedVariant();
                                        if (dialogContext.mounted) {
                                          setSheetState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 🔥 캡슐도 종 -> 색상 순서
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFF3EE),
                                    Color(0xFFFFFBFA),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFFFDED4),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF8E7C)
                                        .withOpacity(0.07),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEAE4),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 11,
                                      color: Color(0xFFFF8E7C),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    isSingleColorBreed
                                        ? selectedBreed
                                        : '$selectedColor $selectedBreed',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFF8E7C),
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (isSingleColorBreed) ...[
                            const SizedBox(height: 8),
                            const Text(
                              '이 종은 단색 외형이라 색상이 자동으로 고정돼요.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFAA8E86),
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          TextField(
                            controller: memoController,
                            maxLines: 4,
                            decoration: _dialogInputDecoration(
                              hintText: '설명 / 메모',
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(bottom: 54),
                                child: Icon(
                                  Icons.edit_note_rounded,
                                  color: Color(0xFFFF8E7C),
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 🔥 너무 평면적이지 않게 살짝 떠 있는 버튼
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF8E7C).withOpacity(0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isSaving ? null : handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8E7C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size(0, 0),
                          ),
                          child: Text(
                            isSaving ? '저장 중...' : (isEdit
                                ? '변경 저장하기'
                                : '등록하기'),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
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

  bool _isSingleColorBreed({
    required bool isCat,
    required String breedName,
  }) {
    final variants = _currentVariantList(isCat)
        .where((v) => v.breedName.trim() == breedName.trim())
        .toList();

    final colors = variants
        .map((v) => v.colorName.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    return colors.length <= 1;
  }

  String? _fixedColorForBreed({
    required bool isCat,
    required String breedName,
  }) {
    final variants = _currentVariantList(isCat)
        .where((v) => v.breedName.trim() == breedName.trim())
        .toList();

    final colors = variants
        .map((v) => v.colorName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (colors.length == 1) {
      return colors.first;
    }
    return null;
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
          final totalSnackCount = _snackOptionsForPet(pet).length;

          final favoriteLabel = _snackNamesMultiline(_favoriteSnackNames(pet));
          final dislikedLabel = _snackNamesMultiline(_dislikedSnackNames(pet));

          final visibleOptions = _buildVisibleSnackOptions(pet);

          Future<void> applyUpdatedPet(Pet updatedPet) async {
            final idx = _allPets.indexWhere((p) => p.id == updatedPet.id);
            if (idx != -1) {
              _allPets[idx] = updatedPet;
            }
            pet = updatedPet;

            if ((context as Element).mounted) {
              setSheetState(() {});
            }
            if (mounted) {
              setState(() {});
            }

            await _updatePetSnacks(updatedPet);
          }

          Future<void> toggleTried(PetSnackOption option) async {
            final target = PetSnackChoice(
              sourceType: option.sourceType,
              itemId: option.itemId,
            );

            final nextTried = Set<PetSnackChoice>.from(pet.triedSnacks);
            if (nextTried.contains(target)) {
              nextTried.remove(target);
            } else {
              nextTried.add(target);
            }

            final updatedPet = pet.copyWith(triedSnacks: nextTried);
            await applyUpdatedPet(updatedPet);
          }

          Future<void> toggleFavorite(PetSnackOption option) async {
            final target = PetSnackChoice(
              sourceType: option.sourceType,
              itemId: option.itemId,
            );

            final nextFavorites = Set<PetSnackChoice>.from(pet.favoriteSnacks);
            if (nextFavorites.contains(target)) {
              nextFavorites.remove(target);
            } else {
              nextFavorites.add(target);
            }

            final updatedPet = pet.copyWith(favoriteSnacks: nextFavorites);
            await applyUpdatedPet(updatedPet);
          }

          Future<void> toggleDisliked(PetSnackOption option) async {
            final target = PetSnackChoice(
              sourceType: option.sourceType,
              itemId: option.itemId,
            );

            final nextDisliked = Set<PetSnackChoice>.from(pet.dislikedSnacks);
            if (nextDisliked.contains(target)) {
              nextDisliked.remove(target);
            } else {
              nextDisliked.add(target);
            }

            final updatedPet = pet.copyWith(dislikedSnacks: nextDisliked);
            await applyUpdatedPet(updatedPet);
          }

          Widget buildIconActionButton({
            required VoidCallback onTap,
            required IconData icon,
            required bool selected,
            required Color activeColor,
            required Color activeBg,
            required Color activeBorder,
            required Color inactiveColor,
            double size = 34,
          }) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: selected ? activeBg : Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selected ? activeBorder : const Color(0xFFE7E7E7),
                      width: 1,
                    ),
                    boxShadow: selected
                        ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: selected ? activeColor : inactiveColor,
                  ),
                ),
              ),
            );
          }

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
                          color: const Color(0xFFFFF4F1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          color: Color(0xFFFF8E7C),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pet.name}의 간식 실험실',
                              style: const TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2D3436),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '먹어본 간식 $triedCount개 / 전체 $totalSnackCount개',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF8A8A8A),
                                fontWeight: FontWeight.w600,
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
                        icon: Icons.favorite_rounded,
                        label: '좋아해요',
                        value: favoriteLabel.isEmpty ? '아직 없음' : favoriteLabel,
                        color: const Color(0xFFFFB545),
                        bgColor: const Color(0xFFFFF7E8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSnackInfoChip(
                        icon: Icons.heart_broken_rounded,
                        label: '싫어해요',
                        value: dislikedLabel.isEmpty ? '아직 없음' : dislikedLabel,
                        color: const Color(0xFFFF8A8A),
                        bgColor: const Color(0xFFFFF1F1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: Color(0xFFFF8E7C),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _snackSearchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _submitSnackSearch(pet, setSheetState),
                          decoration: const InputDecoration(
                            hintText: '간식 이름 검색',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if ((_submittedSnackQuery ?? '').isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _snackSearchController.clear();
                            setSheetState(() {
                              _snackSearchQuery = '';
                              _submittedSnackQuery = null;
                              _highlightedSnackFishId = null;
                            });
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFB0B0B0),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: visibleOptions.isEmpty
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
                    itemCount: visibleOptions.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final option = visibleOptions[index];
                      final displayName = _snackOptionDisplayName(option);

                      final target = PetSnackChoice(
                        sourceType: option.sourceType,
                        itemId: option.itemId,
                      );

                      final isTried =
                      _containsSnackChoice(pet.triedSnacks, option);
                      final isFav =
                      _containsSnackChoice(pet.favoriteSnacks, option);
                      final isDisliked =
                      _containsSnackChoice(pet.dislikedSnacks, option);
                      final isHighlighted =
                          _highlightedSnackFishId == option.key;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? const Color(0xFFFFF4E8)
                              : isFav
                              ? const Color(0xFFFFFBF2)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isHighlighted
                                ? const Color(0xFFFFC8A2)
                                : isFav
                                ? const Color(0xFFFFD67A)
                                : isTried
                                ? const Color(0xFFFFD8D1)
                                : const Color(0xFFF0F0F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
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
                                color: const Color(0xFFFFF4F1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: option.imagePath != null && option.imagePath!.trim().isNotEmpty
                                  ? Image.asset(
                                _imageAssetPath(option.imagePath),
                                width: 28,
                                height: 28,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.phishing,
                                  color: Color(0xFFFF8E7C),
                                ),
                              )
                                  : const Icon(
                                Icons.phishing,
                                color: Color(0xFFFF8E7C),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: AutoSizeText(
                                            displayName,
                                            maxLines: 1,
                                            minFontSize: 10,
                                            maxFontSize: 14,
                                            stepGranularity: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF2D3436),
                                            ),
                                          ),
                                        ),
                                        if (isFav)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF1D6),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              '선호',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFE0A100),
                                              ),
                                            ),
                                          ),
                                        if (isDisliked) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFE7E7),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              '비선호',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFFF6B6B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      buildIconActionButton(
                                        onTap: () => toggleTried(option),
                                        icon: isTried
                                            ? Icons.check_rounded
                                            : Icons.check_outlined,
                                        selected: isTried,
                                        activeColor: const Color(0xFFFF8E7C),
                                        activeBg: const Color(0xFFFFF1EC),
                                        activeBorder: const Color(0xFFFFD8CF),
                                        inactiveColor: const Color(0xFFB5B5B5),
                                        size: 34,
                                      ),
                                      const SizedBox(width: 6),
                                      buildIconActionButton(
                                        onTap: () => toggleFavorite(option),
                                        icon: isFav
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        selected: isFav,
                                        activeColor: const Color(0xFFFFB545),
                                        activeBg: const Color(0xFFFFF7E8),
                                        activeBorder: const Color(0xFFFFD67A),
                                        inactiveColor: const Color(0xFFB5B5B5),
                                        size: 34,
                                      ),
                                      const SizedBox(width: 6),
                                      buildIconActionButton(
                                        onTap: () => toggleDisliked(option),
                                        icon: isDisliked
                                            ? Icons.heart_broken_rounded
                                            : Icons.heart_broken_outlined,
                                        selected: isDisliked,
                                        activeColor: const Color(0xFFFF6B6B),
                                        activeBg: const Color(0xFFFFF1F1),
                                        activeBorder: const Color(0xFFFFD6D6),
                                        inactiveColor: const Color(0xFFB5B5B5),
                                        size: 34,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

  Widget _buildMiniWheelPicker({
    required String title,
    required List<String> items,
    required String selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    final int initialIndex = (() {
      final index = items.indexOf(selectedValue);
      return index >= 0 ? index : 0;
    })();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFFE0D7),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8E7C).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1EC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    title == '색상'
                        ? Icons.palette_rounded
                        : Icons.auto_awesome_rounded,
                    size: 11,
                    color: const Color(0xFFFF8E7C),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7A6E69),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFFDDD4),
                      width: 1,
                    ),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: FixedExtentScrollController(
                    initialItem: initialIndex,
                  ),
                  itemExtent: 30,
                  diameterRatio: 1.5,
                  perspective: 0.0028,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) => onChanged(items[index]),
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: items.length,
                    builder: (context, index) {
                      final isSelected = items[index] == selectedValue;
                      return Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 140),
                          style: TextStyle(
                            fontSize: isSelected ? 14.2 : 11.8,
                            fontWeight:
                            isSelected ? FontWeight.w900 : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFFFF8E7C)
                                : const Color(0xFFA39A96),
                          ),
                          child: Text(
                            items[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

class PetBreedDetailScreen extends StatefulWidget {
  final String breed;
  final List<PetCatalogVariant> items;
  final Set<String> likedIds;
  final void Function(PetCatalogVariant item) onPreview;
  final Future<void> Function(String id) onToggleLike;
  final String catalogLabel;
  final Widget Function(
      String? imagePath, {
      BoxFit fit,
      }) imageBuilder;

  const PetBreedDetailScreen({
    super.key,
    required this.breed,
    required this.items,
    required this.likedIds,
    required this.onPreview,
    required this.onToggleLike,
    required this.catalogLabel,
    required this.imageBuilder,
  });

  @override
  State<PetBreedDetailScreen> createState() => _PetBreedDetailScreenState();
}

class _PetBreedDetailScreenState extends State<PetBreedDetailScreen> {
  static const List<String> _eyeOrder = ['콩눈', '땡눈', '고양이눈', '졸린눈'];

  late Set<String> _localLikedIds;
  bool _likeSubmitting = false;

  @override
  void initState() {
    super.initState();
    _localLikedIds = Set<String>.from(widget.likedIds);
  }

  int _eyeRank(String value) {
    final index = _eyeOrder.indexOf(value.trim());
    return index == -1 ? 999 : index;
  }

  Future<void> _handleToggleLike(String id) async {
    if (_likeSubmitting) return;

    final wasLiked = _localLikedIds.contains(id);

    setState(() {
      if (wasLiked) {
        _localLikedIds.remove(id);
      } else {
        _localLikedIds.add(id);
      }
      _likeSubmitting = true;
    });

    try {
      await widget.onToggleLike(id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          _localLikedIds.add(id);
        } else {
          _localLikedIds.remove(id);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _likeSubmitting = false;
        });
      }
    }
  }

  Map<String, Map<String, List<PetCatalogVariant>>> _groupByColorAndEye() {
    final List<PetCatalogVariant> sorted = List.of(widget.items)
      ..sort((a, b) {
        final colorCompare = a.colorName.compareTo(b.colorName);
        if (colorCompare != 0) return colorCompare;

        final eyeCompare =
        _eyeRank(a.eyeStyleKo).compareTo(_eyeRank(b.eyeStyleKo));
        if (eyeCompare != 0) return eyeCompare;

        final eyeColorCompare =
        (a.eyeColorNameKo ?? '').compareTo(b.eyeColorNameKo ?? '');
        if (eyeColorCompare != 0) return eyeColorCompare;

        final noCompare = a.variantNo.compareTo(b.variantNo);
        if (noCompare != 0) return noCompare;

        return a.id.compareTo(b.id);
      });

    final Map<String, Map<String, List<PetCatalogVariant>>> grouped = {};

    for (final item in sorted) {
      final colorKey = item.colorName.trim().isEmpty ? '기본' : item.colorName;
      final eyeKey = item.eyeStyleKo.trim().isEmpty ? '기본' : item.eyeStyleKo;

      grouped.putIfAbsent(colorKey, () => {});
      grouped[colorKey]!.putIfAbsent(eyeKey, () => []);
      grouped[colorKey]![eyeKey]!.add(item);
    }

    final colorEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return {
      for (final colorEntry in colorEntries)
        colorEntry.key: {
          for (final eyeEntry in colorEntry.value.entries.toList()
            ..sort((a, b) => _eyeRank(a.key).compareTo(_eyeRank(b.key))))
            eyeEntry.key: eyeEntry.value,
        },
    };
  }

  Widget _buildHeartButton({
    required bool isLiked,
    required VoidCallback onTap,
  }) {
    return _buildFloatingHeartButton(
      isLiked: isLiked,
      onTap: onTap,
      size: 28,
      iconSize: 15,
    );
  }

  Widget _buildHeaderCard() {
    final PetCatalogVariant hero = widget.items.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFFFE5DE),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 158,
              height: 158,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F4),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.all(12),
              child: widget.imageBuilder(
                hero.imagePath,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.breed,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2D3436),
                height: 1.08,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.catalogLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7C8796).withOpacity(0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String color,
    required String eye,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Flexible(
            child: Text(
              color,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15.2,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2D3436),
                letterSpacing: -0.1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '·',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFB6BDC9).withOpacity(0.95),
              ),
            ),
          ),
          Flexible(
            child: Text(
              eye,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7C8796),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantCard(PetCatalogVariant item) {
    final bool isLiked = _localLikedIds.contains(item.id);

    final String eyeColorLabel =
    (item.eyeColorNameKo ?? '').trim().isEmpty
        ? '기본 눈색'
        : item.eyeColorNameKo!.trim();

    return GestureDetector(
      onTap: () => widget.onPreview(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFE5DE),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 11),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFFFFBF9),
                              Color(0xFFFFF5F1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(9),
                        child: widget.imageBuilder(
                          item.imagePath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildHeartButton(
                      isLiked: isLiked,
                      onTap: () => _handleToggleLike(item.id),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 5, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.eyeStyleKo.trim().isEmpty ? '기본 눈' : item.eyeStyleKo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.6,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D3436),
                      letterSpacing: -0.05,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    eyeColorLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.4,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A94A6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _groupByColorAndEye();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFE2DA),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.breed,
                      style: const TextStyle(
                        fontSize: 16.8,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2D3436),
                        letterSpacing: -0.1,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _buildHeaderCard(),
              ),
            ),
            ...sections.entries.expand((colorEntry) {
              return colorEntry.value.entries.map((eyeEntry) {
                final items = eyeEntry.value;

                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          color: colorEntry.key,
                          eye: eyeEntry.key,
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double cardWidth = constraints.maxWidth * 0.42;

                            return SizedBox(
                              height: 228,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(right: 18),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  return SizedBox(
                                    width: cardWidth,
                                    child: _buildVariantCard(items[index]),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              });
            }),
            const SliverToBoxAdapter(
              child: SizedBox(height: 28),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetHandleDot extends StatelessWidget {
  const _PetHandleDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3.5,
      height: 3.5,
      decoration: const BoxDecoration(
        color: Color(0xFFC6A59D),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _InstagramLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _InstagramLikeButton({
    required this.isLiked,
    required this.onTap,
    required this.size,
    required this.iconSize,
  });

  @override
  State<_InstagramLikeButton> createState() => _InstagramLikeButtonState();
}

class _InstagramLikeButtonState extends State<_InstagramLikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.9)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.9, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);

    _fillAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant _InstagramLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isLiked && widget.isLiked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLiked = widget.isLiked;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: isLiked ? _scaleAnimation.value : 1.0,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.6),
                border: Border.all(
                  color: Colors.white.withOpacity(0.7),
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

              // ✅ 핵심: 완전 중앙 정렬
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: widget.iconSize,
                      color: const Color(0xFFFF8E7C).withOpacity(0.18),
                    ),

                    if (isLiked)
                      ShaderMask(
                        shaderCallback: (rect) {
                          final fill =
                          _fillAnimation.value.clamp(0.0, 1.0);
                          final stop = 1 - fill;

                          return LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            stops: [0, stop, stop, 1],
                            colors: const [
                              Color(0xFFFF7F73),
                              Color(0xFFFF7F73),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.srcATop,
                        child: Icon(
                          Icons.favorite_rounded,
                          size: widget.iconSize,
                          color: const Color(0xFFFF7F73),
                        ),
                      ),

                    Icon(
                      isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: widget.iconSize,
                      color: isLiked
                          ? const Color(0xFFFF7F73)
                          : const Color(0xFFD89A8D),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _buildFloatingHeartButton({
  required bool isLiked,
  required VoidCallback onTap,
  double size = 28,
  double iconSize = 15,
}) {
  return _InstagramLikeButton(
    isLiked: isLiked,
    onTap: onTap,
    size: size,
    iconSize: iconSize,
  );
}

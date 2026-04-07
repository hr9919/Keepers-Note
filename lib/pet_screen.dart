import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:image_picker/image_picker.dart';
import 'setting_screen.dart';
import 'models/global_search_item.dart';

// --- 데이터 모델 ---
class Pet {
  final int? id;
  String name;
  String breed;
  String? imagePath;
  Set<String> triedSnacks;
  String favoriteSnack;
  bool isCat;

  Pet({
    this.id,
    required this.name,
    required this.breed,
    required this.isCat,
    this.imagePath,
    Set<String>? triedSnacks,
    this.favoriteSnack = "",
  }) : triedSnacks = triedSnacks ?? {};
}

class FishItem {
  final String id;
  final String name;
  final String? nameKo;
  final String image;
  FishItem({required this.id, required this.name, this.nameKo, required this.image});
  factory FishItem.fromJson(Map<String, dynamic> json) {
    return FishItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameKo: (json['name_ko'] ?? json['nameKo'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
    );
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

class _PetScreenState extends State<PetScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  String _selectedType = '단색 고양이';
  String _selectedColor = '흰색';
  bool _isMenuOpen = false;
  bool _isSubmitting = false;

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
    _tabController.addListener(() { if (!_tabController.indexIsChanging) setState(() {}); });
    _initData();
  }

  Future<void> _initData() async {
    await _loadUserInfo();
    await _fetchFishData();
    if (_kakaoId != null) {
      await _fetchPetData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      User user = await UserApi.instance.me();
      if (mounted) setState(() => _kakaoId = user.id.toString());
    } catch (e) {
      debugPrint("사용자 정보 로드 실패: $e");
    }
  }

  Future<void> _fetchPetData() async {
    if (_kakaoId == null) return;
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      final response = await http.get(Uri.parse('$_petApiUrl/user/$_kakaoId'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _allPets = data.map((json) => Pet(
              id: json['id'],
              name: json['name'],
              breed: json['breed'],
              isCat: json['isCat'] ?? true,
              imagePath: json['imagePath'],
              favoriteSnack: json['favoriteSnack'] ?? "",
              triedSnacks: Set<String>.from(json['triedSnacks'] ?? []),
            )).toList();
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFishData() async {
    try {
      final response = await http.get(Uri.parse(_fishApiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) setState(() => _fishList = data.map((e) => FishItem.fromJson(e)).toList());
      }
    } catch (e) {
      debugPrint("물고기 데이터 로드 에러: $e");
    }
  }

  Future<void> _savePetToServer(String name, String breed, String? imagePath, {int? existingId}) async {
    if (_kakaoId == null) return;

    try {
      final Map<String, dynamic> petData = {
        "kakaoId": int.parse(_kakaoId!),
        "name": name,
        "breed": breed,
        "isCat": _tabController.index == 0,
        "imagePath": imagePath,
      };

      http.Response response;
      if (existingId == null) {
        // 신규 등록 (POST)
        response = await http.post(
          Uri.parse(_petApiUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({...petData, "favoriteSnack": "", "triedSnacks": []}),
        );
      } else {
        // 정보 수정 (PUT) - 서버에 /api/pets/{id} 엔드포인트가 있다고 가정
        response = await http.put(
          Uri.parse('$_petApiUrl/$existingId'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(petData),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchPetData();
      }
    } catch (e) {
      debugPrint("저장/수정 실패: $e");
    }
  }

  Future<void> _updatePetSnacks(Pet pet) async {
    try {
      await http.put(
        Uri.parse('$_petApiUrl/${pet.id}'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "kakaoId": int.parse(_kakaoId!),
          "name": pet.name,
          "breed": pet.breed,
          "isCat": pet.isCat,
          "imagePath": pet.imagePath,
          "favoriteSnack": pet.favoriteSnack,
          "triedSnacks": pet.triedSnacks.toList(), // Set을 List로 변환
        }),
      );
    } catch (e) {
      debugPrint("간식 업데이트 실패: $e");
    }
  }

  Future<void> _deletePetFromServer(int petId) async {
    try {
      final response = await http.delete(Uri.parse('$_petApiUrl/$petId'));
      if (response.statusCode == 200) await _fetchPetData();
    } catch (e) {
      debugPrint("삭제 실패: $e");
    }
  }

  String _imageAssetPath(String? image) {
    if (image == null || image.isEmpty) return 'assets/images/default.png';
    String fullPath = image.startsWith('assets/') ? image : 'assets/$image';
    if (!fullPath.toLowerCase().endsWith('.webp') && !fullPath.toLowerCase().endsWith('.png') && !fullPath.toLowerCase().endsWith('.jpg')) {
      fullPath = '$fullPath.webp';
    }
    return fullPath;
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _buildFabWithMenu(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_gradient.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildCustomAppBar(context),
              _buildTabBar(),
              // TabBarView 영역 (이 안에서 각각 새로고침이 일어납니다)
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const PageScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    _buildTabContent(isCat: true),
                    _buildTabContent(isCat: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent({required bool isCat}) {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchFishData();
        await _fetchPetData();
      },
      color: const Color(0xFFFF8E7C),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPetSummaryList(),
            const SizedBox(height: 10),

            if (isCat)
              _buildPetGridContent()
            else
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: Text(
                    "강아지 리스트 준비 중",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // --- 기존 UI 빌더 함수들 ---
  Widget _buildFabWithMenu() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 120, right: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isMenuOpen)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 160,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMenuItem('새 애완동물 추가', () {
                    setState(() => _isMenuOpen = false);
                    _showPetEditSheet();
                  }),
                ],
              ),
            ),
          FloatingActionButton(
            onPressed: () => setState(() => _isMenuOpen = !_isMenuOpen),
            backgroundColor: const Color(0xFFFF8E7C),
            shape: const CircleBorder(),
            elevation: 4,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _isMenuOpen ? 0.125 : 0,
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), alignment: Alignment.center, child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF636363)))));
  }

  Widget _buildPetSummaryList() {
    final bool isCatTab = _tabController.index == 0;
    final filteredPets = _allPets.where((p) => p.isCat == isCatTab).toList();
    if (filteredPets.isEmpty) {
      return Container(
        height: 110, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: GestureDetector(
          onTap: () => _showPetEditSheet(),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF8E7C).withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pets, color: const Color(0xFFFF8E7C).withOpacity(0.5)),
                const SizedBox(width: 10),
                Text(isCatTab ? "등록된 고양이가 없어요. 추가해볼까요?" : "등록된 강아지가 없어요. 추가해볼까요?", style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 110,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        scrollDirection: Axis.horizontal,
        itemCount: filteredPets.length,
        itemBuilder: (context, index) {
          final pet = filteredPets[index];
          return Container( // GestureDetector를 내부 영역별로 나누기 위해 Container로 변경
            width: 240,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Row(
              children: [
                // 1. 왼쪽 영역 (사진 + 이름 + 종): 누르면 기존처럼 통합 관리 메뉴 오픈
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showPetControlSheet(pet),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                              radius: 25,
                              backgroundImage: (pet.imagePath != null && File(pet.imagePath!).existsSync())
                                  ? FileImage(File(pet.imagePath!))
                                  : const AssetImage('assets/images/pets.webp') as ImageProvider
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pet.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(pet.breed, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. 오른쪽 영역 (간식 아이콘): 누르면 즉시 간식 실험실 오픈
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showSnackLabSheet(pet), // 즉시 간식 실험실 호출
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (pet.favoriteSnack.isNotEmpty) ...[
                          Builder(builder: (context) {
                            final favFish = _fishList.firstWhere(
                                    (f) => (f.nameKo ?? f.name) == pet.favoriteSnack,
                                orElse: () => FishItem(id: '', name: '', image: '')
                            );
                            return favFish.image.isNotEmpty
                                ? Image.asset(_imageAssetPath(favFish.image), width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.phishing, size: 18, color: Color(0xFFFF8E7C)))
                                : const Icon(Icons.phishing, size: 18, color: Color(0xFFFF8E7C));
                          }),
                          const SizedBox(height: 2),
                          Text(pet.favoriteSnack, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFF8E7C))),
                        ] else ...[
                          const Icon(Icons.phishing, size: 18, color: Color(0xFFD9D9D9)),
                          const SizedBox(height: 2),
                          const Text('간식 실험실', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFFA4A4A4))),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPetControlSheet(Pet pet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('${pet.name} 관리', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildMenuTile(Icons.edit_rounded, '프로필 정보 변경', () { Navigator.pop(context); _showPetEditSheet(pet: pet); }),
            _buildMenuTile(Icons.science_rounded, '최애 간식 실험실', () { Navigator.pop(context); _showSnackLabSheet(pet); }),
            _buildMenuTile(Icons.delete_outline_rounded, '반려동물 삭제', () {
              Navigator.pop(context);
              if (pet.id != null) _showDeleteConfirm(pet);
            }, isDestructive: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(Pet pet) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text("삭제"),
            content: Text("${pet.name}을(를) 삭제하시겠습니까?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
              TextButton(
                  onPressed: () async {
                    await _deletePetFromServer(pet.id!); // 서버에 삭제 요청
                    Navigator.pop(context); // 다이얼로그 닫기
                  },
                  child: const Text("삭제", style: TextStyle(color: Colors.red))
              )
            ]
        )
    );
  }

  void _showPetEditSheet({Pet? pet}) {
    bool isEdit = pet != null;
    final nameController = TextEditingController(text: isEdit ? pet.name : "");
    final breedController = TextEditingController(text: isEdit ? pet.breed : "");
    String? tempImagePath = isEdit ? pet.imagePath : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? '정보 수정' : '새 친구 등록', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) setSheetState(() => tempImagePath = image.path);
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                          image: DecorationImage(
                              image: tempImagePath != null && File(tempImagePath!).existsSync()
                                  ? FileImage(File(tempImagePath!))
                                  : const AssetImage('assets/images/pets.webp') as ImageProvider,
                              fit: BoxFit.cover
                          ),
                        ),
                      ),
                      Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFFFF8E7C), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 16))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(controller: nameController, decoration: _dialogInputDecoration(hintText: '이름')),
              const SizedBox(height: 12),
              TextField(controller: breedController, decoration: _dialogInputDecoration(hintText: '종류')),
              const SizedBox(height: 24),
              ElevatedButton(
                // 1. 중복 클릭 방지: _isSubmitting이 true면 버튼 비활성화(null)
                onPressed: _isSubmitting
                    ? null
                    : () async {
                  setState(() => _isSubmitting = true); // 로딩 시작
                  try {
                    // 2. 기존 로직 그대로 수행 (수정 모드 대응 포함)
                    await _savePetToServer(
                      nameController.text,
                      breedController.text,
                      tempImagePath,
                      existingId: pet?.id, // pet이 있으면 ID 전달
                    );
                    if (mounted) Navigator.pop(context);
                  } finally {
                    // 3. 성공/실패 여부와 상관없이 상태 복구
                    if (mounted) setState(() => _isSubmitting = false);
                  }
                },
                // 4. 예쁜 주황색 버튼 스타일 복구
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8E7C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                // 5. 로딩 중일 때는 뱅글뱅글(Indicator), 평소에는 텍스트 표시
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackLabSheet(Pet pet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final triedCount = pet.triedSnacks.length;
          final favoriteSnack = pet.favoriteSnack;

          return Container(
            height: MediaQuery.of(context).size.height * 0.82,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFFFDFDFD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E2E2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                        value: favoriteSnack.isEmpty ? '아직 없음' : favoriteSnack,
                        color: const Color(0xFFFFC24B),
                        bgColor: const Color(0xFFFFF8E8),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: _fishList.isEmpty
                      ? const Center(
                    child: Text(
                      '간식 데이터를 불러오는 중이거나 비어 있어요',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  )
                      : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _fishList.length,
                    separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final fish = _fishList[index];
                      final displayName = (fish.nameKo != null &&
                          fish.nameKo!.trim().isNotEmpty)
                          ? fish.nameKo!
                          : fish.name;

                      final isTried = pet.triedSnacks.contains(displayName);
                      final isFav = pet.favoriteSnack == displayName;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isFav
                              ? const Color(0xFFFFFBF2)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isFav
                                ? const Color(0xFFFFD67A)
                                : isTried
                                ? const Color(0xFFFFD8D1)
                                : const Color(0xFFF0F0F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.035),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F8F8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: Image.asset(
                                _imageAssetPath(fish.image),
                                width: 34,
                                height: 34,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.phishing_rounded,
                                  color: Color(0xFFFF8E7C),
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2C2C2E),
                                          ),
                                        ),
                                      ),
                                      if (isFav) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF1C9),
                                            borderRadius:
                                            BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            '최애',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF9C6A00),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    isTried
                                        ? '먹어본 간식이에요'
                                        : '아직 먹여보지 않았어요',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isTried
                                          ? const Color(0xFFFF8E7C)
                                          : const Color(0xFF9A9AA1),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 10),

                            Column(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    setSheetState(() {
                                      if (isTried) {
                                        pet.triedSnacks.remove(displayName);
                                        if (isFav) {
                                          pet.favoriteSnack = "";
                                        }
                                      } else {
                                        pet.triedSnacks.add(displayName);
                                      }
                                    });
                                    setState(() {});
                                    await _updatePetSnacks(pet);
                                  },
                                  child: AnimatedContainer(
                                    duration:
                                    const Duration(milliseconds: 160),
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isTried
                                          ? const Color(0xFFFF8E7C)
                                          : const Color(0xFFF6F7F9),
                                      borderRadius:
                                      BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.check_rounded, // 👉 항상 동일
                                      color: isTried
                                          ? Colors.white
                                          : const Color(0xFFB0B0B0), // 회색 체크
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () async {
                                    setSheetState(() {
                                      // 최애 누르면 자동으로 먹어본 간식에도 추가
                                      pet.triedSnacks.add(displayName);

                                      pet.favoriteSnack = isFav ? "" : displayName;
                                    });
                                    setState(() {});
                                    await _updatePetSnacks(pet);
                                  },
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 150),
                                    opacity: 1.0,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isFav
                                            ? const Color(0xFFFFF3CD)
                                            : const Color(0xFFF6F7F9),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        isFav
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        color: isFav
                                            ? const Color(0xFFFFB800)
                                            : const Color(0xFF8E8E93),
                                        size: 21,
                                      ),
                                    ),
                                  ),
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

  Widget _buildSnackInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2C2C2E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(leading: Icon(icon, color: isDestructive ? Colors.red[300] : const Color(0xFFFF8E7C)), title: Text(title, style: TextStyle(fontSize: 15, color: isDestructive ? Colors.red[300] : Colors.black87)), onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 8));
  }

  InputDecoration _dialogInputDecoration({required String hintText}) {
    return InputDecoration(hintText: hintText, filled: true, fillColor: const Color(0xFFF6F7F9), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF8E7C), width: 1.4)), hintStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 14));
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16), height: 60, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: widget.openDrawer, icon: SvgPicture.asset('assets/icons/ic_menu.svg', width: 24, height: 24)), const Text('동물', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'SF Pro')), IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())), icon: SvgPicture.asset('assets/icons/ic_settings.svg', width: 24, height: 24))]));
  }

  Widget _buildTabBar() {
    return Stack(alignment: Alignment.bottomCenter, children: [Container(width: double.infinity, height: 0.7, color: const Color(0xFFC4C4C4)), TabBar(controller: _tabController, labelColor: Colors.black, unselectedLabelColor: const Color(0xFF898989), labelStyle: const TextStyle(fontSize: 16, fontFamily: 'SF Pro', fontWeight: FontWeight.w500), indicatorColor: Colors.black, indicatorWeight: 1.5, indicatorSize: TabBarIndicatorSize.label, indicatorPadding: const EdgeInsets.symmetric(horizontal: -20), tabs: const [Tab(text: '고양이'), Tab(text: '강아지')])]);
  }

  Widget _buildPetGridContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFilterRow('종류', ['단색 고양이', '얼룩 고양이', '샴 고양이'], true), _buildFilterRow('색', ['흰색', '검정색'], false), const SizedBox(height: 16), _buildPetSectionTitle('올화이트'), _buildPetGrid(['assets/images/cat_white.png'], favoriteIndex: 0), const SizedBox(height: 24), _buildPetSectionTitle('올블랙'), _buildPetGrid(['assets/images/cat_black_1.png', 'assets/images/cat_black_2.png'], favoriteIndex: -1), const SizedBox(height: 120)]);
  }

  Widget _buildFilterRow(String label, List<String> items, bool isTypeFilter) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [SizedBox(width: 40, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF555555), fontFamily: 'SF Pro'))), Expanded(child: SizedBox(height: 40, child: ListView.builder(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: items.length, itemBuilder: (context, index) => _buildFilterChip(items[index], isTypeFilter: isTypeFilter))))]));
  }

  Widget _buildFilterChip(String label, {required bool isTypeFilter}) {
    bool isSelected = isTypeFilter ? (_selectedType == label) : (_selectedColor == label);
    return Theme(data: Theme.of(context).copyWith(splashColor: Colors.transparent, highlightColor: Colors.transparent), child: Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Padding(padding: EdgeInsets.only(bottom: isTypeFilter ? 0 : 2.0), child: Text(label)), selected: isSelected, onSelected: (bool selected) => setState(() { if (isTypeFilter) _selectedType = label; else _selectedColor = label; }), labelStyle: TextStyle(color: isSelected ? const Color(0xFF555655) : const Color(0xFF636363), fontSize: 12, height: 1.0, fontFamily: 'SF Pro', fontWeight: isSelected ? FontWeight.bold : FontWeight.w400), backgroundColor: Colors.white, selectedColor: isTypeFilter ? const Color(0xFFFFDED9) : const Color(0xFFFFE2A5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36), side: BorderSide(color: isSelected ? (isTypeFilter ? const Color(0xFFFF7A65).withOpacity(0.2) : const Color(0xFFFFCC5E).withOpacity(0.4)) : const Color(0xFFE0E0E0).withOpacity(0.5), width: 1.0)), visualDensity: const VisualDensity(horizontal: 0, vertical: -4), labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, showCheckmark: false)));
  }

  Widget _buildPetSectionTitle(String title) => Padding(padding: const EdgeInsets.only(left: 18, bottom: 12), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black, fontFamily: 'SF Pro')));

  Widget _buildPetGrid(List<String> images, {int favoriteIndex = -1}) {
    return GridView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85), itemCount: images.length, itemBuilder: (context, index) => _buildPetCard(imagePath: images[index], isFavorite: index == favoriteIndex));
  }

  Widget _buildPetCard({required String imagePath, required bool isFavorite}) {
    return Container(decoration: ShapeDecoration(color: Colors.white.withOpacity(0.9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), shadows: [BoxShadow(color: Colors.black.withOpacity(0.06), spreadRadius: 1.0, blurRadius: 14, offset: const Offset(0, 0))]), child: Stack(children: [Padding(padding: const EdgeInsets.all(14.0), child: Center(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset(imagePath, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.pets, color: Colors.grey, size: 24))))), Positioned(top: 8, right: 8, child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, size: 20, color: isFavorite ? const Color(0xFFFF8E7C) : const Color(0xFFD9D9D9)))]));
  }
}
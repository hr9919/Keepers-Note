import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'setting_screen.dart';

// --- 데이터 모델 ---
class Pet {
  String name;
  String breed;
  String? imagePath;
  Set<String> triedSnacks;
  String favoriteSnack;
  bool isCat;

  Pet({
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
  const PetScreen({super.key, this.openDrawer});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  String _selectedType = '단색 고양이';
  String _selectedColor = '흰색';
  bool _isMenuOpen = false;

  // 1. 초기 상태: 빈 리스트
  List<Pet> _allPets = [];
  List<FishItem> _fishList = [];
  bool _isFishLoading = true;
  final String _fishApiUrl = 'http://161.33.30.40:8080/api/fish';

  String _imageAssetPath(String? image) {
    if (image == null || image.isEmpty) return 'assets/images/default.png';
    String fullPath = image.startsWith('assets/') ? image : 'assets/$image';
    if (!fullPath.toLowerCase().endsWith('.webp') && !fullPath.toLowerCase().endsWith('.png') && !fullPath.toLowerCase().endsWith('.jpg')) {
      fullPath = '$fullPath.webp';
    }
    return fullPath;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() { if (!_tabController.indexIsChanging) setState(() {}); });
    _fetchFishData();
  }

  Future<void> _fetchFishData() async {
    try {
      final response = await http.get(Uri.parse(_fishApiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() { _fishList = data.map((e) => FishItem.fromJson(e)).toList(); _isFishLoading = false; });
      }
    } catch (e) { setState(() => _isFishLoading = false); }
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  // --- 통합 관리 팝업 ---
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
            _buildMenuTile(Icons.delete_outline_rounded, '반려동물 삭제', () { Navigator.pop(context); _showDeleteConfirm(pet); }, isDestructive: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- 추가/수정 시트 ---
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
                          image: DecorationImage(image: tempImagePath != null ? FileImage(File(tempImagePath!)) : const AssetImage('assets/images/pets.webp') as ImageProvider, fit: BoxFit.cover),
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
                onPressed: () {
                  setState(() {
                    if (isEdit) {
                      pet.name = nameController.text; pet.breed = breedController.text; pet.imagePath = tempImagePath;
                    } else {
                      _allPets.add(Pet(name: nameController.text, breed: breedController.text, imagePath: tempImagePath, isCat: _tabController.index == 0));
                    }
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8E7C), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: Text(isEdit ? '저장하기' : '등록하기', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 간식 실험실 ---
  void _showSnackLabSheet(Pet pet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🐟 ${pet.name}의 간식 실험실', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: _isFishLoading ? const Center(child: CircularProgressIndicator()) : ListView.separated(
                  itemCount: _fishList.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final fish = _fishList[index];
                    final displayName = fish.nameKo ?? fish.name;
                    final isTried = pet.triedSnacks.contains(displayName);
                    final isFav = pet.favoriteSnack == displayName;
                    return ListTile(
                      leading: Row(mainAxisSize: MainAxisSize.min, children: [
                        Checkbox(value: isTried, activeColor: const Color(0xFFFF8E7C), onChanged: (val) { setSheetState(() { if (val!) pet.triedSnacks.add(displayName); else { pet.triedSnacks.remove(displayName); if (isFav) pet.favoriteSnack = ""; } }); setState(() {}); }),
                        Image.asset(_imageAssetPath(fish.image), width: 30, height: 30, errorBuilder: (c,e,s) => const Icon(Icons.phishing)),
                      ]),
                      title: Text(displayName),
                      trailing: IconButton(icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.orange : Colors.grey), onPressed: isTried ? () { setSheetState(() => pet.favoriteSnack = displayName); setState(() {}); } : null),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _buildFabWithMenu(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/bg_gradient.png'), fit: BoxFit.cover)),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildCustomAppBar(context),
              _buildTabBar(),
              _buildPetSummaryList(),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPetGridContent(),
                    const Center(child: Text("강아지 리스트 준비 중", style: TextStyle(color: Colors.grey))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 드롭업 메뉴 (Stack으로 구조 변경) ---
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

  // --- 기타 UI 헬퍼 ---
  Widget _buildMenuItem(String title, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), alignment: Alignment.center, child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF636363)))));
  }

  Widget _buildPetSummaryList() {
    final bool isCatTab = _tabController.index == 0;
    final filteredPets = _allPets.where((p) => p.isCat == isCatTab).toList();

    // 1. 등록된 동물이 없을 때 보여줄 예쁜 빈 카드 UI
    if (filteredPets.isEmpty) {
      return Container(
        height: 110,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: GestureDetector(
          onTap: () => _showPetEditSheet(), // 빈 칸 눌러도 바로 등록창 뜨게
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5), // 살짝 투명한 배경
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF8E7C).withOpacity(0.3), // 테두리는 포인트 컬러로 연하게
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCatTab ? Icons.pets : Icons.pets,
                  color: const Color(0xFFFF8E7C).withOpacity(0.5),
                ),
                const SizedBox(width: 10),
                Text(
                  isCatTab ? "등록된 고양이가 없어요. 친구를 추가해볼까요?" : "등록된 강아지가 없어요. 친구를 추가해볼까요?",
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2. 동물이 있을 때 보여줄 기존 리스트 UI
    return SizedBox(
      height: 110,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        scrollDirection: Axis.horizontal,
        itemCount: filteredPets.length,
        itemBuilder: (context, index) {
          final pet = filteredPets[index];
          // ... 기존의 GestureDetector 코드와 동일 ...
          return GestureDetector(
            onTap: () => _showPetControlSheet(pet),
            child: Container(
              width: 240, margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Row(children: [
                CircleAvatar(radius: 25, backgroundImage: pet.imagePath != null ? FileImage(File(pet.imagePath!)) : const AssetImage('assets/images/pets.webp') as ImageProvider),
                const SizedBox(width: 12),
                Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pet.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(pet.breed, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 8),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (pet.favoriteSnack.isNotEmpty) ...[
                    Builder(builder: (context) {
                      final favFish = _fishList.firstWhere((f) => (f.nameKo ?? f.name) == pet.favoriteSnack, orElse: () => FishItem(id: '', name: '', image: ''));
                      return favFish.image.isNotEmpty ? Image.asset(_imageAssetPath(favFish.image), width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.phishing, size: 18, color: Color(0xFFFF8E7C))) : const Icon(Icons.phishing, size: 18, color: Color(0xFFFF8E7C));
                    }),
                    const SizedBox(height: 2),
                    Text(pet.favoriteSnack, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFF8E7C))),
                  ] else ...[
                    const Icon(Icons.phishing, size: 18, color: Color(0xFFD9D9D9)),
                    const SizedBox(height: 2),
                    const Text('간식 실험실', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFFA4A4A4))),
                  ],
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(leading: Icon(icon, color: isDestructive ? Colors.red[300] : const Color(0xFFFF8E7C)), title: Text(title, style: TextStyle(fontSize: 15, color: isDestructive ? Colors.red[300] : Colors.black87)), onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 8));
  }

  void _showDeleteConfirm(Pet pet) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("삭제"), content: Text("${pet.name}을(를) 삭제하시겠습니까?"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")), TextButton(onPressed: () { setState(() => _allPets.remove(pet)); Navigator.pop(context); }, child: const Text("삭제", style: TextStyle(color: Colors.red)))]));
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
    return SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFilterRow('종류', ['단색 고양이', '얼룩 고양이', '샴 고양이'], true), _buildFilterRow('색', ['흰색', '검정색'], false), const SizedBox(height: 16), _buildPetSectionTitle('올화이트'), _buildPetGrid(['assets/images/cat_white.png'], favoriteIndex: 0), const SizedBox(height: 24), _buildPetSectionTitle('올블랙'), _buildPetGrid(['assets/images/cat_black_1.png', 'assets/images/cat_black_2.png'], favoriteIndex: -1), const SizedBox(height: 120)]));
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
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class PetAdminScreen extends StatefulWidget {
  final String kakaoId;

  const PetAdminScreen({
    super.key,
    required this.kakaoId,
  });

  @override
  State<PetAdminScreen> createState() => _PetAdminScreenState();
}

class _PetAdminScreenState extends State<PetAdminScreen>
    with TickerProviderStateMixin {
  static const String _baseUrl = 'http://161.33.30.40:8080';

  TabController? _animalTabController;
  TabController? _statusTabController;

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isUploading = false;
  bool _isDeleting = false;

  List<Map<String, dynamic>> _catPending = [];
  List<Map<String, dynamic>> _dogPending = [];
  List<Map<String, dynamic>> _catUploaded = [];
  List<Map<String, dynamic>> _dogUploaded = [];

  String? _selectedCatTypeId;
  String? _selectedCatColorId;
  String? _selectedCatEyeId;
  int? _selectedCatVariantNo;

  String? _selectedDogTypeId;
  String? _selectedDogColorId;
  String? _selectedDogEyeId;
  int? _selectedDogVariantNo;

  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _animalTabController = TabController(length: 2, vsync: this);
    _statusTabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _animalTabController?.dispose();
    _statusTabController?.dispose();
    super.dispose();
  }

  bool get _isCatTab => (_animalTabController?.index ?? 0) == 0;
  bool get _isPendingTab => (_statusTabController?.index ?? 0) == 0;

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/cat-variants/pending')),
        http.get(Uri.parse('$_baseUrl/api/dog-variants/pending')),
        http.get(Uri.parse('$_baseUrl/api/cat-variants?uploadedOnly=true')),
        http.get(Uri.parse('$_baseUrl/api/dog-variants?uploadedOnly=true')),
      ]);

      if (results[0].statusCode == 200) {
        _catPending = List<Map<String, dynamic>>.from(
          jsonDecode(utf8.decode(results[0].bodyBytes)),
        );
      }
      if (results[1].statusCode == 200) {
        _dogPending = List<Map<String, dynamic>>.from(
          jsonDecode(utf8.decode(results[1].bodyBytes)),
        );
      }
      if (results[2].statusCode == 200) {
        _catUploaded = List<Map<String, dynamic>>.from(
          jsonDecode(utf8.decode(results[2].bodyBytes)),
        );
      }
      if (results[3].statusCode == 200) {
        _dogUploaded = List<Map<String, dynamic>>.from(
          jsonDecode(utf8.decode(results[3].bodyBytes)),
        );
      }

      _syncSelections();
    } catch (e) {
      _showSnack('목록 불러오기 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _syncSelections() {
    _syncCatSelection();
    _syncDogSelection();
  }

  void _syncCatSelection() {
    final source = _isPendingTab ? _catPending : _catUploaded;
    if (source.isEmpty) {
      _selectedCatTypeId = null;
      _selectedCatColorId = null;
      _selectedCatEyeId = null;
      _selectedCatVariantNo = null;
      return;
    }

    final hasCurrent = source.any((item) =>
    item['catTypeId'] == _selectedCatTypeId &&
        item['colorId'] == _selectedCatColorId &&
        item['eyeId'] == _selectedCatEyeId &&
        _toInt(item['variantNo']) == _selectedCatVariantNo);

    if (!hasCurrent) {
      final first = source.first;
      _selectedCatTypeId = first['catTypeId']?.toString();
      _selectedCatColorId = first['colorId']?.toString();
      _selectedCatEyeId = first['eyeId']?.toString();
      _selectedCatVariantNo = _toInt(first['variantNo']);
    }
  }

  void _syncDogSelection() {
    final source = _isPendingTab ? _dogPending : _dogUploaded;
    if (source.isEmpty) {
      _selectedDogTypeId = null;
      _selectedDogColorId = null;
      _selectedDogEyeId = null;
      _selectedDogVariantNo = null;
      return;
    }

    final hasCurrent = source.any((item) =>
    item['dogTypeId'] == _selectedDogTypeId &&
        item['colorId'] == _selectedDogColorId &&
        item['eyeId'] == _selectedDogEyeId &&
        _toInt(item['variantNo']) == _selectedDogVariantNo);

    if (!hasCurrent) {
      final first = source.first;
      _selectedDogTypeId = first['dogTypeId']?.toString();
      _selectedDogColorId = first['colorId']?.toString();
      _selectedDogEyeId = first['eyeId']?.toString();
      _selectedDogVariantNo = _toInt(first['variantNo']);
    }
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _currentSource(bool isCat) {
    if (isCat) {
      return _isPendingTab ? _catPending : _catUploaded;
    }
    return _isPendingTab ? _dogPending : _dogUploaded;
  }

  List<Map<String, dynamic>> _filteredCatItems() {
    final source = _currentSource(true);
    return source.where((item) {
      return item['catTypeId'] == _selectedCatTypeId &&
          item['colorId'] == _selectedCatColorId &&
          item['eyeId'] == _selectedCatEyeId;
    }).toList()
      ..sort((a, b) => _toInt(a['variantNo'])!.compareTo(_toInt(b['variantNo'])!));
  }

  List<Map<String, dynamic>> _filteredDogItems() {
    final source = _currentSource(false);
    return source.where((item) {
      return item['dogTypeId'] == _selectedDogTypeId &&
          item['colorId'] == _selectedDogColorId &&
          item['eyeId'] == _selectedDogEyeId;
    }).toList()
      ..sort((a, b) => _toInt(a['variantNo'])!.compareTo(_toInt(b['variantNo'])!));
  }

  List<Map<String, String>> _uniqueCatTypes() {
    final source = _currentSource(true);
    final map = <String, String>{};
    for (final item in source) {
      map[item['catTypeId'].toString()] =
          (item['catTypeNameKo'] ?? item['catTypeId']).toString();
    }
    return map.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  List<Map<String, String>> _uniqueCatColors() {
    final source = _currentSource(true);
    final map = <String, String>{};
    for (final item in source.where((e) => e['catTypeId'] == _selectedCatTypeId)) {
      map[item['colorId'].toString()] =
          (item['colorNameKo'] ?? item['colorId']).toString();
    }
    return map.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  List<Map<String, String>> _uniqueCatEyes() {
    final source = _currentSource(true);
    final map = <String, String>{};
    for (final item in source.where((e) =>
    e['catTypeId'] == _selectedCatTypeId &&
        e['colorId'] == _selectedCatColorId)) {
      map[item['eyeId'].toString()] =
          (item['eyeNameKo'] ?? item['eyeId']).toString();
    }
    return map.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  List<int> _uniqueCatVariantNos() {
    return _filteredCatItems()
        .map((e) => _toInt(e['variantNo'])!)
        .toSet()
        .toList()
      ..sort();
  }

  List<Map<String, String>> _uniqueDogTypes() {
    final source = _currentSource(false);
    final map = <String, String>{};
    for (final item in source) {
      map[item['dogTypeId'].toString()] =
          (item['dogTypeNameKo'] ?? item['dogTypeId']).toString();
    }
    return map.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  List<Map<String, String>> _uniqueDogColors() {
    final source = _currentSource(false);
    final map = <String, String>{};
    for (final item in source.where((e) => e['dogTypeId'] == _selectedDogTypeId)) {
      map[item['colorId'].toString()] =
          (item['colorNameKo'] ?? item['colorId']).toString();
    }
    return map.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  List<Map<String, String>> _uniqueDogEyes() {
    final source = _currentSource(false);
    final map = <String, String>{};
    for (final item in source.where((e) =>
    e['dogTypeId'] == _selectedDogTypeId &&
        e['colorId'] == _selectedDogColorId)) {
      map[item['eyeId'].toString()] =
          (item['eyeNameKo'] ?? item['eyeId']).toString();
    }
    return map.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  List<int> _uniqueDogVariantNos() {
    return _filteredDogItems()
        .map((e) => _toInt(e['variantNo'])!)
        .toSet()
        .toList()
      ..sort();
  }

  Map<String, dynamic>? _currentSelectedItem(bool isCat) {
    final source = _currentSource(isCat);
    final typeId = isCat ? _selectedCatTypeId : _selectedDogTypeId;
    final colorId = isCat ? _selectedCatColorId : _selectedDogColorId;
    final eyeId = isCat ? _selectedCatEyeId : _selectedDogEyeId;
    final variantNo = isCat ? _selectedCatVariantNo : _selectedDogVariantNo;

    try {
      return source.firstWhere(
            (item) =>
        (isCat ? item['catTypeId'] : item['dogTypeId']) == typeId &&
            item['colorId'] == colorId &&
            item['eyeId'] == eyeId &&
            _toInt(item['variantNo']) == variantNo,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (file == null) return;

      setState(() {
        _selectedImageFile = File(file.path);
      });
    } catch (e) {
      _showSnack('이미지 선택 실패: $e');
    }
  }

  Future<void> _uploadCurrent() async {
    final bool isCatTab = _isCatTab;

    final String? typeId = isCatTab ? _selectedCatTypeId : _selectedDogTypeId;
    final String? colorId = isCatTab ? _selectedCatColorId : _selectedDogColorId;
    final String? eyeId = isCatTab ? _selectedCatEyeId : _selectedDogEyeId;
    final int? variantNo = isCatTab ? _selectedCatVariantNo : _selectedDogVariantNo;

    if (typeId == null || colorId == null || eyeId == null || variantNo == null) {
      _showSnack('등록할 펫 조합을 먼저 선택해주세요.');
      return;
    }
    if (_selectedImageFile == null) {
      _showSnack('업로드할 이미지를 선택해주세요.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uri = Uri.parse(
        isCatTab
            ? '$_baseUrl/api/admin/cat-variants/upload'
            : '$_baseUrl/api/admin/dog-variants/upload',
      );

      final req = http.MultipartRequest('POST', uri)
        ..fields['kakaoId'] = widget.kakaoId
        ..fields[isCatTab ? 'catTypeId' : 'dogTypeId'] = typeId
        ..fields['colorId'] = colorId
        ..fields['eyeId'] = eyeId
        ..fields['variantNo'] = variantNo.toString()
        ..files.add(
          await http.MultipartFile.fromPath(
            'image',
            _selectedImageFile!.path,
          ),
        );

      final streamed = await req.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnack('등록이 완료됐어요.');
        setState(() {
          _selectedImageFile = null;
          _statusTabController?.index = 1;
        });
        await _loadAll();
      } else {
        _showSnack('등록 실패: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      _showSnack('등록 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteCurrent() async {
    final bool isCatTab = _isCatTab;

    final String? typeId = isCatTab ? _selectedCatTypeId : _selectedDogTypeId;
    final String? colorId = isCatTab ? _selectedCatColorId : _selectedDogColorId;
    final String? eyeId = isCatTab ? _selectedCatEyeId : _selectedDogEyeId;
    final int? variantNo = isCatTab ? _selectedCatVariantNo : _selectedDogVariantNo;

    if (typeId == null || colorId == null || eyeId == null || variantNo == null) {
      _showSnack('삭제할 펫 조합을 먼저 선택해주세요.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('이미지 삭제'),
          content: const Text('현재 등록된 이미지를 삭제할까요?\n삭제 후 다시 등록할 수 있어요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8E7C),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      final uri = Uri.parse(
        isCatTab
            ? '$_baseUrl/api/admin/cat-variants/image'
            : '$_baseUrl/api/admin/dog-variants/image',
      ).replace(
        queryParameters: {
          'kakaoId': widget.kakaoId,
          isCatTab ? 'catTypeId' : 'dogTypeId': typeId,
          'colorId': colorId,
          'eyeId': eyeId,
          'variantNo': variantNo.toString(),
        },
      );

      final response = await http.delete(uri);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnack('삭제가 완료됐어요.');
        setState(() {
          _selectedImageFile = null;
          _statusTabController?.index = 0;
        });
        await _loadAll();
      } else {
        _showSnack('삭제 실패: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      _showSnack('삭제 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF8E7C).withOpacity(0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1ED),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.pets_rounded,
              color: Color(0xFFFF8E7C),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '펫 등록',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF24303A),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '관리자 전용 이미지 등록/삭제 화면',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
              onTap: () => Navigator.pop(context, true),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.close_rounded,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFE0D9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5C6773),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildTopTabs() {
    final animalController = _animalTabController;
    final statusController = _statusTabController;

    if (animalController == null || statusController == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFFE1DA),
            ),
          ),
          child: TabBar(
            controller: animalController,
            onTap: (_) {
              setState(() {
                _selectedImageFile = null;
                _syncSelections();
              });
            },
            labelColor: const Color(0xFFFF8E7C),
            unselectedLabelColor: const Color(0xFF94A3B8),
            indicatorColor: const Color(0xFFFF8E7C),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: '고양이'),
              Tab(text: '강아지'),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFFE1DA),
            ),
          ),
          child: TabBar(
            controller: statusController,
            onTap: (_) {
              setState(() {
                _selectedImageFile = null;
                _syncSelections();
              });
            },
            labelColor: const Color(0xFFFF8E7C),
            unselectedLabelColor: const Color(0xFF94A3B8),
            indicatorColor: const Color(0xFFFF8E7C),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: '미등록'),
              Tab(text: '등록완료'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageBox(Map<String, dynamic>? currentItem) {
    final String? imagePath = currentItem?['imagePath']?.toString();
    final bool hasServerImage = imagePath != null && imagePath.isNotEmpty;

    return AspectRatio(
      aspectRatio: 1.08,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFFFD7CF),
            width: 1.2,
          ),
        ),
        child: _selectedImageFile != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Image.file(
            _selectedImageFile!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        )
            : hasServerImage
            ? ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Image.network(
            '$_baseUrl$imagePath',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _buildImagePlaceholder('이미지를 불러오지 못했어요'),
          ),
        )
            : _buildImagePlaceholder(
          _isPendingTab ? '등록할 이미지를 선택해주세요' : '등록된 이미지가 없어요',
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.image_outlined,
          size: 42,
          color: Color(0xFFFFB8AA),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimalBody({required bool isCat}) {
    final source = _currentSource(isCat);
    final pendingCount = source.length;

    final typeItems = isCat ? _uniqueCatTypes() : _uniqueDogTypes();
    final colorItems = isCat ? _uniqueCatColors() : _uniqueDogColors();
    final eyeItems = isCat ? _uniqueCatEyes() : _uniqueDogEyes();
    final variantNos = isCat ? _uniqueCatVariantNos() : _uniqueDogVariantNos();

    final selectedTypeId = isCat ? _selectedCatTypeId : _selectedDogTypeId;
    final selectedColorId = isCat ? _selectedCatColorId : _selectedDogColorId;
    final selectedEyeId = isCat ? _selectedCatEyeId : _selectedDogEyeId;
    final selectedVariantNo = isCat ? _selectedCatVariantNo : _selectedDogVariantNo;

    final currentItem = _currentSelectedItem(isCat);

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: const Color(0xFFFF8E7C),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFDCD3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isPendingTab ? Icons.inventory_2_rounded : Icons.check_circle_rounded,
                  color: const Color(0xFFFF8E7C),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${isCat ? '고양이' : '강아지'} ${_isPendingTab ? '미등록' : '등록완료'} 조합 $pendingCount개',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (source.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFFFE0D9)),
              ),
              child: Center(
                child: Text(
                  _isPendingTab
                      ? '미등록 조합이 없어요.'
                      : '등록된 조합이 없어요.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            )
          else ...[
            _buildDropdownCard(
              title: isCat ? '종 선택' : '견종 선택',
              child: DropdownButtonFormField<String>(
                value: selectedTypeId,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                items: typeItems
                    .map(
                      (e) => DropdownMenuItem<String>(
                    value: e['id'],
                    child: Text(e['name']!),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedImageFile = null;
                    if (isCat) {
                      _selectedCatTypeId = value;
                      final nextColors = _uniqueCatColors();
                      _selectedCatColorId =
                      nextColors.isNotEmpty ? nextColors.first['id'] : null;
                      final nextEyes = _uniqueCatEyes();
                      _selectedCatEyeId =
                      nextEyes.isNotEmpty ? nextEyes.first['id'] : null;
                      final nextVariantNos = _uniqueCatVariantNos();
                      _selectedCatVariantNo =
                      nextVariantNos.isNotEmpty ? nextVariantNos.first : null;
                    } else {
                      _selectedDogTypeId = value;
                      final nextColors = _uniqueDogColors();
                      _selectedDogColorId =
                      nextColors.isNotEmpty ? nextColors.first['id'] : null;
                      final nextEyes = _uniqueDogEyes();
                      _selectedDogEyeId =
                      nextEyes.isNotEmpty ? nextEyes.first['id'] : null;
                      final nextVariantNos = _uniqueDogVariantNos();
                      _selectedDogVariantNo =
                      nextVariantNos.isNotEmpty ? nextVariantNos.first : null;
                    }
                  });
                },
              ),
            ),
            _buildDropdownCard(
              title: '털색 선택',
              child: DropdownButtonFormField<String>(
                value: selectedColorId,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                items: colorItems
                    .map(
                      (e) => DropdownMenuItem<String>(
                    value: e['id'],
                    child: Text(e['name']!),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedImageFile = null;
                    if (isCat) {
                      _selectedCatColorId = value;
                      final nextEyes = _uniqueCatEyes();
                      _selectedCatEyeId =
                      nextEyes.isNotEmpty ? nextEyes.first['id'] : null;
                      final nextVariantNos = _uniqueCatVariantNos();
                      _selectedCatVariantNo =
                      nextVariantNos.isNotEmpty ? nextVariantNos.first : null;
                    } else {
                      _selectedDogColorId = value;
                      final nextEyes = _uniqueDogEyes();
                      _selectedDogEyeId =
                      nextEyes.isNotEmpty ? nextEyes.first['id'] : null;
                      final nextVariantNos = _uniqueDogVariantNos();
                      _selectedDogVariantNo =
                      nextVariantNos.isNotEmpty ? nextVariantNos.first : null;
                    }
                  });
                },
              ),
            ),
            _buildDropdownCard(
              title: '눈 선택',
              child: DropdownButtonFormField<String>(
                value: selectedEyeId,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                items: eyeItems
                    .map(
                      (e) => DropdownMenuItem<String>(
                    value: e['id'],
                    child: Text(e['name']!),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedImageFile = null;
                    if (isCat) {
                      _selectedCatEyeId = value;
                      final nextVariantNos = _uniqueCatVariantNos();
                      _selectedCatVariantNo =
                      nextVariantNos.isNotEmpty ? nextVariantNos.first : null;
                    } else {
                      _selectedDogEyeId = value;
                      final nextVariantNos = _uniqueDogVariantNos();
                      _selectedDogVariantNo =
                      nextVariantNos.isNotEmpty ? nextVariantNos.first : null;
                    }
                  });
                },
              ),
            ),
            _buildDropdownCard(
              title: '번호 선택',
              child: DropdownButtonFormField<int>(
                value: selectedVariantNo,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                items: variantNos
                    .map(
                      (e) => DropdownMenuItem<int>(
                    value: e,
                    child: Text('${isCat ? 'cat' : 'dog'} $e'),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedImageFile = null;
                    if (isCat) {
                      _selectedCatVariantNo = value;
                    } else {
                      _selectedDogVariantNo = value;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFE0D9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (currentItem != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              isCat
                                  ? (currentItem['catTypeNameKo'] ?? currentItem['catTypeId'])
                                  : (currentItem['dogTypeNameKo'] ?? currentItem['dogTypeId']),
                              currentItem['colorNameKo'] ?? currentItem['colorId'],
                              currentItem['eyeNameKo'] ?? currentItem['eyeId'],
                              '${isCat ? 'cat' : 'dog'} ${currentItem['variantNo']}',
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  _buildImageBox(currentItem),
                  const SizedBox(height: 14),
                  if (_isPendingTab)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : _pickImage,
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('이미지 선택'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              side: const BorderSide(color: Color(0xFFFFD4CB)),
                              foregroundColor: const Color(0xFF5C6773),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isUploading ? null : _uploadCurrent,
                            icon: _isUploading
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.1,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.cloud_upload_rounded),
                            label: Text(_isUploading ? '등록중...' : '등록'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: const Color(0xFFFF8E7C),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_isDeleting || _isUploading) ? null : _pickImage,
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('새 이미지 선택'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              side: const BorderSide(color: Color(0xFFFFD4CB)),
                              foregroundColor: const Color(0xFF5C6773),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_isDeleting || _isUploading) ? null : _deleteCurrent,
                            icon: _isDeleting
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.1,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.delete_rounded),
                            label: Text(_isDeleting ? '삭제중...' : '삭제'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: const Color(0xFFEF6C5B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!_isPendingTab && _selectedImageFile != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _uploadCurrent,
                        icon: _isUploading
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.1,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.restart_alt_rounded),
                        label: Text(_isUploading ? '재등록중...' : '선택한 이미지로 다시 등록'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFFFF8E7C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTopTabs(),
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF8E7C),
                ),
              )
                  : (_animalTabController == null)
                  ? const SizedBox.shrink()
                  : TabBarView(
                controller: _animalTabController,
                children: [
                  _buildAnimalBody(isCat: true),
                  _buildAnimalBody(isCat: false),
                ],
              )
            ),
          ],
        ),
      ),
    );
  }
}
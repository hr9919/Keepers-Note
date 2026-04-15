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
  bool _isUploadedLoaded = false;

  List<Map<String, dynamic>> _catPending = [];
  List<Map<String, dynamic>> _dogPending = [];
  List<Map<String, dynamic>> _catUploaded = [];
  List<Map<String, dynamic>> _dogUploaded = [];

  String? _selectedCatTypeId;
  String? _selectedCatColorId;
  String? _selectedCatEyeTypeId;
  String? _selectedCatEyeColorId;
  int? _selectedCatVariantNo;

  String? _selectedDogTypeId;
  String? _selectedDogColorId;
  String? _selectedDogEyeTypeId;
  String? _selectedDogEyeColorId;
  int? _selectedDogVariantNo;

  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _animalTabController = TabController(length: 2, vsync: this);
    _statusTabController = TabController(length: 2, vsync: this);

    _animalTabController?.addListener(() {
      if (!mounted) return;
      if (!(_animalTabController?.indexIsChanging ?? false)) {
        setState(() {
          _selectedImageFile = null;
          _syncSelections();
        });
      }
    });

    _statusTabController?.addListener(() async {
      if (!mounted) return;
      if ((_statusTabController?.indexIsChanging ?? false)) return;

      if (_isPendingTab) {
        setState(() {
          _selectedImageFile = null;
          _syncSelections();
        });
      } else {
        await _ensureUploadedLoaded();
      }
    });

    _loadInitial();
  }

  @override
  void dispose() {
    _animalTabController?.dispose();
    _statusTabController?.dispose();
    super.dispose();
  }

  bool get _isCatTab => (_animalTabController?.index ?? 0) == 0;
  bool get _isPendingTab => (_statusTabController?.index ?? 0) == 0;

  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/cat-variants/pending')),
        http.get(Uri.parse('$_baseUrl/api/dog-variants/pending')),
      ]);

      if (results[0].statusCode == 200) {
        _catPending = List<Map<String, dynamic>>.from(
          jsonDecode(utf8.decode(results[0].bodyBytes)),
        );
      } else {
        _catPending = [];
      }

      if (results[1].statusCode == 200) {
        _dogPending = List<Map<String, dynamic>>.from(
          jsonDecode(utf8.decode(results[1].bodyBytes)),
        );
      } else {
        _dogPending = [];
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

  Future<void> _ensureUploadedLoaded() async {
    if (_isUploadedLoaded) {
      if (mounted) {
        setState(() {
          _selectedImageFile = null;
          _syncSelections();
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/cat-variants?uploadedOnly=true')),
        http.get(Uri.parse('$_baseUrl/api/dog-variants?uploadedOnly=true')),
      ]);

      if (results[0].statusCode == 200) {
        _catUploaded = List<Map<String, dynamic>>.from(
          jsonDecode(utf8.decode(results[0].bodyBytes)),
        );
      } else {
        _catUploaded = [];
      }

      if (results[1].statusCode == 200) {
        _dogUploaded = List<Map<String, dynamic>>.from(
          jsonDecode(utf8.decode(results[1].bodyBytes)),
        );
      } else {
        _dogUploaded = [];
      }

      _isUploadedLoaded = true;
      _syncSelections();
    } catch (e) {
      _showSnack('등록완료 목록 불러오기 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshCurrentTab() async {
    if (_isPendingTab) {
      await _loadInitial();
    } else {
      _isUploadedLoaded = false;
      await _ensureUploadedLoaded();
    }
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String _toStr(dynamic value) => value?.toString() ?? '';

  List<Map<String, dynamic>> _currentSource(bool isCat) {
    if (isCat) {
      return _isPendingTab ? _catPending : _catUploaded;
    }
    return _isPendingTab ? _dogPending : _dogUploaded;
  }

  String _itemTypeId(Map<String, dynamic> item, bool isCat) {
    return isCat ? _toStr(item['catTypeId']) : _toStr(item['dogTypeId']);
  }

  String _itemTypeName(Map<String, dynamic> item, bool isCat) {
    return isCat
        ? (_toStr(item['catTypeNameKo']).isNotEmpty
        ? _toStr(item['catTypeNameKo'])
        : _toStr(item['catTypeId']))
        : (_toStr(item['dogTypeNameKo']).isNotEmpty
        ? _toStr(item['dogTypeNameKo'])
        : _toStr(item['dogTypeId']));
  }

  String _itemColorId(Map<String, dynamic> item) => _toStr(item['colorId']);

  String _itemColorName(Map<String, dynamic> item) {
    return _toStr(item['colorNameKo']).isNotEmpty
        ? _toStr(item['colorNameKo'])
        : _toStr(item['colorId']);
  }

  String _itemEyeTypeId(Map<String, dynamic> item) => _toStr(item['eyeStyle']);

  String _itemEyeTypeName(Map<String, dynamic> item) {
    final styleKo = _toStr(item['eyeStyleKo']);
    if (styleKo.isNotEmpty) return styleKo;

    final style = _toStr(item['eyeStyle']);
    if (style == 'cat_eye') return '고양이눈';
    if (style == 'round_eye') return '땡눈';
    if (style == 'sleepy_eye') return '졸린눈';
    if (style == 'droopy_eye') return '처진눈';
    if (style == 'dot_eye') return '콩눈';
    return style;
  }

  String _itemEyeColorId(Map<String, dynamic> item) => _toStr(item['eyeColorId']);

  String _itemEyeColorName(Map<String, dynamic> item) {
    final name = _toStr(item['eyeColorNameKo']);
    if (name.isNotEmpty) return name;

    final id = _toStr(item['eyeColorId']);
    if (id.isNotEmpty) return id;

    return '자동';
  }

  int _itemVariantNo(Map<String, dynamic> item) => _toInt(item['variantNo']) ?? 1;

  void _syncSelections() {
    _syncCatSelection();
    _syncDogSelection();
  }

  void _syncCatSelection() {
    final source = _currentSource(true);
    if (source.isEmpty) {
      _selectedCatTypeId = null;
      _selectedCatColorId = null;
      _selectedCatEyeTypeId = null;
      _selectedCatEyeColorId = null;
      _selectedCatVariantNo = null;
      return;
    }

    final hasCurrent = source.any((item) {
      final baseMatch = _itemTypeId(item, true) == _selectedCatTypeId &&
          _itemColorId(item) == _selectedCatColorId &&
          _itemEyeTypeId(item) == _selectedCatEyeTypeId &&
          _itemEyeColorId(item) == (_selectedCatEyeColorId ?? '');

      if (_isPendingTab) return baseMatch;
      return baseMatch && _itemVariantNo(item) == _selectedCatVariantNo;
    });

    if (!hasCurrent) {
      final first = source.first;
      _selectedCatTypeId = _itemTypeId(first, true);
      _selectedCatColorId = _itemColorId(first);
      _selectedCatEyeTypeId = _itemEyeTypeId(first);
      _selectedCatEyeColorId = _itemEyeColorId(first);
      _selectedCatVariantNo = _itemVariantNo(first);
      _normalizeCatSelection();
    }
  }

  void _syncDogSelection() {
    final source = _currentSource(false);
    if (source.isEmpty) {
      _selectedDogTypeId = null;
      _selectedDogColorId = null;
      _selectedDogEyeTypeId = null;
      _selectedDogEyeColorId = null;
      _selectedDogVariantNo = null;
      return;
    }

    final hasCurrent = source.any((item) {
      final baseMatch = _itemTypeId(item, false) == _selectedDogTypeId &&
          _itemColorId(item) == _selectedDogColorId &&
          _itemEyeTypeId(item) == _selectedDogEyeTypeId &&
          _itemEyeColorId(item) == (_selectedDogEyeColorId ?? '');

      if (_isPendingTab) return baseMatch;
      return baseMatch && _itemVariantNo(item) == _selectedDogVariantNo;
    });

    if (!hasCurrent) {
      final first = source.first;
      _selectedDogTypeId = _itemTypeId(first, false);
      _selectedDogColorId = _itemColorId(first);
      _selectedDogEyeTypeId = _itemEyeTypeId(first);
      _selectedDogEyeColorId = _itemEyeColorId(first);
      _selectedDogVariantNo = _itemVariantNo(first);
      _normalizeDogSelection();
    }
  }

  List<Map<String, dynamic>> _filteredItems(bool isCat) {
    final source = _currentSource(isCat);
    final selectedTypeId = isCat ? _selectedCatTypeId : _selectedDogTypeId;
    final selectedColorId = isCat ? _selectedCatColorId : _selectedDogColorId;
    final selectedEyeTypeId = isCat ? _selectedCatEyeTypeId : _selectedDogEyeTypeId;
    final selectedEyeColorId = isCat ? _selectedCatEyeColorId : _selectedDogEyeColorId;

    final filtered = source.where((item) {
      return _itemTypeId(item, isCat) == selectedTypeId &&
          _itemColorId(item) == selectedColorId &&
          _itemEyeTypeId(item) == selectedEyeTypeId &&
          _itemEyeColorId(item) == (selectedEyeColorId ?? '');
    }).toList()
      ..sort((a, b) => _itemVariantNo(a).compareTo(_itemVariantNo(b)));

    return filtered;
  }

  List<Map<String, String>> _uniqueTypes(bool isCat) {
    final source = _currentSource(isCat);
    final map = <String, String>{};

    for (final item in source) {
      map[_itemTypeId(item, isCat)] = _itemTypeName(item, isCat);
    }

    return map.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  List<Map<String, String>> _uniqueColors(bool isCat) {
    final source = _currentSource(isCat);
    final selectedTypeId = isCat ? _selectedCatTypeId : _selectedDogTypeId;
    final map = <String, String>{};

    for (final item in source.where((e) => _itemTypeId(e, isCat) == selectedTypeId)) {
      map[_itemColorId(item)] = _itemColorName(item);
    }

    return map.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  List<Map<String, String>> _uniqueEyeTypes(bool isCat) {
    final source = _currentSource(isCat);
    final selectedTypeId = isCat ? _selectedCatTypeId : _selectedDogTypeId;
    final selectedColorId = isCat ? _selectedCatColorId : _selectedDogColorId;
    final map = <String, String>{};

    for (final item in source.where((e) =>
    _itemTypeId(e, isCat) == selectedTypeId &&
        _itemColorId(e) == selectedColorId)) {
      map[_itemEyeTypeId(item)] = _itemEyeTypeName(item);
    }

    return map.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  List<Map<String, String>> _uniqueEyeColors(bool isCat) {
    final source = _currentSource(isCat);
    final selectedTypeId = isCat ? _selectedCatTypeId : _selectedDogTypeId;
    final selectedColorId = isCat ? _selectedCatColorId : _selectedDogColorId;
    final selectedEyeTypeId = isCat ? _selectedCatEyeTypeId : _selectedDogEyeTypeId;
    final map = <String, String>{};

    for (final item in source.where((e) =>
    _itemTypeId(e, isCat) == selectedTypeId &&
        _itemColorId(e) == selectedColorId &&
        _itemEyeTypeId(e) == selectedEyeTypeId)) {
      map[_itemEyeColorId(item)] = _itemEyeColorName(item);
    }

    return map.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  List<int> _uniqueVariantNos(bool isCat) {
    return _filteredItems(isCat)
        .map(_itemVariantNo)
        .toSet()
        .toList()
      ..sort();
  }

  bool _isSingleColorType(bool isCat) => _uniqueColors(isCat).length <= 1;

  bool _isSingleEyeColorType(bool isCat) => _uniqueEyeColors(isCat).length <= 1;

  String? _fixedColorName(bool isCat) {
    final items = _uniqueColors(isCat);
    if (items.length == 1) return items.first['name'];
    return null;
  }

  String? _fixedEyeColorName(bool isCat) {
    final items = _uniqueEyeColors(isCat);
    if (items.length == 1) return items.first['name'];
    return null;
  }

  void _normalizeCatSelection() {
    final typeItems = _uniqueTypes(true);
    if (typeItems.isEmpty) {
      _selectedCatTypeId = null;
      _selectedCatColorId = null;
      _selectedCatEyeTypeId = null;
      _selectedCatEyeColorId = null;
      _selectedCatVariantNo = null;
      return;
    }

    final validTypeIds = typeItems.map((e) => e['id']!).toSet();
    if (!validTypeIds.contains(_selectedCatTypeId)) {
      _selectedCatTypeId = typeItems.first['id'];
    }

    final colorItems = _uniqueColors(true);
    final validColorIds = colorItems.map((e) => e['id']!).toSet();
    if (!validColorIds.contains(_selectedCatColorId)) {
      _selectedCatColorId = colorItems.isNotEmpty ? colorItems.first['id'] : null;
    }

    final eyeTypeItems = _uniqueEyeTypes(true);
    final validEyeTypeIds = eyeTypeItems.map((e) => e['id']!).toSet();
    if (!validEyeTypeIds.contains(_selectedCatEyeTypeId)) {
      _selectedCatEyeTypeId = eyeTypeItems.isNotEmpty ? eyeTypeItems.first['id'] : null;
    }

    final eyeColorItems = _uniqueEyeColors(true);
    final validEyeColorIds = eyeColorItems.map((e) => e['id']!).toSet();
    if (!validEyeColorIds.contains(_selectedCatEyeColorId)) {
      _selectedCatEyeColorId =
      eyeColorItems.isNotEmpty ? eyeColorItems.first['id'] : null;
    }

    if (_isPendingTab) {
      _selectedCatVariantNo = null;
    } else {
      final variantNos = _uniqueVariantNos(true);
      if (!variantNos.contains(_selectedCatVariantNo)) {
        _selectedCatVariantNo = variantNos.isNotEmpty ? variantNos.first : null;
      }
    }
  }

  void _normalizeDogSelection() {
    final typeItems = _uniqueTypes(false);
    if (typeItems.isEmpty) {
      _selectedDogTypeId = null;
      _selectedDogColorId = null;
      _selectedDogEyeTypeId = null;
      _selectedDogEyeColorId = null;
      _selectedDogVariantNo = null;
      return;
    }

    final validTypeIds = typeItems.map((e) => e['id']!).toSet();
    if (!validTypeIds.contains(_selectedDogTypeId)) {
      _selectedDogTypeId = typeItems.first['id'];
    }

    final colorItems = _uniqueColors(false);
    final validColorIds = colorItems.map((e) => e['id']!).toSet();
    if (!validColorIds.contains(_selectedDogColorId)) {
      _selectedDogColorId = colorItems.isNotEmpty ? colorItems.first['id'] : null;
    }

    final eyeTypeItems = _uniqueEyeTypes(false);
    final validEyeTypeIds = eyeTypeItems.map((e) => e['id']!).toSet();
    if (!validEyeTypeIds.contains(_selectedDogEyeTypeId)) {
      _selectedDogEyeTypeId = eyeTypeItems.isNotEmpty ? eyeTypeItems.first['id'] : null;
    }

    final eyeColorItems = _uniqueEyeColors(false);
    final validEyeColorIds = eyeColorItems.map((e) => e['id']!).toSet();
    if (!validEyeColorIds.contains(_selectedDogEyeColorId)) {
      _selectedDogEyeColorId =
      eyeColorItems.isNotEmpty ? eyeColorItems.first['id'] : null;
    }

    if (_isPendingTab) {
      _selectedDogVariantNo = null;
    } else {
      final variantNos = _uniqueVariantNos(false);
      if (!variantNos.contains(_selectedDogVariantNo)) {
        _selectedDogVariantNo = variantNos.isNotEmpty ? variantNos.first : null;
      }
    }
  }

  Map<String, dynamic>? _currentSelectedItem(bool isCat) {
    final filtered = _filteredItems(isCat);
    if (filtered.isEmpty) return null;

    if (_isPendingTab) {
      return filtered.first;
    }

    final variantNo = isCat ? _selectedCatVariantNo : _selectedDogVariantNo;
    try {
      return filtered.firstWhere((item) => _itemVariantNo(item) == variantNo);
    } catch (_) {
      return filtered.first;
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
    final String? eyeTypeId =
    isCatTab ? _selectedCatEyeTypeId : _selectedDogEyeTypeId;
    final String? eyeColorId =
    isCatTab ? _selectedCatEyeColorId : _selectedDogEyeColorId;

    if (typeId == null || colorId == null || eyeTypeId == null) {
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
        ..fields['eyeTypeId'] = eyeTypeId;

      if (eyeColorId != null && eyeColorId.isNotEmpty) {
        req.fields['eyeColorId'] = eyeColorId;
      }

      req.files.add(
        await http.MultipartFile.fromPath(
          'image',
          _selectedImageFile!.path,
        ),
      );

      final streamed = await req.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnack('등록이 완료됐어요.');
        _isUploadedLoaded = false;

        setState(() {
          _selectedImageFile = null;
          _statusTabController?.index = 1;
        });

        await _ensureUploadedLoaded();
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
    final String? eyeTypeId =
    isCatTab ? _selectedCatEyeTypeId : _selectedDogEyeTypeId;
    final String? eyeColorId =
    isCatTab ? _selectedCatEyeColorId : _selectedDogEyeColorId;
    final int? variantNo =
    isCatTab ? _selectedCatVariantNo : _selectedDogVariantNo;

    if (typeId == null || colorId == null || eyeTypeId == null || variantNo == null) {
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
      final query = <String, String>{
        'kakaoId': widget.kakaoId,
        isCatTab ? 'catTypeId' : 'dogTypeId': typeId,
        'colorId': colorId,
        'eyeTypeId': eyeTypeId,
        'variantNo': variantNo.toString(),
      };

      if (eyeColorId != null && eyeColorId.isNotEmpty) {
        query['eyeColorId'] = eyeColorId;
      }

      final uri = Uri.parse(
        isCatTab
            ? '$_baseUrl/api/admin/cat-variants/image'
            : '$_baseUrl/api/admin/dog-variants/image',
      ).replace(queryParameters: query);

      final response = await http.delete(uri);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnack('삭제가 완료됐어요.');
        _isUploadedLoaded = false;

        setState(() {
          _selectedImageFile = null;
          _statusTabController?.index = 0;
        });

        await _loadInitial();
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
            errorBuilder: (_, __, ___) =>
                _buildImagePlaceholder('이미지를 불러오지 못했어요'),
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
    final count = source.length;

    final typeItems = _uniqueTypes(isCat);
    final colorItems = _uniqueColors(isCat);
    final eyeTypeItems = _uniqueEyeTypes(isCat);
    final eyeColorItems = _uniqueEyeColors(isCat);
    final variantNos = _uniqueVariantNos(isCat);

    final selectedTypeId = isCat ? _selectedCatTypeId : _selectedDogTypeId;
    final selectedColorId = isCat ? _selectedCatColorId : _selectedDogColorId;
    final selectedEyeTypeId = isCat ? _selectedCatEyeTypeId : _selectedDogEyeTypeId;
    final selectedEyeColorId =
    isCat ? _selectedCatEyeColorId : _selectedDogEyeColorId;
    final selectedVariantNo =
    isCat ? _selectedCatVariantNo : _selectedDogVariantNo;

    final currentItem = _currentSelectedItem(isCat);

    final bool isSingleColor = _isSingleColorType(isCat);
    final bool isSingleEyeColor = _isSingleEyeColorType(isCat);
    final String? fixedColorName = _fixedColorName(isCat);
    final String? fixedEyeColorName = _fixedEyeColorName(isCat);

    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
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
                  _isPendingTab
                      ? Icons.inventory_2_rounded
                      : Icons.check_circle_rounded,
                  color: const Color(0xFFFF8E7C),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${isCat ? '고양이' : '강아지'} ${_isPendingTab ? '미등록' : '등록완료'} 조합 $count개',
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
                  _isPendingTab ? '미등록 조합이 없어요.' : '등록된 조합이 없어요.',
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
                      _normalizeCatSelection();
                    } else {
                      _selectedDogTypeId = value;
                      _normalizeDogSelection();
                    }
                  });
                },
              ),
            ),
            _buildDropdownCard(
              title: '털색 선택',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
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
                    onChanged: isSingleColor
                        ? null
                        : (value) {
                      setState(() {
                        _selectedImageFile = null;
                        if (isCat) {
                          _selectedCatColorId = value;
                          _normalizeCatSelection();
                        } else {
                          _selectedDogColorId = value;
                          _normalizeDogSelection();
                        }
                      });
                    },
                  ),
                  if (isSingleColor) ...[
                    const SizedBox(height: 8),
                    Text(
                      '이 종은 털색이 ${fixedColorName ?? '자동'}으로 고정돼요.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAA8E86),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildDropdownCard(
              title: '눈 종류 선택',
              child: DropdownButtonFormField<String>(
                value: selectedEyeTypeId,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                items: eyeTypeItems
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
                      _selectedCatEyeTypeId = value;
                      _normalizeCatSelection();
                    } else {
                      _selectedDogEyeTypeId = value;
                      _normalizeDogSelection();
                    }
                  });
                },
              ),
            ),
            _buildDropdownCard(
              title: '눈 색 선택',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedEyeColorId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    items: eyeColorItems
                        .map(
                          (e) => DropdownMenuItem<String>(
                        value: e['id'],
                        child: Text(e['name']!),
                      ),
                    )
                        .toList(),
                    onChanged: isSingleEyeColor
                        ? null
                        : (value) {
                      setState(() {
                        _selectedImageFile = null;
                        if (isCat) {
                          _selectedCatEyeColorId = value;
                          _normalizeCatSelection();
                        } else {
                          _selectedDogEyeColorId = value;
                          _normalizeDogSelection();
                        }
                      });
                    },
                  ),
                  if (isSingleEyeColor) ...[
                    const SizedBox(height: 8),
                    Text(
                      '이 눈 종류는 눈 색이 ${fixedEyeColorName ?? '자동'}으로 고정돼요.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAA8E86),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!_isPendingTab)
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
                              _itemTypeName(currentItem, isCat),
                              _itemColorName(currentItem),
                              _itemEyeTypeName(currentItem),
                              _itemEyeColorName(currentItem),
                              if (!_isPendingTab)
                                '${isCat ? 'cat' : 'dog'} ${_itemVariantNo(currentItem)}',
                            ].where((e) => e.trim().isNotEmpty).join(' · '),
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
                            onPressed: (_isDeleting || _isUploading)
                                ? null
                                : _pickImage,
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
                            onPressed: (_isDeleting || _isUploading)
                                ? null
                                : _deleteCurrent,
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
                            : const Icon(Icons.add_photo_alternate_rounded),
                        label: Text(_isUploading ? '등록중...' : '같은 카테고리로 새 이미지 추가'),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
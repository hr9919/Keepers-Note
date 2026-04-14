import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'models/pet_model.dart';

class ManagePetsScreen extends StatefulWidget {
  final List<Pet> pets;
  final Function(List<Pet>) onUpdate;
  final Function(int) deletePet;
  final Function(Pet) onEdit;

  const ManagePetsScreen({
    super.key,
    required this.pets,
    required this.onUpdate,
    required this.deletePet,
    required this.onEdit,
  });

  @override
  State<ManagePetsScreen> createState() => _ManagePetsScreenState();
}

class _ManagePetsScreenState extends State<ManagePetsScreen> {
  late List<Pet> _tempPets;
  final Set<int> _selectedIds = {};
  bool _isChanged = false;

  static const String _baseUrl = 'http://161.33.30.40:8080';

  @override
  void initState() {
    super.initState();
    _tempPets = List.from(widget.pets);
  }

  double _getBottomPadding(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemPadding = MediaQuery.of(context).padding.bottom;
    return bottomInset > 0 ? bottomInset + 16 : systemPadding + 16;
  }

  Future<void> _handleEdit(Pet pet) async {
    await widget.onEdit(pet);
    if (!mounted) return;

    setState(() {
      _isChanged = true;
    });
  }

  void _saveAndExit() {
    widget.onUpdate(_tempPets);
    Navigator.pop(context);
  }

  String _resolvePetImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return '';
    final value = imagePath.trim();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    if (value.startsWith('/uploads/')) {
      return '$_baseUrl$value';
    }

    return value;
  }

  bool _isRemotePetImage(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return false;
    final value = imagePath.trim();
    return value.startsWith('/uploads/') ||
        value.startsWith('http://') ||
        value.startsWith('https://');
  }

  void _showPetImagePreview(Pet pet) {
    final imagePath = pet.imagePath;
    final isRemote = _isRemotePetImage(imagePath);
    final remoteUrl = _resolvePetImageUrl(imagePath);
    final hasLocalFile =
        imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
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
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleEdit(pet);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8E7C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text(
                          '사진/정보 수정하기',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
      ),
    );
  }

  Future<bool> _showExitDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF8E7C),
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '변경사항이 있어요!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '저장하지 않고 나가시면\n변경된 순서가 반영되지 않아요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E93),
                height: 1.5,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFEAEAEA)),
                    ),
                  ),
                  child: const Text(
                    '그냥 나갈래요',
                    style: TextStyle(
                      color: Color(0xFFA4A4A4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8E7C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '저장하기',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ) ??
        false;
  }

  void _handleDelete() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          '선택 삭제',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('${_selectedIds.length}마리의 정보를 정말 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '삭제',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final id in _selectedIds) {
        await widget.deletePet(id);
      }

      setState(() {
        _tempPets.removeWhere((p) => _selectedIds.contains(p.id));
        _selectedIds.clear();
        _isChanged = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isChanged,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldSave = await _showExitDialog();
        if (shouldSave) {
          _saveAndExit();
        } else {
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFDFDFD),
        appBar: AppBar(
          title: const Text(
            '펫 통합 관리',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: [
            if (_selectedIds.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                onPressed: _handleDelete,
              ),
          ],
        ),
        body: Column(
          children: [
            _buildInfoBanner(),
            Expanded(
              child: _tempPets.isEmpty
                  ? _buildEmptyState()
                  : ReorderableListView.builder(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  _isChanged ? 120 : 40,
                ),
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final animValue =
                      Curves.easeInOut.transform(animation.value);
                      final elevation = lerpDouble(0, 8, animValue)!;
                      return Material(
                        elevation: elevation,
                        color: Colors.transparent,
                        shadowColor: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) newIndex -= 1;
                    final item = _tempPets.removeAt(oldIndex);
                    _tempPets.insert(newIndex, item);
                    _isChanged = true;
                  });
                },
                itemCount: _tempPets.length,
                itemBuilder: (context, index) =>
                    _buildManageCard(_tempPets[index]),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: AnimatedSlide(
          offset: _isChanged ? const Offset(0, 0) : const Offset(0, 1.5),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: _isChanged ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Padding(
              padding: EdgeInsets.only(bottom: _getBottomPadding(context)),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: _saveAndExit,
                  backgroundColor: const Color(0xFFFF8E7C),
                  elevation: 0,
                  focusElevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  label: const Text(
                    '변경사항 저장하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets_rounded,
            size: 64,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            '관리할 동물이 없습니다.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetImage(String? imagePath, {BoxFit fit = BoxFit.cover}) {
    if (imagePath == null || imagePath.isEmpty) {
      return Image.asset('assets/images/pets.webp', fit: fit);
    }

    if (imagePath.startsWith('/uploads')) {
      return Image.network(
        '$_baseUrl$imagePath',
        fit: fit,
        errorBuilder: (_, __, ___) {
          return Image.asset('assets/images/pets.webp', fit: fit);
        },
      );
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: fit,
        errorBuilder: (_, __, ___) {
          return Image.asset('assets/images/pets.webp', fit: fit);
        },
      );
    }

    if (File(imagePath).existsSync()) {
      return Image.file(
        File(imagePath),
        fit: fit,
        errorBuilder: (_, __, ___) {
          return Image.asset('assets/images/pets.webp', fit: fit);
        },
      );
    }

    return Image.asset('assets/images/pets.webp', fit: fit);
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: [
          Icon(
            Icons.tips_and_updates_rounded,
            size: 16,
            color: Colors.orange.shade300,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '사진을 누르면 확대, 수정 버튼을 누르면 편집 화면으로 이동해요.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageCard(Pet pet) {
    final isSelected = _selectedIds.contains(pet.id);

    return Container(
      key: ValueKey('manage_${pet.id}'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFF8E7C)
              : const Color(0xFFF2F2F2),
          width: isSelected ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isSelected,
              activeColor: const Color(0xFFFF8E7C),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFFFF8E7C)
                    : const Color(0xFFD1D1D1),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              onChanged: (val) {
                setState(() {
                  if (val == true && pet.id != null) {
                    _selectedIds.add(pet.id!);
                  } else {
                    _selectedIds.remove(pet.id);
                  }
                });
              },
            ),
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showPetImagePreview(pet),
              onLongPress: () => _handleEdit(pet),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
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
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.52),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.zoom_in_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        title: Text(
          pet.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          pet.breed,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '편집',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.edit_note_rounded,
                color: Color(0xFFFF8E7C),
                size: 28,
              ),
              onPressed: () => _handleEdit(pet),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.drag_indicator_rounded,
              color: Color(0xFFE0E0E0),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
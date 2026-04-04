import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'models/resource_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<ResourceModel> _resources = [];
  bool _isLoading = true;
  Set<String> _enabledResources = {};
  bool _showAllNpcs = true;
  bool _showAllAnimals = false;

  final Color seaColor = const Color(0xFF6CA0B3);
  final Color accentColor = const Color(0xFFFF8E7C);

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      final data = await ApiService.getResources();
      if (mounted) {
        setState(() {
          _resources = data;

          _enabledResources = data
              .where(
                (res) =>
            res.category != 'npc' &&
                res.category != 'animal' &&
                !res.isFixed,
          )
              .map((res) => res.resourceName)
              .toSet();

          _showAllNpcs = true;
          _showAllAnimals = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleVote(ResourceModel res) {
    setState(() {
      final index = _resources.indexOf(res);
      if (index != -1) {
        _resources[index] = res.copyWith(
          voteCount: res.voteCount + 1,
          isVerified: (res.voteCount + 1) >= 3,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${res.koName}에 투표했습니다! 현재 ${res.voteCount + 1}표"),
      ),
    );

    Navigator.pop(context);
  }

  void _showResourceDetail(ResourceModel res) {
    final bool needsVote = !res.isFixed;
    final bool isActuallyVerified = res.voteCount >= 3;

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
                    Image.asset(
                      res.iconPath,
                      width: 40,
                      height: 40,
                      errorBuilder: (c, e, s) =>
                      const Icon(Icons.pets, color: Colors.orange),
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
                      label: Text("있어요! (${res.voteCount})"),
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

  Widget _buildFilterDrawer() {
    final fruitItems =
    _getDistinctNamesByCategory(['fruit', 'bubble', 'tree', 'material']);
    final mushroomItems = _getDistinctNamesByCategory(['mushroom']);
    final locationItems = _getDistinctNamesByCategory(['location']);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '필터',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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

                  const SizedBox(height: 24),

                  _buildSectionTitle('자원'),
                  const SizedBox(height: 8),
                  _buildSimpleExpansionSection(
                    title: '채집 자원',
                    items: fruitItems,
                    icon: Icons.spa_outlined,
                  ),
                  _buildSimpleExpansionSection(
                    title: '버섯 종류',
                    items: mushroomItems,
                    icon: Icons.park_outlined,
                  ),
                  _buildSimpleExpansionSection(
                    title: '주요 장소',
                    items: locationItems,
                    icon: Icons.place_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF94A3B8),
        letterSpacing: 0.3,
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

  Widget _buildSimpleExpansionSection({
    required String title,
    required List<String> items,
    required IconData icon,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(icon, size: 20, color: const Color(0xFF475569)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        iconColor: const Color(0xFF64748B),
        collapsedIconColor: const Color(0xFF64748B),
        children: [
          ...items.map(_buildFilterTile),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ],
      ),
    );
  }

  Widget _buildFilterTile(String resourceName) {
    final bool isEnabled = _enabledResources.contains(resourceName);

    final sampleRes = _resources.firstWhere(
          (r) => r.resourceName == resourceName,
      orElse: () => _resources.first,
    );

    return InkWell(
      onTap: () => _toggleResource(resourceName),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                sampleRes.iconPath,
                width: 18,
                height: 18,
                errorBuilder: (c, e, s) =>
                const Icon(Icons.circle, size: 10, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                sampleRes.koName,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isEnabled ? accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isEnabled ? accentColor : const Color(0xFFCBD5E1),
                ),
              ),
              child: isEnabled
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: seaColor,
      appBar: AppBar(
        title: const Text(
          "지도",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildFilterDrawer(),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.white),
      )
          : LayoutBuilder(
        builder: (context, constraints) {
          final double mapSize = constraints.maxWidth * 0.95;

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
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
                    ..._resources.where((res) {
                      if (res.category == 'npc') return _showAllNpcs;
                      if (res.category == 'animal') return _showAllAnimals;
                      return _enabledResources.contains(res.resourceName);
                    }).map(
                          (res) => Positioned(
                        left: (res.x * mapSize) - 14,
                        top: (res.y * mapSize) - 14,
                        child: GestureDetector(
                          onTap: () => _showResourceDetail(res),
                          behavior: HitTestBehavior.opaque,
                          child: Opacity(
                            opacity: res.isFixed || res.voteCount >= 3
                                ? 1.0
                                : 0.4,
                            child: Image.asset(
                              res.iconPath,
                              width: 28,
                              height: 28,
                            ),
                          ),
                        ),
                      ),
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
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/resource_model.dart';
import 'dart:ui';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<ResourceModel> _resources = [];
  bool _isLoading = true;

  // ★ 지도 테두리에서 추출하신 색상 적용
  final Color mapBaseColor = const Color(0xFF6CA0B3);

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      final data = await ApiService.getResources();
      setState(() {
        _resources = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("데이터 로딩 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. 앱바 뒤로 지도가 보이게 설정 (반투명 효과를 극대화)
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: const Text("지도",
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
          ),
          centerTitle: true,
          // 2. ★ 상단 바에 반투명한 흰색 배경 추가
          backgroundColor: Colors.white.withOpacity(0.8), // 40% 투명도
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
      ),
      backgroundColor: mapBaseColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : LayoutBuilder(
        builder: (context, constraints) {
          double mapSize = constraints.maxWidth * 0.92;

          return InteractiveViewer(
            clipBehavior: Clip.none,
            minScale: 1.0,
            maxScale: 5.0,
            boundaryMargin: EdgeInsets.zero,
            child: Center(
              child: Container(
                width: mapSize,
                height: mapSize,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/map_background.png',
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(color: mapBaseColor),
                        ),
                      ),
                    ),
                    ..._resources.map((res) => Positioned(
                      left: (res.x * mapSize) - 15,
                      top: (res.y * mapSize) - 15,
                      child: GestureDetector(
                        onTap: () => _showDetail(res),
                        child: Image.asset(
                          res.iconPath,
                          width: 30,
                          height: 30,
                          errorBuilder: (c, e, s) =>
                          const Icon(Icons.location_on, color: Colors.red, size: 30),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDetail(ResourceModel res) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(res.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(res.displayInfo ?? "정보 없음", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: mapBaseColor),
                onPressed: () => Navigator.pop(context),
                child: const Text("닫기", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
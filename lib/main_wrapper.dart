import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'home_screen.dart';
import 'encyclopedia_screen.dart';
import 'cooking_screen.dart';
import 'gathering_screen.dart';
import 'pet_screen.dart';
import 'setting_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _todoController = TextEditingController();

  // --- 유저 및 투두 데이터 ---
  String _userName = "로그인 중...";
  String _userUid = "";
  String? _profileImageUrl;
  String? _headerImageUrl;

  // 기본 투두 리스트 (서버 로드 전 초기값)
  List<Map<String, dynamic>> _todoTasks = [
    {"id": 0, "taskName": "가게 판매 품목 확인", "completed": false, "isSystem": true},
    {"id": 0, "taskName": "그자리 참나무 파밍", "completed": false, "isSystem": true},
    {"id": 0, "taskName": "완벽한 형광석 채집", "completed": false, "isSystem": true},
    {"id": 0, "taskName": "작물에 물 주기", "completed": false, "isSystem": true},
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  // --- [로직] 유저 정보 가져오기 ---
  Future<void> _fetchUserInfo() async {
    try {
      User user = await UserApi.instance.me();
      final String kakaoId = user.id.toString();

      // 1. 서버에 저장된 최신 정보 먼저 가져오기
      final response = await http.post(
        Uri.parse('http://161.33.30.40:8080/api/user/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "kakaoId": user.id,
          "nickname": user.kakaoAccount?.profile?.nickname ?? "사용자"
        }),
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _userUid = data['gameUid'] ?? kakaoId;
          _userName = data['nickname'] ?? "사용자";

          if (data['profileImageUrl'] != null) {
            _profileImageUrl =
            "http://161.33.30.40:8080${data['profileImageUrl']}?t=${DateTime.now().millisecondsSinceEpoch}";
          } else {
            _profileImageUrl = user.kakaoAccount?.profile?.thumbnailImageUrl;
          }

          if (data['headerImageUrl'] != null) {
            _headerImageUrl =
            "http://161.33.30.40:8080${data['headerImageUrl']}?t=${DateTime.now().millisecondsSinceEpoch}";
          } else {
            _headerImageUrl = null;
          }
        });
      }

      _loadTodoFromServer(kakaoId);
    } catch (e) {
      debugPrint("메인 유저 정보 갱신 에러: $e");
    }
  }

  // --- [API] 할 일 불러오기 ---
  Future<void> _loadTodoFromServer([String? uid]) async {
    final targetUid = uid ?? _userUid;
    if (targetUid.isEmpty || targetUid == "UID를 입력해보세요") return;

    try {
      final response = await http.get(
        Uri.parse('http://161.33.30.40:8080/api/todo/$targetUid'),
      );

      if (response.statusCode == 200) {
        // ★ 1. JSON 디코딩
        final List<dynamic> decodedData = jsonDecode(utf8.decode(response.bodyBytes));

        if (decodedData.isEmpty) {
          debugPrint("신규 유저: 기본 투두 생성 중...");
          final defaultTasks = ["가게 판매 품목 확인", "그자리 참나무 파밍", "완벽한 형광석 채집", "작물에 물 주기"];
          for (var taskName in defaultTasks) {
            await http.post(
              Uri.parse('http://161.33.30.40:8080/api/todo/add'),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"kakaoId": targetUid, "taskName": taskName}),
            );
          }
          _loadTodoFromServer(targetUid);
        } else {
          // ★ 2. 데이터 매핑 (BIT 타입 0x01 대응 포함)
          setState(() {
            _todoTasks = decodedData.map((task) => {
              "id": task['id'],
              "taskName": task['taskName'],
              "completed": (task['completed'] == true ||
                  task['completed'] == 1 ||
                  task['completed'].toString().contains('1')) ||
                  (task['isCompleted'] == true ||
                      task['isCompleted'] == 1 ||
                      task['isCompleted'].toString().contains('1')),
              "isSystem": task['isSystem'] ?? false
            }).toList();
          });
          debugPrint("서버 동기화 완료");
        }
      }
    } catch (e) {
      debugPrint("로드 에러: $e");
    }
  }

  // --- [API] 할 일 체크 토글 ---
  void _toggleTodo(int index) async {
    final taskId = _todoTasks[index]['id'];
    if (taskId == 0) return;

    setState(() {
      _todoTasks[index]['completed'] = !_todoTasks[index]['completed'];
    });

    try {
      await http.put(
        Uri.parse('http://161.33.30.40:8080/api/todo/toggle/$taskId'),
      );
    } catch (e) {
      debugPrint("토글 동기화 실패: $e");
    }
  }

  void _showImageViewer({
    required ImageProvider imageProvider,
    required bool isProfile,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'image_viewer',
      barrierColor: Colors.black.withOpacity(0.9),
      pageBuilder: (context, animation, secondaryAnimation) {
        final size = MediaQuery.of(context).size;

        return SafeArea(
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: size.width,
                  height: size.height,
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: isProfile
                      ? Hero(
                    tag: 'drawer_profile_image',
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          width: size.width * 0.72,
                          height: size.width * 0.72,
                          child: Image(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  )
                      : InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: size.width * 0.92,
                        child: Image(
                          image: imageProvider,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.black.withOpacity(0.35),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  // --- [API] 할 일 추가 ---
  void _addTodo() async {
    if (_todoController.text.trim().isEmpty) return;
    final taskName = _todoController.text.trim();

    try {
      final response = await http.post(
        Uri.parse('http://161.33.30.40:8080/api/todo/add'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"kakaoId": _userUid, "taskName": taskName}),
      );

      if (response.statusCode == 200) {
        _todoController.clear();
        _loadTodoFromServer();
      }
    } catch (e) {
      debugPrint("추가 실패: $e");
    }
  }

  // --- [API] 할 일 삭제 ---
  void _deleteTodo(int index) async {
    final taskId = _todoTasks[index]['id'];
    if (taskId == 0) return;

    try {
      final response = await http.delete(
        Uri.parse('http://161.33.30.40:8080/api/todo/$taskId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _todoTasks.removeAt(index);
        });
      }
    } catch (e) {
      debugPrint("삭제 실패: $e");
    }
  }

  void _handleSixAMReset() async {
    await _loadTodoFromServer();
  }

  Future<void> _onRefreshData() async {
    await _loadTodoFromServer();
  }

  void _onMenuSelect(int index) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.pop(context);
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // ★ 기기 하단 바 높이 계산
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    final List<Widget> pages = [
      HomeScreen(
        openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        openEndDrawer: () => _scaffoldKey.currentState?.openEndDrawer(),
        todoList: _todoTasks,
        onTodoToggle: (index) => _toggleTodo(index),
        onResetAll: _handleSixAMReset,
        onRefresh: _onRefreshData,
      ),
      EncyclopediaScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
      CookingScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
      GatheringScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
      PetScreen(openDrawer: () => _scaffoldKey.currentState?.openDrawer()),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
        } else if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeEndDrawer();
        } else {
          if (_selectedIndex != 0) {
            setState(() => _selectedIndex = 0);
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        extendBody: true,
        drawer: _buildCommonDrawer(bottomPadding),
        endDrawer: _buildTodoDrawer(),
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: _buildBottomNavigationBar(bottomPadding),
      ),
    );
  }

  // --- [UI] 투두 드로워 ---
  Widget _buildTodoDrawer() {
    int doneCount = _todoTasks.where((t) => t['completed'] == true).length;
    double progress = _todoTasks.isEmpty ? 0 : doneCount / _todoTasks.length;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(30), bottomLeft: Radius.circular(30))),
      child: Container(
        color: const Color(0xFFF9F9F9),
        child: SafeArea(
          child: Column(
            children: [
              _buildTodoHeader(progress),
              Expanded(child: _buildTodoListArea()),
              _buildTodoInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodoHeader(double progress) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("오늘의 할 일 🌿", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'SF Pro')),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          const Text("오전 06:00에 모든 항목이 초기화됩니다.", style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE0E0E0),
              color: const Color(0xFFFF8E7C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoListArea() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _todoTasks.length,
      itemBuilder: (context, index) {
        return _buildTodoTile(_todoTasks[index], index);
      },
    );
  }

  Widget _buildTodoTile(Map<String, dynamic> todo, int index) {
    bool isDone = todo['completed'];
    return GestureDetector(
      onTap: () => _toggleTodo(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(isDone ? Icons.check_circle : Icons.circle_outlined, color: isDone ? const Color(0xFFFF8E7C) : Colors.grey[300], size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IntrinsicWidth(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Text(todo['taskName'], style: TextStyle(fontSize: 14, fontFamily: 'SF Pro', color: isDone ? Colors.grey.withOpacity(0.6) : Colors.black87)),
                        if (isDone)
                          Positioned(
                            left: 0, right: 0,
                            child: Container(height: 1.2, color: Colors.grey.withOpacity(0.5)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (todo['isSystem'] == false)
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () => _deleteTodo(index),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodoInputArea() {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _todoController,
              onSubmitted: (_) => _addTodo(),
              decoration: InputDecoration(
                hintText: "오늘 뭐 할까요?",
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                filled: true, fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(onTap: _addTodo, child: const CircleAvatar(backgroundColor: Color(0xFFFF8E7C), child: Icon(Icons.add, color: Colors.white))),
        ],
      ),
    );
  }

  // --- [UI] 공통 드로워 ---
  Widget _buildCommonDrawer(double bottomPadding) {
    return Drawer(
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final ImageProvider provider = _headerImageUrl != null
                      ? NetworkImage(_headerImageUrl!)
                      : const AssetImage('assets/images/profile_header_bg.png');

                  _showImageViewer(
                    imageProvider: provider,
                    isProfile: false,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(left: 20, top: 40, bottom: 20),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: _headerImageUrl != null
                          ? NetworkImage(_headerImageUrl!)
                          : const AssetImage('assets/images/profile_header_bg.png')
                      as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final ImageProvider provider = _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : const AssetImage('assets/images/profile.png');

                          _showImageViewer(
                            imageProvider: provider,
                            isProfile: true,
                          );
                        },
                        child: Hero(
                          tag: 'drawer_profile_image',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              image: DecorationImage(
                                image: _profileImageUrl != null
                                    ? NetworkImage(_profileImageUrl!) as ImageProvider
                                    : const AssetImage('assets/images/profile.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "$_userName 님",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                      Text(
                        "UID: $_userUid",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );

                    _fetchUserInfo();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          _buildDrawerItem(Icons.home_rounded, '홈', () => _onMenuSelect(0)),
          _buildDrawerItem(Icons.auto_stories_rounded, '아이템 도감', () => _onMenuSelect(1)),
          _buildDrawerItem(Icons.restaurant_menu_rounded, '요리 레시피', () => _onMenuSelect(2)),
          _buildDrawerItem(Icons.backpack_rounded, '채집 도감', () => _onMenuSelect(3)),
          _buildDrawerItem(Icons.pets_rounded, '동물 도감', () => _onMenuSelect(4)),
          const Spacer(),
          const Divider(height: 1),
          _buildDrawerItem(Icons.settings_rounded, '설정', () async {
            Navigator.pop(context);

            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );

            _fetchUserInfo();
          }),
          SizedBox(height: bottomPadding > 0 ? bottomPadding : 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF636363), size: 22),
      title: Text(title, style: const TextStyle(color: Color(0xFF636363), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'SF Pro')),
      onTap: onTap,
    );
  }

  // --- [UI] 하단 내비게이션 바 ---
  Widget _buildBottomNavigationBar(double bottomPadding) {
    return Container(
      width: double.infinity,
      // 시스템 바 높이 반영하여 전체 높이 조절
      height: bottomPadding > 0 ? 85 + bottomPadding : 85,
      padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 10),
      decoration: const ShapeDecoration(color: Color(0xEAFFFDF9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))), shadows: [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -5))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, 'home', '홈'),
          _buildNavItem(1, 'book', '도감'),
          _buildNavItem(2, 'cook', '요리'),
          _buildNavItem(3, 'fish', '채집'),
          _buildNavItem(4, 'pet', '동물'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String fileName, String label) {
    bool isSelected = _selectedIndex == index;
    String assetPath = isSelected ? 'assets/icons/ic_${fileName}_active.svg' : 'assets/icons/ic_$fileName.svg';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(40), border: isSelected ? Border.all(color: Colors.black.withOpacity(0.1), width: 0.8) : null),
        child: Column(
          mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(assetPath, width: 24, height: 24, colorFilter: isSelected ? null : const ColorFilter.mode(Colors.black38, BlendMode.srcIn)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.black : Colors.black38, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontFamily: 'SF Pro')),
          ],
        ),
      ),
    );
  }
}
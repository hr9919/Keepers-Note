import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'encyclopedia_screen.dart';
import 'cooking_screen.dart';
import 'gathering_screen.dart';
import 'pet_screen.dart';
import 'setting_screen.dart';
import 'models/global_search_item.dart';
import 'event_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  int _searchResetSignal = 0;
  final TextEditingController _todoController = TextEditingController();

  bool _isScrimPressed = false;
  bool _isDrawerOpen = false;
  bool _isEndDrawerOpen = false;
  bool _isAdmin = false;

  String _userName = "로그인 중...";
  String _userUid = "";
  String? _profileImageUrl;
  String? _headerImageUrl;
  String _kakaoId = "";

  GlobalSearchItem? _pendingSearchItem;

  List<Map<String, dynamic>> _todoTasks = [
    {"id": 0, "taskName": "가게 판매 품목 확인", "completed": false, "isSystem": true},
    {"id": 0, "taskName": "그자리 참나무 파밍", "completed": false, "isSystem": true},
    {"id": 0, "taskName": "완벽한 형광석 채집", "completed": false, "isSystem": true},
    {"id": 0, "taskName": "작물에 물 주기", "completed": false, "isSystem": true},
  ];

  static const List<String> _defaultSystemTasks = [
    "가게 판매 품목 확인",
    "그자리 참나무 파밍",
    "완벽한 형광석 채집",
    "작물에 물 주기",
  ];

  static const Duration _kPanelDuration = Duration(milliseconds: 360);
  static const Curve _kPanelCurve = Curves.easeOutCubic;

  String _normalizeTaskName(String name) {
    return name.replaceAll('\n', '').replaceAll('\r', '').trim();
  }

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  @override
  void dispose() {
    _todoController.dispose();
    super.dispose();
  }

  Future<void> _openDrawerSmooth() async {
    if (_isEndDrawerOpen) {
      setState(() => _isEndDrawerOpen = false);
      await Future.delayed(_kPanelDuration);
    }
    if (!mounted) return;
    setState(() => _isDrawerOpen = true);
  }

  Future<void> _openEndDrawerSmooth() async {
    if (_isDrawerOpen) {
      setState(() => _isDrawerOpen = false);
      await Future.delayed(_kPanelDuration);
    }
    if (!mounted) return;
    setState(() => _isEndDrawerOpen = true);
  }

  Future<void> _closeDrawerSmooth() async {
    if (!_isDrawerOpen) return;
    setState(() => _isDrawerOpen = false);
    await Future.delayed(_kPanelDuration);
  }

  Future<void> _closeEndDrawerSmooth() async {
    if (!_isEndDrawerOpen) return;
    setState(() => _isEndDrawerOpen = false);
    await Future.delayed(_kPanelDuration);
  }

  Future<void> _fetchUserInfo() async {
    try {
      User user = await UserApi.instance.me();
      final String kakaoId = user.id.toString();

      if (!mounted) return;
      setState(() {
        _kakaoId = kakaoId;
      });

      final response = await http.post(
        Uri.parse('http://161.33.30.40:8080/api/user/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "kakaoId": user.id,
          "nickname": user.kakaoAccount?.profile?.nickname ?? "사용자",
        }),
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _userUid = data['gameUid'] ?? kakaoId;
          _userName = data['nickname'] ?? "사용자";
          _isAdmin = data['isAdmin'] ?? false;

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
      } else {
        if (!mounted) return;
        setState(() {
          _userUid = kakaoId;
        });
      }

      await _loadTodoFromServer(kakaoId);
    } catch (e) {
      debugPrint("_fetchUserInfo 실패: $e");
    }
  }

  Future<void> _loadTodoFromServer([String? uid]) async {
    final targetUid = uid ?? _kakaoId;
    if (targetUid.isEmpty || targetUid == "UID를 입력해보세요") return;

    try {
      final response = await http.get(
        Uri.parse('http://161.33.30.40:8080/api/todo/$targetUid'),
      );

      if (response.statusCode != 200) return;

      final List<dynamic> decodedData = jsonDecode(utf8.decode(response.bodyBytes));

      List<Map<String, dynamic>> mapped = decodedData.map((task) {
        return {
          "id": task['id'],
          "taskName": task['taskName'],
          "completed": (task['completed'] == true ||
              task['completed'] == 1 ||
              task['completed'].toString().contains('1')) ||
              (task['isCompleted'] == true ||
                  task['isCompleted'] == 1 ||
                  task['isCompleted'].toString().contains('1')),
          "isSystem": (task['isSystem'] == true ||
              task['isSystem'] == 1 ||
              task['isSystem'].toString().contains('1')),
        };
      }).toList();

      if (mapped.isEmpty) {
        for (final taskName in _defaultSystemTasks) {
          await http.post(
            Uri.parse('http://161.33.30.40:8080/api/todo/add'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "kakaoId": targetUid,
              "taskName": taskName,
            }),
          );
        }
        await _loadTodoFromServer(targetUid);
        return;
      }

      final existingNames =
      mapped.map((e) => _normalizeTaskName(e["taskName"] ?? "")).toSet();

      bool addedMissingDefault = false;

      for (final taskName in _defaultSystemTasks) {
        if (!existingNames.contains(_normalizeTaskName(taskName))) {
          addedMissingDefault = true;
          await http.post(
            Uri.parse('http://161.33.30.40:8080/api/todo/add'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "kakaoId": targetUid,
              "taskName": taskName,
            }),
          );
        }
      }

      if (addedMissingDefault) {
        await _loadTodoFromServer(targetUid);
        return;
      }

      mapped.sort((a, b) {
        final aName = (a["taskName"] ?? "").toString();
        final bName = (b["taskName"] ?? "").toString();

        final aIndex = _defaultSystemTasks.indexOf(aName);
        final bIndex = _defaultSystemTasks.indexOf(bName);

        final aIsDefault = aIndex != -1;
        final bIsDefault = bIndex != -1;

        if (aIsDefault && bIsDefault) return aIndex.compareTo(bIndex);
        if (aIsDefault) return -1;
        if (bIsDefault) return 1;
        return 0;
      });

      if (!mounted) return;
      setState(() {
        _todoTasks = mapped;
      });
    } catch (_) {}
  }

  void _toggleTodo(int index) async {
    final taskId = _todoTasks[index]['id'];
    if (taskId == 0) return;

    final previous = _todoTasks[index]['completed'];

    setState(() {
      _todoTasks[index]['completed'] = !previous;
    });

    try {
      final response = await http.put(
        Uri.parse('http://161.33.30.40:8080/api/todo/toggle/$taskId'),
      );

      if (response.statusCode != 200 && mounted) {
        setState(() {
          _todoTasks[index]['completed'] = previous;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _todoTasks[index]['completed'] = previous;
        });
      }
      debugPrint("_toggleTodo 실패: $e");
    }
  }

  void _addTodo() async {
    final taskName = _todoController.text
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .trim();

    if (taskName.isEmpty) return;

    if (_kakaoId.isEmpty) {
      await _fetchUserInfo();
    }

    if (_kakaoId.isEmpty) {
      debugPrint("할 일 추가 실패: _kakaoId 비어 있음");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://161.33.30.40:8080/api/todo/add'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "kakaoId": _kakaoId,
          "taskName": taskName,
        }),
      );

      debugPrint("할 일 추가 응답: ${response.statusCode} / ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        _todoController.clear();
        await _loadTodoFromServer(_kakaoId);
      }
    } catch (e) {
      debugPrint("_addTodo 실패: $e");
    }
  }

  void _deleteTodo(int index) async {
    final taskId = _todoTasks[index]['id'];
    if (taskId == 0) return;

    try {
      final response = await http.delete(
        Uri.parse('http://161.33.30.40:8080/api/todo/$taskId'),
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _todoTasks.removeAt(index);
        });
      }
    } catch (_) {}
  }

  void _handleSixAMReset() async {
    await _loadTodoFromServer();
  }

  Future<void> _onRefreshData() async {
    await _loadTodoFromServer();
  }

  Future<void> _onMenuSelect(int index) async {
    if (_isDrawerOpen) {
      await _closeDrawerSmooth();
    }

    if (_isEndDrawerOpen) {
      await _closeEndDrawerSmooth();
    }

    if (!mounted) return;

    setState(() {
      _selectedIndex = index;
      _pendingSearchItem = null;
      _searchResetSignal++;
    });
  }

  void _handleGlobalSearchSelection(GlobalSearchItem item) {
    setState(() {
      _pendingSearchItem = item;
    });

    switch (item.screen) {
      case SearchTargetScreen.encyclopedia:
        _selectedIndex = 1;
        break;
      case SearchTargetScreen.cooking:
        _selectedIndex = 2;
        break;
      case SearchTargetScreen.gathering:
        _selectedIndex = 3;
        break;
      case SearchTargetScreen.pet:
        _selectedIndex = 4;
        break;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _pendingSearchItem = null;
      });
    });
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
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '앱 종료',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '키퍼노트를 종료하시겠습니까?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFD7DEE7)),
                          minimumSize: const Size.fromHeight(40),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8E7C),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(40),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '종료',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    final List<Widget> pages = [
      HomeScreen(
        openDrawer: _openDrawerSmooth,
        openEndDrawer: _openEndDrawerSmooth,
        todoList: _todoTasks,
        onTodoToggle: (index) => _toggleTodo(index),
        onResetAll: _handleSixAMReset,
        onRefresh: _onRefreshData,
        onSearchItemSelected: _handleGlobalSearchSelection,
      ),
      EncyclopediaScreen(
        openDrawer: _openDrawerSmooth,
        initialSearchItem: _pendingSearchItem,
      ),
      CookingScreen(
        openDrawer: _openDrawerSmooth,
        initialSearchItem: _pendingSearchItem,
        resetSearchSignal: _searchResetSignal,
      ),
      GatheringScreen(
        openDrawer: _openDrawerSmooth,
        initialSearchItem: _pendingSearchItem,
        resetSearchSignal: _searchResetSignal,
      ),
      PetScreen(
        openDrawer: _openDrawerSmooth,
        initialSearchItem: _pendingSearchItem,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_isDrawerOpen) {
          await _closeDrawerSmooth();
          return;
        }

        if (_isEndDrawerOpen) {
          await _closeEndDrawerSmooth();
          return;
        }

        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
            _pendingSearchItem = null;
            _searchResetSignal++;
          });
          return;
        }

        final shouldExit = await _showExitConfirmationDialog(context);
        if (!mounted) return;

        if (shouldExit) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: pages,
            ),

            AnimatedPositioned(
              duration: _kPanelDuration,
              curve: _kPanelCurve,
              left: 0,
              right: 0,
              bottom: (_isDrawerOpen || _isEndDrawerOpen) ? -140 : 0,
              child: IgnorePointer(
                ignoring: _isDrawerOpen || _isEndDrawerOpen,
                child: AnimatedOpacity(
                  duration: _kPanelDuration,
                  curve: _kPanelCurve,
                  opacity: (_isDrawerOpen || _isEndDrawerOpen) ? 0.0 : 1.0,
                  child: _buildBottomNavigationBar(bottomPadding),
                ),
              ),
            ),

            // 바깥 배경
            IgnorePointer(
              ignoring: !(_isDrawerOpen || _isEndDrawerOpen),
              child: AnimatedOpacity(
                duration: _kPanelDuration,
                curve: _kPanelCurve,
                opacity: (_isDrawerOpen || _isEndDrawerOpen) ? 1.0 : 0.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    setState(() {
                      _isScrimPressed = true;
                    });
                  },
                  onTapCancel: () {
                    setState(() {
                      _isScrimPressed = false;
                    });
                  },
                  onTapUp: (_) async {
                    await Future.delayed(const Duration(milliseconds: 70));
                    if (!mounted) return;

                    setState(() {
                      _isScrimPressed = false;
                    });

                    if (_isDrawerOpen) {
                      await _closeDrawerSmooth();
                    } else if (_isEndDrawerOpen) {
                      await _closeEndDrawerSmooth();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    color: _isScrimPressed
                        ? Colors.black.withOpacity(0.28)
                        : Colors.black.withOpacity(0.22),
                  ),
                ),
              ),
            ),

            _buildCustomLeftPanel(bottomPadding),
            _buildCustomRightPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomLeftPanel(double bottomPadding) {
    final double panelWidth = MediaQuery.of(context).size.width * 0.82;

    return AnimatedPositioned(
      duration: _kPanelDuration,
      curve: _kPanelCurve,
      left: _isDrawerOpen ? 0 : -panelWidth - 24,
      top: 0,
      bottom: 0,
      child: AnimatedScale(
        duration: _kPanelDuration,
        curve: _kPanelCurve,
        scale: _isDrawerOpen ? 1.0 : 0.985,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: panelWidth,
          child: _buildCommonDrawerPanel(bottomPadding),
        ),
      ),
    );
  }

  Widget _buildCustomRightPanel() {
    final double panelWidth = MediaQuery.of(context).size.width * 0.85;

    return AnimatedPositioned(
      duration: _kPanelDuration,
      curve: _kPanelCurve,
      right: _isEndDrawerOpen ? 0 : -panelWidth - 24,
      top: 0,
      bottom: 0,
      child: AnimatedScale(
        duration: _kPanelDuration,
        curve: _kPanelCurve,
        scale: _isEndDrawerOpen ? 1.0 : 0.985,
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: panelWidth,
          child: _buildTodoDrawerPanel(),
        ),
      ),
    );
  }

  Widget _buildTodoDrawerPanel() {
    int doneCount = _todoTasks.where((t) => t['completed'] == true).length;
    double progress = _todoTasks.isEmpty ? 0 : doneCount / _todoTasks.length;

    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Color(0xFFF9F9F9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                bottomLeft: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 28,
                  offset: Offset(-6, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildTodoHeader(progress),
                Expanded(child: _buildTodoListArea()),
                _buildTodoInputArea(),
              ],
            ),
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
              const Text(
                "오늘의 할 일 🌿",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SF Pro',
                ),
              ),
              IconButton(
                onPressed: () async {
                  await _closeEndDrawerSmooth();
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "오전 06:00에 모든 항목이 초기화됩니다.",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
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

    final String displayTaskName = (todo['taskName'] ?? '')
        .toString()
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .trim();

    final bool isDefaultTask = [
      "가게 판매 품목 확인",
      "그자리 참나무 파밍",
      "완벽한 형광석 채집",
      "작물에 물 주기",
    ].contains(displayTaskName);

    return GestureDetector(
      onTap: () => _toggleTodo(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.circle_outlined,
                color: isDone ? const Color(0xFFFF8E7C) : Colors.grey[300],
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayTaskName,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'SF Pro',
                    color: isDone
                        ? Colors.grey.withOpacity(0.6)
                        : Colors.black87,
                    decoration:
                    isDone ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationColor: Colors.grey.withOpacity(0.5),
                    decorationThickness: 1.2,
                    height: 1.35,
                  ),
                ),
              ),
              SizedBox(
                width: 22,
                height: 22,
                child: (todo['isSystem'] != true && !isDefaultTask)
                    ? GestureDetector(
                  onTap: () => _deleteTodo(index),
                  behavior: HitTestBehavior.opaque,
                  child: const Center(
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodoInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _todoController,
              onSubmitted: (_) => _addTodo(),
              decoration: InputDecoration(
                hintText: "오늘 뭐 할까요?",
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _addTodo,
            child: const CircleAvatar(
              backgroundColor: Color(0xFFFF8E7C),
              child: Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonDrawerPanel(double bottomPadding) {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 24,
                offset: Offset(4, 0),
              ),
            ],
          ),
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
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(28),
                        ),
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
                        await _closeDrawerSmooth();
                        if (!mounted) return;

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
              _buildDrawerItem(Icons.celebration_rounded, '이벤트', () async {
                await _closeDrawerSmooth();
                if (!mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventScreen(
                      isAdmin: _isAdmin,
                    ),
                  ),
                );
              }),
              const Spacer(),
              const Divider(height: 1),
              _buildDrawerItem(Icons.settings_rounded, '설정', () async {
                await _closeDrawerSmooth();
                if (!mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );

                _fetchUserInfo();
              }),
              SizedBox(height: bottomPadding > 0 ? bottomPadding : 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF636363), size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF636363),
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: 'SF Pro',
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildBottomNavigationBar(double bottomPadding) {
    return Container(
      width: double.infinity,
      height: bottomPadding > 0 ? 85 + bottomPadding : 85,
      padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 10),
      decoration: const ShapeDecoration(
        color: Color(0xEAFFFDF9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        shadows: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
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
    String assetPath = isSelected
        ? 'assets/icons/ic_${fileName}_active.svg'
        : 'assets/icons/ic_$fileName.svg';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _selectedIndex = index;
        _pendingSearchItem = null;
        _searchResetSignal++;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(40),
          border: isSelected
              ? Border.all(
            color: Colors.black.withOpacity(0.1),
            width: 0.8,
          )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              assetPath,
              width: 24,
              height: 24,
              colorFilter: isSelected
                  ? null
                  : const ColorFilter.mode(Colors.black38, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.black : Colors.black38,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'SF Pro',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
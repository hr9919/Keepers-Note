import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'weather_admin_screen.dart';
import 'encyclopedia_screen.dart';
import 'cooking_screen.dart';
import 'gathering_screen.dart';
import 'pet_screen.dart';
import 'setting_screen.dart';
import 'models/global_search_item.dart';
import 'event_screen.dart';
import 'models/event_item.dart';
import 'services/event_api_service.dart';


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

  List<EventItem> _eventList = [];

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
    _loadEvents();
  }

  @override
  void dispose() {
    _todoController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await EventApiService.fetchActiveEvents();

      if (!mounted) return;
      setState(() {
        _eventList = events;
      });

      debugPrint('MainWrapper events loaded: ${events.length}');
    } catch (e) {
      debugPrint('이벤트 불러오기 실패: $e');
    }
  }

  Future<void> _openWeatherAdminScreen() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_isDrawerOpen) {
      await _closeDrawerSmooth();
    }

    if (_isEndDrawerOpen) {
      await _closeEndDrawerSmooth();
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WeatherAdminScreen(),
      ),
    );
  }

  Future<void> _openDrawerSmooth() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isEndDrawerOpen) {
      setState(() => _isEndDrawerOpen = false);
      await Future.delayed(_kPanelDuration);
    }
    if (!mounted) return;
    setState(() => _isDrawerOpen = true);
  }

  Future<void> _openEndDrawerSmooth() async {
    FocusManager.instance.primaryFocus?.unfocus();
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
        FocusManager.instance.primaryFocus?.unfocus(); // 키보드 닫기
        _todoController.clear(); // 입력값 비우기
        await _loadTodoFromServer(_kakaoId); // 목록 새로고침
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
    FocusManager.instance.primaryFocus?.unfocus();
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
              // 🔥 배경 (터치 시 닫힘)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: size.width,
                  height: size.height,
                  color: Colors.black.withOpacity(0.9),
                ),
              ),

              // 🔥 이미지 영역 (터치 이벤트 막기)
              Center(
                child: GestureDetector(
                  onTap: () {}, // 👉 이벤트 막기 (닫힘 방지)
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
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  Future<void> _openEventScreen() async {
    if (_isDrawerOpen) {
      await _closeDrawerSmooth();
    }

    if (_isEndDrawerOpen) {
      await _closeEndDrawerSmooth();
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventScreen(
          isAdmin: false,
          canManage: _isAdmin,
        ),
      )
    );

    await _loadEvents();
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
        openEventScreen: _openEventScreen,
        todoList: _todoTasks,
        onTodoToggle: (index) => _toggleTodo(index),
        onResetAll: _handleSixAMReset,
        onRefresh: () async {
          await _onRefreshData();
          await _loadEvents();
        },
        onSearchItemSelected: _handleGlobalSearchSelection,
        eventList: _eventList,
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

        FocusManager.instance.primaryFocus?.unfocus();

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
        resizeToAvoidBottomInset: false,
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
                    FocusManager.instance.primaryFocus?.unfocus();

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
    final int doneCount = _todoTasks.where((t) => t['completed'] == true).length;
    final int totalCount = _todoTasks.length;
    final double progress = totalCount == 0 ? 0 : doneCount / totalCount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBFA),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(34),
                  bottomLeft: Radius.circular(34),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 30,
                    offset: const Offset(-8, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTodoHeader(progress, doneCount, totalCount),
                  const SizedBox(height: 4),
                  Expanded(
                    child: _buildTodoListArea(),
                  ),
                  _buildTodoInputArea(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodoHeader(double progress, int doneCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF8E7C).withOpacity(0.08),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    '📝',
                    style: TextStyle(fontSize: 19),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의 할 일',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '오늘의 할 일을 놓치지 말고 체크하세요!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8),
                        height: 1.2,
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
                  onTap: () async {
                    await _closeEndDrawerSmooth();
                  },
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: const Color(0xFFFF8E7C),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$doneCount / $totalCount',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF8E7C),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '오전 06:00에 모든 항목이 초기화돼요.',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoListArea() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      physics: const BouncingScrollPhysics(),
      itemCount: _todoTasks.length,
      itemBuilder: (context, index) {
        return _buildTodoTile(_todoTasks[index], index);
      },
    );
  }

  Widget _buildTodoTile(Map<String, dynamic> todo, int index) {
    final bool isDone = todo['completed'] == true;

    final String displayTaskName = (todo['taskName'] ?? '')
        .toString()
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .trim();

    final bool isDefaultTask = const [
      "가게 판매 품목 확인",
      "그자리 참나무 파밍",
      "완벽한 형광석 채집",
      "작물에 물 주기",
    ].contains(displayTaskName);

    const TextStyle todoTextStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.35,
      color: Color(0xFF1E293B),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _toggleTodo(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFFFFF8F6)
                  : Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDone
                    ? const Color(0xFFFFD8D0)
                    : const Color(0xFFF1F5F9),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFFFF8E7C)
                        : const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFFFF8E7C)
                          : const Color(0xFFD9E2EC),
                      width: 1.4,
                    ),
                  ),
                  child: isDone
                      ? const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  )
                      : null,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final textWidth = _measureTodoTextWidth(
                        text: displayTaskName,
                        style: todoTextStyle,
                        maxWidth: constraints.maxWidth,
                      );

                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Text(
                            displayTaskName,
                            softWrap: true,
                            strutStyle: const StrutStyle(
                              forceStrutHeight: true,
                              fontSize: 14.5,
                              height: 1.35,
                            ),
                            style: todoTextStyle.copyWith(
                              color: isDone
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          if (isDone)
                            IgnorePointer(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Transform.translate(
                                  offset: const Offset(0, 0.5),
                                  child: Container(
                                    width: textWidth,
                                    height: 1.0,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF94A3B8).withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: (todo['isSystem'] != true && !isDefaultTask)
                      ? Material(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _deleteTodo(index),
                      child: const Center(
                        child: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _measureTodoTextWidth({
    required String text,
    required TextStyle style,
    required double maxWidth,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    return textPainter.size.width;
  }

  Widget _buildTodoInputArea() {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double systemBottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: keyboardHeight > 0
            ? keyboardHeight + 12
            : (systemBottomPadding > 0 ? 12 : 16),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFFF8E7C).withOpacity(0.08),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFEAEFF5),
                ),
              ),
              child: TextField(
                controller: _todoController,
                onSubmitted: (_) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _addTodo();
                },
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
                decoration: InputDecoration(
                  hintText: "오늘 뭐 할까요?",
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      Icons.edit_note_rounded,
                      size: 20,
                      color: Color(0xFFFF8E7C),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: const Color(0xFFFF8E7C),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                _addTodo();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8E7C).withOpacity(0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonDrawerPanel(double bottomPadding) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 18, 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBFA),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(34),
                bottomRight: Radius.circular(34),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 30,
                  offset: const Offset(8, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildPrettyDrawerHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDrawerSectionLabel('메뉴'),
                        const SizedBox(height: 10),

                        _buildDrawerItem(
                          icon: Icons.home_rounded,
                          title: '홈',
                          subtitle: '오늘의 정보와 할 일을 확인해요',
                          isSelected: _selectedIndex == 0,
                          onTap: () => _onMenuSelect(0),
                        ),
                        _buildDrawerItem(
                          icon: Icons.collections_bookmark_rounded,
                          title: '도감',
                          subtitle: '아이템과 생물 정보를 둘러봐요',
                          isSelected: _selectedIndex == 1,
                          onTap: () => _onMenuSelect(1),
                        ),
                        _buildDrawerItem(
                          icon: Icons.soup_kitchen_rounded,
                          title: '요리',
                          subtitle: '레시피와 재료를 정리해요',
                          isSelected: _selectedIndex == 2,
                          onTap: () => _onMenuSelect(2),
                        ),
                        _buildDrawerItem(
                          icon: Icons.travel_explore_rounded,
                          title: '채집',
                          subtitle: '낚시, 곤충, 새, 원예를 모아봐요',
                          isSelected: _selectedIndex == 3,
                          onTap: () => _onMenuSelect(3),
                        ),
                        _buildDrawerItem(
                          icon: Icons.pets_rounded,
                          title: '동물',
                          subtitle: '간식 실험실과 동물 정보를 확인해요',
                          isSelected: _selectedIndex == 4,
                          onTap: () => _onMenuSelect(4),
                        ),

                        const SizedBox(height: 18),
                        _buildDrawerSectionLabel('기타'),
                        const SizedBox(height: 10),

                        if (_isAdmin)
                          _buildDrawerItem(
                            icon: Icons.cloud_rounded,
                            title: '날씨 관리',
                            subtitle: '주간 날씨를 수정해요 (관리자)',
                            isSelected: false,
                            onTap: () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              await _closeDrawerSmooth();

                              if (!mounted) return;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const WeatherAdminScreen(),
                                ),
                              );
                            },
                          ),

                        _buildDrawerItem(
                          icon: Icons.settings_rounded,
                          title: '설정',
                          subtitle: '프로필과 앱 설정을 관리해요',
                          isSelected: false,
                          onTap: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
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
                        ),

                        SizedBox(height: bottomPadding > 0 ? bottomPadding : 20),
                      ],
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

  Widget _buildPrettyDrawerHeader() {
    final ImageProvider headerProvider = _headerImageUrl != null
        ? NetworkImage(_headerImageUrl!)
        : const AssetImage('assets/images/profile_header_bg.png');

    final ImageProvider profileProvider = _profileImageUrl != null
        ? NetworkImage(_profileImageUrl!)
        : const AssetImage('assets/images/profile.png');

    final String displayUid = _userUid.isEmpty ? _kakaoId : _userUid;
    final bool hasUid = displayUid.isNotEmpty;

    return GestureDetector(
      onTap: () {
        _showImageViewer(
          imageProvider: headerProvider,
          isProfile: false,
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(34),
          ),
          image: DecorationImage(
            image: headerProvider,
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 18, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.12),
                Colors.black.withOpacity(0.30),
              ],
            ),
          ),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _showImageViewer(
                        imageProvider: profileProvider,
                        isProfile: true,
                      );
                    },
                    child: Hero(
                      tag: 'drawer_profile_image',
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          image: DecorationImage(
                            image: profileProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 42),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_userName 님',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: hasUid
                                  ? () async {
                                await Clipboard.setData(
                                  ClipboardData(text: displayUid),
                                );

                                if (!mounted) return;
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        18,
                                      ),
                                      backgroundColor: const Color(0xFF2B3440),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      duration: const Duration(seconds: 2),
                                      content: Row(
                                        children: const [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'UID가 복사되었어요',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                              }
                                  : null,
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(hasUid ? 0.18 : 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(
                                      hasUid ? 0.26 : 0.16,
                                    ),
                                  ),
                                  boxShadow: hasUid
                                      ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      hasUid
                                          ? Icons.badge_rounded
                                          : Icons.schedule_rounded,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.96),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        hasUid ? displayUid : 'UID 불러오는 중...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.8,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withOpacity(0.96),
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                    ),
                                    if (hasUid) ...[
                                      const SizedBox(width: 7),
                                      Icon(
                                        Icons.content_copy_rounded,
                                        size: 13,
                                        color: Colors.white.withOpacity(0.88),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasUid ? '즐거운 타운생활 되세요!' : 'UID를 불러오고 있어요',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () async {
                      FocusManager.instance.primaryFocus?.unfocus();
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
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: Colors.white,
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
  }

  Widget _buildDrawerSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFF4F1)
                  : Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFFD7CF)
                    : const Color(0xFFF1F5F9),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF8E7C)
                        : const Color(0xFFFFF1ED),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected
                        ? Colors.white
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
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? const Color(0xFFE56F5B)
                              : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFE4DE)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isSelected
                        ? const Color(0xFFFF8E7C)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(double bottomPadding) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        bottomPadding > 0 ? bottomPadding + 6 : 12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.55),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 22,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildNavItem(
                  index: 0,
                  label: '홈',
                  outlinedIcon: Icons.home_outlined,
                  filledIcon: Icons.home_rounded,
                ),
                _buildNavItem(
                  index: 1,
                  label: '도감',
                  outlinedIcon: Icons.collections_bookmark_outlined,
                  filledIcon: Icons.collections_bookmark_rounded,
                ),
                _buildNavItem(
                  index: 2,
                  label: '요리',
                  outlinedIcon: Icons.soup_kitchen_outlined,
                  filledIcon: Icons.soup_kitchen,
                ),
                _buildNavItem(
                  index: 3,
                  label: '채집',
                  outlinedIcon: Icons.travel_explore_outlined,
                  filledIcon: Icons.travel_explore,
                ),
                _buildNavItem(
                  index: 4,
                  label: '동물',
                  outlinedIcon: Icons.pets_outlined,
                  filledIcon: Icons.pets,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData outlinedIcon,
    required IconData filledIcon,
  }) {
    final bool isSelected = _selectedIndex == index;

    const Color selectedColor = Color(0xFFFF8E7C);
    const Color unselectedColor = Color(0xFF98A2B3);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await _onMenuSelect(index);
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 12 : 0,
              vertical: isSelected ? 8 : 0,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.92)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFFD8D2)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? filledIcon : outlinedIcon,
                  size: 23,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? selectedColor : unselectedColor,
                    fontFamily: 'SF Pro',
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
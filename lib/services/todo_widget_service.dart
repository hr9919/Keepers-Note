import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class TodoWidgetItem {
  final String id;
  final String title;
  final bool done;
  final double createdAt;

  const TodoWidgetItem({
    required this.id,
    required this.title,
    required this.done,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'done': done,
      'createdAt': createdAt,
    };
  }
}

class TodoWidgetService {
  static const String _iOSAppGroupId = 'group.com.townhelpers.keepersnote';
  static const String _iOSWidgetName = 'KeepersTodoWidget';

  static Future<void> _ensureInitialized() async {
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(_iOSAppGroupId);
    }
  }

  static Future<void> saveAndRefresh({
    required List<TodoWidgetItem> todos,
  }) async {
    await _ensureInitialized();

    final json = jsonEncode(
      todos.map((e) => e.toJson()).toList(),
    );

    debugPrint('🧩 TodoWidget save count=${todos.length}');
    debugPrint('🧩 TodoWidget save json=$json');

    await HomeWidget.saveWidgetData<String>(
      'keepers_todo_widget_data',
      json,
    );

    await HomeWidget.saveWidgetData<String>(
      'keepers_todo_updated_at',
      _nowLabel(),
    );

    await HomeWidget.saveWidgetData<int>(
      'keepers_todo_debug_count',
      todos.length,
    );

    await HomeWidget.updateWidget(
      name: _iOSWidgetName,
      iOSName: _iOSWidgetName,
    );
  }

  static String _nowLabel() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
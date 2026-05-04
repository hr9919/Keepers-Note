import 'dart:io';

import 'package:live_activities/live_activities.dart';

class CropTimerLiveActivityService {
  CropTimerLiveActivityService._();

  static final CropTimerLiveActivityService instance =
  CropTimerLiveActivityService._();

  static const String _appGroupId = 'group.com.townhelpers.keepersnote';

  final LiveActivities _liveActivities = LiveActivities();

  String? _activityId;

  Future<void> init() async {
    if (!Platform.isIOS) return;

    await _liveActivities.init(
      appGroupId: _appGroupId,
    );
  }

  Future<void> startCropTimer({
    required String timerId,
    required String cropId,
    required String cropName,
    required DateTime plantedAt,
    required DateTime harvestAt,
  }) async {
    if (!Platform.isIOS) return;

    await init();

    final activityId = await _liveActivities.createActivity(
      timerId,
      {
        'cropId': cropId,
        'cropName': cropName,
        'plantedAtMillis': plantedAt.millisecondsSinceEpoch,
        'harvestAtMillis': harvestAt.millisecondsSinceEpoch,
      },
    );

    _activityId = activityId;
  }

  Future<void> endCurrentActivity() async {
    if (!Platform.isIOS) return;

    await init();

    final id = _activityId;
    if (id == null || id.isEmpty) {
      return;
    }

    await _liveActivities.endActivity(id);

    _activityId = null;
  }

  Future<void> endAllActivities() async {
    if (!Platform.isIOS) return;

    await init();

    await _liveActivities.endAllActivities();

    _activityId = null;
  }
}
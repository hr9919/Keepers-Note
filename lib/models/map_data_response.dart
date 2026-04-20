import 'resource_model.dart';
import 'spawn_point_model.dart';

class MapDataResponse {
  final List<ResourceModel> fixedResources;
  final List<SpawnPointModel> spawnPoints;

  const MapDataResponse({
    required this.fixedResources,
    required this.spawnPoints,
  });

  factory MapDataResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawFixed =
        (json['fixedResources'] as List?) ?? const [];
    final List<dynamic> rawSpawn =
        (json['spawnPoints'] as List?) ?? const [];

    return MapDataResponse(
      fixedResources: rawFixed
          .map((e) => ResourceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      spawnPoints: rawSpawn
          .map((e) => SpawnPointModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

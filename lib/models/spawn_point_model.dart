import 'spawn_resource_model.dart';

class SpawnPointModel {
  final int id;
  final double lat;
  final double lng;
  final double x;
  final double y;
  final String pointType;
  final String? placeLabel;
  final List<SpawnResourceModel> resources;

  const SpawnPointModel({
    required this.id,
    required this.lat,
    required this.lng,
    required this.x,
    required this.y,
    required this.pointType,
    required this.resources,
    this.placeLabel,
  });

  factory SpawnPointModel.fromJson(Map<String, dynamic> json) {
    const double mapSize = 1024.0;

    final double lngVal = (json['lng'] as num).toDouble();
    final double latVal = (json['lat'] as num).toDouble();

    final List<dynamic> rawResources = (json['resources'] as List?) ?? const [];

    return SpawnPointModel(
      id: (json['id'] as num).toInt(),
      lat: latVal,
      lng: lngVal,
      x: lngVal / mapSize,
      y: 1.0 - ((mapSize + latVal) / mapSize),
      pointType: (json['pointType'] ?? json['point_type'] ?? 'shared').toString(),
      placeLabel: (json['placeLabel'] ?? json['place_label'])?.toString(),
      resources: rawResources
          .map((e) => SpawnResourceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  SpawnResourceModel? get oak {
    try {
      return resources.firstWhere((r) => r.resourceName == 'roaming_oak');
    } catch (_) {
      return null;
    }
  }

  SpawnResourceModel? get fluorite {
    try {
      return resources.firstWhere((r) => r.resourceName == 'fluorite');
    } catch (_) {
      return null;
    }
  }

  bool get hasOak => oak != null;
  bool get hasFluorite => fluorite != null;

  bool get isOakVerified => oak?.isVerified == true;
  bool get isFluoriteVerified => fluorite?.isVerified == true;
  bool get isBothVerified => isOakVerified && isFluoriteVerified;

  bool get isOakOnly => pointType == 'oak_only';

  bool get hasAnyActiveResource => resources.any((r) => r.isActive);
  bool get hasAnyVotedByMe => resources.any((r) => r.votedByMe);
}

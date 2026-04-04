import 'dart:ui';

class PlaceLabel {
  final String id;
  final String nameKo;
  final List<Offset> positions;
  final bool showFromBaseZoom;

  const PlaceLabel({
    required this.id,
    required this.nameKo,
    required this.positions,
    this.showFromBaseZoom = false,
  });
}
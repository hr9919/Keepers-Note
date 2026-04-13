class WidgetPlaceRef {
  final String label;
  final double lat;
  final double lng;

  const WidgetPlaceRef({
    required this.label,
    required this.lat,
    required this.lng,
  });
}

/// 사진 기준으로 다시 맞춘 집 위치 라벨
const List<WidgetPlaceRef> kWidgetPlaceRefs = [
  // 기존 8번 위치가 실제 1번
  WidgetPlaceRef(label: '1번 집 앞', lat: -635.1, lng: 368.7),

  // 기존 1,2,3,4,5,6,7 이 각각 2,3,4,5,6,7,8 로 한 칸씩 밀림
  WidgetPlaceRef(label: '2번 집 앞', lat: -376.0, lng: 608.3),
  WidgetPlaceRef(label: '3번 집 앞', lat: -365.6, lng: 530.9),
  WidgetPlaceRef(label: '4번 집 앞', lat: -335.8, lng: 452.2),
  WidgetPlaceRef(label: '5번 집 앞', lat: -330.9, lng: 387.6),
  WidgetPlaceRef(label: '6번 집 앞', lat: -428.4, lng: 318.7),
  WidgetPlaceRef(label: '7번 집 앞', lat: -510.1, lng: 331.5),
  WidgetPlaceRef(label: '8번 집 앞', lat: -571.1, lng: 337.6),

  WidgetPlaceRef(label: '9번 집 앞', lat: -415.7, lng: 670.5),
  WidgetPlaceRef(label: '10번 집 앞', lat: -488.2, lng: 671.7),
  WidgetPlaceRef(label: '11번 집 앞', lat: -574.2, lng: 663.2),
  WidgetPlaceRef(label: '12번 집 앞', lat: -636.3, lng: 645.5),

  WidgetPlaceRef(label: '숲', lat: -545.5, lng: 807.7),
];

String mapPointToWidgetLabelByLatLng(double lat, double lng) {
  WidgetPlaceRef? best;
  double bestDist = double.infinity;

  for (final ref in kWidgetPlaceRefs) {
    final dLat = lat - ref.lat;
    final dLng = lng - ref.lng;
    final dist = (dLat * dLat) + (dLng * dLng);

    if (dist < bestDist) {
      bestDist = dist;
      best = ref;
    }
  }

  return best?.label ?? '위치 확인 필요';
}
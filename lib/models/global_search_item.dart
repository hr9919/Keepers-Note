enum SearchTargetScreen {
  encyclopedia,
  cooking,
  gathering,
  pet,
}

enum GatheringTabType {
  fish,
  bird,
  insect,
  plant,
}

class GlobalSearchItem {
  final String id;
  final String title;
  final String? subtitle;
  final String iconPath;
  final SearchTargetScreen screen;
  final GatheringTabType? gatheringTab;
  final String keyword;

  const GlobalSearchItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.iconPath,
    required this.screen,
    this.gatheringTab,
    required this.keyword,
  });
}
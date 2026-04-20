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

enum CookingTabType {
  recipe,
  material,
}

enum CookingMaterialCategoryType {
  crop,
  store,
  mushroom,
  fish,
  insect,
  etc,
}

class GlobalSearchItem {
  final String id;
  final String title;
  final String? subtitle;
  final String iconPath;
  final SearchTargetScreen screen;
  final GatheringTabType? gatheringTab;
  final CookingTabType? cookingTab;
  final CookingMaterialCategoryType? cookingMaterialCategory;
  final String keyword;

  const GlobalSearchItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.iconPath,
    required this.screen,
    this.gatheringTab,
    this.cookingTab,
    this.cookingMaterialCategory,
    required this.keyword,
  });
}

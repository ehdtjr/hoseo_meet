class Category {
  final String name;
  final String iconPath;

  const Category({
    required this.name,
    required this.iconPath,
  });
}

const List<Category> categories = [
  Category(name: '자취방', iconPath: 'assets/icons/fi-rr-home.svg'),
  Category(name: '음식점', iconPath: 'assets/icons/fi-rr-utensils.svg'),
  Category(name: '카페', iconPath: 'assets/icons/fi-rr-mug-alt.svg'),
  Category(name: '술집', iconPath: 'assets/icons/fi-rr-beer.svg'),
  Category(name: '편의점', iconPath: 'assets/icons/ff-rr-store.svg'),
];

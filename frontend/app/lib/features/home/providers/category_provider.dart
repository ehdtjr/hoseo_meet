import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/category.dart';


class CategoryNotifier extends StateNotifier<Category?> {
  CategoryNotifier() : super(null); // 초기 상태를 null로 설정

  void selectCategory(Category? category) {
    if (state == category) {
      state = null; // 동일한 카테고리를 다시 클릭하면 null로 변경
    } else {
      state = category; // 다른 카테고리를 클릭하면 상태 변경
    }
  }
}

// StateNotifierProvider에서 상태 타입을 Category?로 변경
final categoryProvider = StateNotifierProvider<CategoryNotifier, Category?>(
      (ref) => CategoryNotifier(),
);

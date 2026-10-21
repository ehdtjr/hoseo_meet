import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 카테고리 열거형
enum ChatCategory { all, meet, delivery, taxi }

/// 전역 StateProvider로 현재 선택된 카테고리를 관리 (초기값: ChatCategory.all)
final chatCategoryProvider = StateProvider<ChatCategory>((ref) {
  return ChatCategory.all;
});

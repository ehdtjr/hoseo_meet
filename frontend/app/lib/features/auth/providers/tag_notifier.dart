import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/tag.dart';
import '../data/services/user_service.dart';

class TagNotifier extends StateNotifier<TagState> {
  final UserService userService;

  TagNotifier({required this.userService}) : super(const TagState());

  Future<void> fetchTags() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final tags = await userService.getUserTags();
      state = state.copyWith(
        isLoading: false,
        tags: tags,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '태그 불러오기 실패: $e',
      );
    }
  }

  void clearTags() {
    state = const TagState();
  }
}

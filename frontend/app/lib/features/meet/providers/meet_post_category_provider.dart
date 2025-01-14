import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MeetPostCategory { all, meet, delivery, taxi }

final meetPostCategoryProvider = StateProvider<MeetPostCategory>((ref) {
  return MeetPostCategory.all;
});

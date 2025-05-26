import 'package:shared_preferences/shared_preferences.dart';

class BlockedUsers {
  static const String _key = 'blocked_user_ids';

  /// 차단된 유저 목록 가져오기
  static Future<List<int>> getBlockedUserIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key);
    return ids?.map(int.parse).toList() ?? [];
  }

  /// 차단 추가
  static Future<void> blockUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    if (!ids.contains(userId.toString())) {
      ids.add(userId.toString());
      await prefs.setStringList(_key, ids);
    }
  }

  /// 차단 해제
  static Future<void> unblockUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    ids.remove(userId.toString());
    await prefs.setStringList(_key, ids);
  }

  /// 차단 여부 확인
  static Future<bool> isBlocked(int userId) async {
    final ids = await getBlockedUserIds();
    return ids.contains(userId);
  }
}

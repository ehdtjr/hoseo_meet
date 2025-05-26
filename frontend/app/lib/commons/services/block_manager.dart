import 'package:shared_preferences/shared_preferences.dart';

class BlockedUsers {
  static const String _key = 'blocked_user_ids';

  /// 캐시된 차단된 유저 ID 목록 (앱 내에서만 유지)
  static List<int>? _cachedIds;

  /// 차단된 유저 목록 가져오기 (캐시 우선)
  static Future<List<int>> getBlockedUserIds() async {
    if (_cachedIds != null) return _cachedIds!;
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key);
    _cachedIds = ids?.map(int.parse).toList() ?? [];
    return _cachedIds!;
  }

  /// 차단 추가
  static Future<void> blockUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    final userIdStr = userId.toString();
    if (!ids.contains(userIdStr)) {
      ids.add(userIdStr);
      await prefs.setStringList(_key, ids);
      _cachedIds = ids.map(int.parse).toList(); // ✅ 캐시 갱신
    }
  }

  /// 차단 해제
  static Future<void> unblockUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    final userIdStr = userId.toString();
    ids.remove(userIdStr);
    await prefs.setStringList(_key, ids);
    _cachedIds = ids.map(int.parse).toList(); // ✅ 캐시 갱신
  }

  /// 차단 여부 확인
  static Future<bool> isBlocked(int userId) async {
    final ids = await getBlockedUserIds();
    return ids.contains(userId);
  }

  /// 캐시 초기화 (예: 로그아웃 시)
  static void clearCache() {
    _cachedIds = null;
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  static const _secureStorage = FlutterSecureStorage();

  // 토큰 읽기
  Future<String?> readRefreshToken() async {
    try {
      final token = await _secureStorage.read(key: 'refresh_token');
      return token;
    } catch (e) {
      print('[TokenStorageService] Failed to read refresh token: $e');
      return null;
    }
  }

  // 토큰 쓰기
  Future<void> writeRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: 'refresh_token', value: token);
      print('[TokenStorageService] Refresh Token saved');
    } catch (e) {
      print('[TokenStorageService] Failed to save refresh token: $e');
    }
  }

  /// Refresh 토큰 삭제
  Future<void> deleteRefreshToken() async {
    try {
      await _secureStorage.delete(key: 'refresh_token');
      print('[TokenStorageService] Refresh Token deleted');
    } catch (e) {
      print('[TokenStorageService] Failed to delete refresh token: $e');
    }
  }

}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/auth_state.dart';
import '../data/services/auth_service.dart';
import '../data/services/token_storage_service.dart';
import 'auth_notifier.dart';


final tokenStorageProvider = Provider<TokenStorageService>((ref) {
  return TokenStorageService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(); // Map<String,dynamic> 결과 반환
});

final authNotifierProvider =
StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final service = ref.watch(authServiceProvider);
  final storage = ref.watch(tokenStorageProvider);
  return AuthNotifier(service, storage);
});
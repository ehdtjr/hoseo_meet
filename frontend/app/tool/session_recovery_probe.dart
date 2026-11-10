// Isolated emulator entrypoint. Use only with session_recovery_probe_server.py.
// Exercises production auth, secure storage, HTTP client, lifecycle and ChatPage.
import 'package:campusmeet/commons/services/session_lifecycle.dart';
import 'package:campusmeet/config.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier_provider.dart';
import 'package:campusmeet/features/chat/presentation/pages/chat_page.dart';
import 'package:campusmeet/features/navigation/providers/bottom_nav_index_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.baseUrl != 'http://10.0.2.2:18810/api/v1') {
    throw StateError('The session probe must use its isolated synthetic API.');
  }
  final container = ProviderContainer();
  final auth = container.read(authNotifierProvider.notifier);
  await auth.initialization;
  await auth.logout();
  await auth.loginUser('synthetic-probe', 'synthetic-password');
  container.read(bottomNavIndexProvider.notifier).state = 2;
  runApp(UncontrolledProviderScope(
    container: container,
    child: const SessionLifecycle(child: MaterialApp(home: ProbePage())),
  ));
}

class ProbePage extends ConsumerWidget {
  const ProbePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    return auth.isLoggedIn
        ? const ChatPage()
        : const Scaffold(body: Center(child: Text('Probe signed out')));
  }
}

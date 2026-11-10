import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_notifier_provider.dart';

/// Also retries startup auto-login after a temporary offline launch.
class SessionLifecycle extends ConsumerStatefulWidget {
  const SessionLifecycle({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SessionLifecycle> createState() => _SessionLifecycleState();
}

class _SessionLifecycleState extends ConsumerState<SessionLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authNotifierProvider.notifier).ensureValidSession();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

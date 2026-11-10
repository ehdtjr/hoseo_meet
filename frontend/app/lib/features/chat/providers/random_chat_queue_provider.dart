import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../commons/network/auth_http_client_provider.dart';
import '../../auth/providers/auth_notifier_provider.dart';
import '../data/models/random_chat_queue.dart';
import '../data/services/random_chat_service.dart';

class RandomChatQueueState {
  final RandomChatQueueSnapshot queue;
  final bool isBusy;
  final bool isStatusUncertain;
  final String? errorMessage;

  const RandomChatQueueState({
    this.queue = const RandomChatQueueSnapshot.idle(),
    this.isBusy = false,
    this.isStatusUncertain = true,
    this.errorMessage,
  });

  RandomChatQueueState copyWith({
    RandomChatQueueSnapshot? queue,
    bool? isBusy,
    bool? isStatusUncertain,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RandomChatQueueState(
      queue: queue ?? this.queue,
      isBusy: isBusy ?? this.isBusy,
      isStatusUncertain: isStatusUncertain ?? this.isStatusUncertain,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class RandomChatQueueController extends StateNotifier<RandomChatQueueState> {
  static const genericError = '랜덤채팅 상태를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const joinError = '매칭 시작을 완료하지 못했습니다. 다시 시도해주세요.';
  static const leaveError = '대기 취소를 완료하지 못했습니다. 다시 시도해주세요.';

  final RandomChatQueueApi _api;
  final Duration _pollInterval;
  final Duration _reconciliationDelay;
  Timer? _pollTimer;
  bool _active = false;
  bool _mutationInFlight = false;
  bool _statusInFlight = false;
  Completer<void>? _statusCompleted;
  bool _initialized = false;
  bool _disposed = false;
  int _generation = 0;

  RandomChatQueueController(
    this._api, {
    Duration pollInterval = const Duration(seconds: 5),
    Duration reconciliationDelay = const Duration(seconds: 1),
  })  : _pollInterval = pollInterval,
        _reconciliationDelay = reconciliationDelay,
        super(const RandomChatQueueState());

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await refreshStatus(showError: true);
  }

  Future<void> resume() async {
    _active = true;
    if (!_initialized) {
      await initialize();
    } else {
      await refreshStatus(showError: false, force: true);
    }
  }

  void pause() {
    _active = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Authentication could not be checked after resume. Do not show a cached
  /// waiting/matched result as current while the page retries the session.
  void markStatusUncertain() {
    if (!_disposed) {
      state = state.copyWith(isStatusUncertain: true, clearError: true);
    }
  }

  Future<void> join() => _mutate(
        operation: _api.join,
        succeeded: (result) => result.status != RandomChatQueueStatus.idle,
        failureMessage: joinError,
      );

  Future<void> leave() => _mutate(
        operation: _api.leave,
        succeeded: (result) => result.status != RandomChatQueueStatus.waiting,
        failureMessage: leaveError,
      );

  Future<void> refreshStatus(
      {bool showError = true, bool force = false}) async {
    if (_mutationInFlight || _disposed) return;
    if (_statusInFlight) {
      if (force) {
        // A request started before leaving a room may still say "matched".
        // Wait for it, then fetch again rather than accepting that old result.
        await _statusCompleted!.future;
        await refreshStatus(showError: showError, force: true);
      }
      return;
    }
    _statusInFlight = true;
    final completed = Completer<void>();
    _statusCompleted = completed;
    final generation = _generation;
    try {
      final result = await _api.getStatus();
      if (!_disposed && generation == _generation) {
        _apply(result, clearError: true);
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        // Silent polling suppresses repeated snackbars, not the persistent
        // connection/status warning. Never present an expired lease as waiting.
        state = state.copyWith(
          isStatusUncertain: true,
          errorMessage: showError ? genericError : null,
        );
      }
    } finally {
      _statusInFlight = false;
      _statusCompleted = null;
      completed.complete();
      if (!_disposed) _syncPolling();
    }
  }

  Future<void> _mutate({
    required Future<RandomChatQueueSnapshot> Function() operation,
    required bool Function(RandomChatQueueSnapshot) succeeded,
    required String failureMessage,
  }) async {
    if (_mutationInFlight || _disposed) return;
    _mutationInFlight = true;
    final generation = ++_generation;
    _pollTimer?.cancel();
    _pollTimer = null;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await operation();
      if (!_disposed && generation == _generation) {
        _apply(result, clearError: true);
        if (!succeeded(result)) {
          state = state.copyWith(errorMessage: failureMessage);
        }
      }
    } catch (_) {
      // A timed-out mutation may still have reached the server. Reconcile with
      // the authoritative status. A few bounded follow-ups cover a response
      // that was lost just before the transaction became visible.
      RandomChatQueueSnapshot? reconciled;
      for (var attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) await Future<void>.delayed(_reconciliationDelay);
        if (_disposed || generation != _generation) break;
        try {
          reconciled = await _api.getStatus();
          if (succeeded(reconciled)) break;
        } catch (_) {
          reconciled = null;
          // Try again within the fixed reconciliation budget.
        }
      }
      if (!_disposed && generation == _generation) {
        if (reconciled != null) {
          _apply(reconciled, clearError: true);
          if (!succeeded(reconciled)) {
            state = state.copyWith(errorMessage: failureMessage);
          }
        } else {
          state = state.copyWith(
            isStatusUncertain: true,
            errorMessage: genericError,
          );
        }
      }
    } finally {
      _mutationInFlight = false;
      if (!_disposed) {
        state = state.copyWith(isBusy: false);
        _syncPolling();
      }
    }
  }

  void clearError() {
    if (!_disposed) state = state.copyWith(clearError: true);
  }

  void _apply(RandomChatQueueSnapshot result, {required bool clearError}) {
    state = state.copyWith(
      queue: result,
      isStatusUncertain: false,
      clearError: clearError,
    );
    _syncPolling();
  }

  void _syncPolling() {
    final shouldPoll = _active &&
        !_mutationInFlight &&
        (state.queue.status == RandomChatQueueStatus.waiting ||
            state.isStatusUncertain);
    if (!shouldPoll) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    if (_pollTimer?.isActive == true) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(refreshStatus(showError: false));
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}

final randomChatQueueApiProvider = Provider<RandomChatQueueApi>((ref) {
  return RandomChatService(
    AuthRandomChatHttpClient(ref.watch(authHttpClientProvider)),
  );
});

final randomChatQueueProvider = StateNotifierProvider.autoDispose<
    RandomChatQueueController, RandomChatQueueState>((ref) {
  // Logging out disposes the controller and its timer. A later login creates a
  // fresh controller, so queue state never leaks between accounts.
  ref.watch(authNotifierProvider.select((auth) => auth.isLoggedIn));
  return RandomChatQueueController(ref.watch(randomChatQueueApiProvider));
});

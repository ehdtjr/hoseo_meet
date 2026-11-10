import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../navigation/providers/bottom_nav_index_provider.dart';
import '../../../auth/providers/auth_notifier_provider.dart';
import '../../data/models/chat_room.dart';
import '../../data/models/random_chat_queue.dart';
import '../../providers/chat_category_provider.dart';
import '../../providers/random_chat_queue_provider.dart';
import '../../providers/chat_room_provicer.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_category_bar.dart';
import '../widgets/random_chat_queue_card.dart';
import '../widgets/chat_room_list.dart';
import 'chat_detail_page.dart';

class ChatPage extends ConsumerStatefulWidget {
  final Widget Function(ChatRoom room)? chatDetailBuilder;

  const ChatPage({super.key, this.chatDetailBuilder});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver {
  bool _isInitialLoading = true;
  bool _isInitialized = false;
  bool _openingMatchedRoom = false;
  int _resumeRevision = 0;
  bool _foreground = true;
  Timer? _sessionRetryTimer;
  RandomChatQueueController? _queueController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() async {
      if (!mounted) return;
      await Future.wait([
        _fetchRooms(showError: false),
        ref.read(randomChatQueueProvider.notifier).initialize(),
      ]);
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _sessionRetryTimer?.cancel();
    _queueController?.pause();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(randomChatQueueProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _resumeChat();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      _resumeRevision++;
      _sessionRetryTimer?.cancel();
      controller.pause();
    }
  }

  Future<void> _resumeChat() async {
    if (!mounted || !_foreground) return;
    _sessionRetryTimer?.cancel();
    final revision = ++_resumeRevision;
    final ready = await ref.read(authNotifierProvider.notifier).ensureValidSession();
    if (!mounted || !_foreground || revision != _resumeRevision) return;
    if (!ready) {
      ref.read(randomChatQueueProvider.notifier).markStatusUncertain();
      if (ref.read(authNotifierProvider).refreshToken != null &&
          ref.read(bottomNavIndexProvider) == 2) {
        _sessionRetryTimer = Timer(const Duration(seconds: 2), () {
          if (mounted && _foreground && revision == _resumeRevision &&
              ref.read(bottomNavIndexProvider) == 2) {
            unawaited(_resumeChat());
          }
        });
      }
      return;
    }
    await _fetchRooms(showError: true);
    if (!mounted || revision != _resumeRevision) return;
    if (ref.read(bottomNavIndexProvider) == 2) {
      final controller = ref.read(randomChatQueueProvider.notifier);
      _queueController = controller;
      await controller.resume();
    }
  }

  Future<void> _onRefresh() => _resumeChat();

  Future<bool> _fetchRooms({required bool showError}) async {
    try {
      await ref.read(chatRoomNotifierProvider.notifier).fetchRooms();
      return true;
    } catch (_) {
      if (showError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅방을 불러오지 못했습니다. 다시 시도해주세요.')),
        );
      }
      return false;
    }
  }

  Future<void> _openMatchedRoom(int streamId) async {
    if (_openingMatchedRoom) return;
    setState(() => _openingMatchedRoom = true);
    try {
      final loaded = await _fetchRooms(showError: true);
      if (!mounted || !loaded) return;
      ChatRoom? matchedRoom;
      for (final room in ref.read(chatRoomNotifierProvider)) {
        if (room.streamId == streamId) {
          matchedRoom = room;
          break;
        }
      }
      if (matchedRoom == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅방을 불러오지 못했습니다. 다시 시도해주세요.')),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              widget.chatDetailBuilder?.call(matchedRoom!) ??
              ChatDetailPage(chatRoom: matchedRoom!),
        ),
      );
      if (!mounted) return;
      await Future.wait([
        _fetchRooms(showError: false),
        ref.read(randomChatQueueProvider.notifier).refreshStatus(force: true),
      ]);
    } finally {
      if (mounted) setState(() => _openingMatchedRoom = false);
    }
  }

  Future<void> _onRoomClosed(ChatRoom room) async {
    if (!mounted || room.type != 'random') return;
    await Future.wait([
      _fetchRooms(showError: false),
      ref.read(randomChatQueueProvider.notifier).refreshStatus(force: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      authNotifierProvider.select((auth) => auth.isLoggedIn),
      (previous, loggedIn) {
        if (loggedIn && previous == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && ref.read(bottomNavIndexProvider) == 2) {
              _resumeChat();
            }
          });
        }
      },
    );
    ref.listen<RandomChatQueueState>(randomChatQueueProvider, (previous, next) {
      if (!next.isStatusUncertain &&
          next.queue.status == RandomChatQueueStatus.matched &&
          (previous?.queue.status != RandomChatQueueStatus.matched ||
              previous?.queue.streamId != next.queue.streamId ||
              previous?.isStatusUncertain == true)) {
        _fetchRooms(showError: false);
      }
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(next.errorMessage!)));
          ref.read(randomChatQueueProvider.notifier).clearError();
        });
      }
    });
    final currentIndex = ref.watch(bottomNavIndexProvider);

    if (currentIndex == 2 && !_isInitialized) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _resumeChat();
      });
    }

    if (currentIndex != 2) {
      if (_isInitialized) {
        _sessionRetryTimer?.cancel();
        _resumeRevision++;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(randomChatQueueProvider.notifier).pause();
        });
      }
      _isInitialized = false;
    }

    final chatRooms = ref.watch(chatRoomNotifierProvider);
    final selectedCategory = ref.watch(chatCategoryProvider);
    final isExitMode = ref.watch(chatRoomNotifierProvider.notifier).isExitMode;
    final randomChatState = ref.watch(randomChatQueueProvider);
    final filteredRooms = _filterRoomsByCategory(chatRooms, selectedCategory);

    if (_isInitialLoading && chatRooms.isEmpty) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChatHeader(
                isExitMode: isExitMode,
                onToggleExitMode: () => ref
                    .read(chatRoomNotifierProvider.notifier)
                    .toggleExitMode(),
              ),
              const SizedBox(height: 16),
              RandomChatQueueCard(
                state: randomChatState.copyWith(
                  isBusy: randomChatState.isBusy || _openingMatchedRoom,
                ),
                onJoin: () => ref.read(randomChatQueueProvider.notifier).join(),
                onLeave: () =>
                    ref.read(randomChatQueueProvider.notifier).leave(),
                onOpenRoom: () {
                  final streamId = randomChatState.queue.streamId;
                  if (streamId != null) _openMatchedRoom(streamId);
                },
                onRetry: _resumeChat,
              ),
              const SizedBox(height: 25),
              const ChatCategoryBar(),
              const SizedBox(height: 10),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: filteredRooms.isEmpty
                      ? _buildEmptyState()
                      : ChatRoomList(
                          rooms: filteredRooms,
                          isExitMode: isExitMode,
                          selectedRoomIds: ref
                              .watch(chatRoomNotifierProvider.notifier)
                              .roomsToRemove
                              .map((room) => room.streamId)
                              .toSet(),
                          onRoomToggle: (roomId) {
                            ref
                                .read(chatRoomNotifierProvider.notifier)
                                .toggleRoomRemoval(roomId);
                          },
                          onRoomClosed: _onRoomClosed,
                          chatDetailBuilder: widget.chatDetailBuilder,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isExitMode
          ? RawMaterialButton(
              onPressed: () async {
                final notifier = ref.read(chatRoomNotifierProvider.notifier);

                if (notifier.roomsToRemove.isNotEmpty) {
                  final includesRandom = notifier.roomsToRemove
                      .any((room) => room.type == 'random');
                  try {
                    await notifier.removeSelectedRooms();
                    notifier.toggleExitMode();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('일부 채팅방에서 나가지 못했습니다. 다시 시도해주세요.'),
                        ),
                      );
                    }
                  } finally {
                    // Earlier removals may have committed even if a later
                    // request failed or its response was lost.
                    if (mounted && includesRandom) {
                      await Future.wait([
                        _fetchRooms(showError: false),
                        ref
                            .read(randomChatQueueProvider.notifier)
                            .refreshStatus(force: true),
                      ]);
                    }
                  }
                } else {
                  debugPrint('No rooms selected for removal.');
                }
              },
              shape: const CircleBorder(),
              child: SvgPicture.asset(
                'assets/icons/chat-remove-button.svg',
                width: 43,
                height: 43,
              ),
            )
          : null,
    );
  }

  List<ChatRoom> _filterRoomsByCategory(
    List<ChatRoom> rooms,
    ChatCategory cat,
  ) {
    switch (cat) {
      case ChatCategory.all:
        return rooms;
      case ChatCategory.meet:
        return rooms.where((r) => r.type == 'meet').toList();
      case ChatCategory.delivery:
        return rooms.where((r) => r.type == 'delivery').toList();
      case ChatCategory.taxi:
        return rooms.where((r) => r.type == 'taxi').toList();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/empty_chat.svg',
            width: 100,
            height: 100,
            colorFilter: const ColorFilter.mode(
              Color(0xFFE72410),
              BlendMode.srcIn,
            ),
            placeholderBuilder: (context) => const Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Color(0xFFE72410),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '채팅방이 비어 있어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Meet 게시판 통해\n새로운 대화를 시작해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w400,
              height: 1.4,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

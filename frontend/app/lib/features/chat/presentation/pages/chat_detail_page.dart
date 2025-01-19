import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/chat/presentation/widgets/detail/chat_message_loading_indicator.dart';

import '../../data/models/chat_message.dart';
import '../../data/models/chat_room.dart';
import '../../providers/chat_detail_provider.dart';
import '../../providers/chat_detail_notifier.dart';
import '../../providers/chat_room_provicer.dart';
import '../widgets/detail/chat_message_list.dart';
import '../widgets/detail/chat_room_app_bar.dart';
import '../widgets/detail/input_bar/chat_input_bar.dart';

/// Scroll Glow 제거용 커스텀 Behavior (Flutter 3.7+에서 buildViewportChrome -> buildOverscrollIndicator로 변경)
class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    // 스크롤 오버플로우 시 발생하는 Glow(반짝) 효과 제거
    return child;
  }
}

class ChatDetailPage extends ConsumerStatefulWidget {
  final ChatRoom chatRoom;

  const ChatDetailPage({
    super.key,
    required this.chatRoom,
  });

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage>
    with WidgetsBindingObserver {
  // 메시지 입력 관련
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  // 실제 비즈니스 로직 담당 Notifier
  late final ChatDetailNotifier _detailNotifier;

  // "자동 스크롤" 판정에 사용할 하단 부근(threshold) 거리
  static const double _scrollThreshold = 500.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Notifier 인스턴스 초기화
    _detailNotifier =
        ref.read(chatDetailNotifierProvider(widget.chatRoom).notifier);

    // 화면 렌더링이 끝난 뒤 초기 작업
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _detailNotifier.init();
      await _detailNotifier.startLocationTracking();

      // 채팅방 읽음 처리
      ref
          .read(chatRoomNotifierProvider.notifier)
          .markRoomAsRead(widget.chatRoom.streamId);
    });

    // 위로 스크롤 시 이전 메시지 로드
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detailNotifier.disposeNotifier();

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  /// (A) 스크롤 리스너
  void _onScroll() {
    final currentState = ref.read(chatDetailNotifierProvider(widget.chatRoom));
    // 스크롤 맨 위쪽 근접 & 아직 로딩 중이 아닐 때 → 이전 메시지 로드
    if (_scrollController.position.pixels <= 100 && !currentState.isLoadingMore) {
      _loadMoreMessagesSafely();
    }
  }

  /// 이전 메시지 로드 시 "스크롤 튐" 최소화를 위한 offset 보정
  Future<void> _loadMoreMessagesSafely() async {
    final oldOffset = _scrollController.offset;
    final oldMaxExtent = _scrollController.position.maxScrollExtent;

    await _detailNotifier.loadMoreMessages();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final newMaxExtent = _scrollController.position.maxScrollExtent;
      final diff = newMaxExtent - oldMaxExtent;
      _scrollController.jumpTo(oldOffset + diff);
    });
  }

  /// (B) 메시지 전송
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await _detailNotifier.sendMessage(text);
    _messageController.clear();

    _scrollToBottom();
  }

  /// (C) "사용자가 하단 부근"인지 판별
  bool _isUserNearBottom() {
    if (!_scrollController.hasClients) return false;
    final currentOffset = _scrollController.offset;
    final maxOffset = _scrollController.position.maxScrollExtent;

    return (maxOffset - currentOffset) < _scrollThreshold;
  }

  /// (D) "새 메시지 수신 시" 자동 스크롤 여부 체크
  void _scrollToBottomIfNeeded() {
    if (_isUserNearBottom()) {
      _scrollToBottom();
    }
  }

  /// (E) 실제 스크롤을 맨 아래로 이동
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 최신 채팅 상태 watch
    final detailState = ref.watch(chatDetailNotifierProvider(widget.chatRoom));

    // (1) 새 메시지 추가감지 → "이미 하단부근이라면" 자동 스크롤
    ref.listen<ChatDetailState>(
      chatDetailNotifierProvider(widget.chatRoom),
          (previous, next) {
        // 이전 상태가 없거나, 메시지 개수 변화가 없다면 무시
        if (previous == null ||
            previous.messages.length == next.messages.length) {
          return;
        }

        // 새 메시지가 추가된 상황
        if (next.messages.length > previous.messages.length) {
          _scrollToBottomIfNeeded();
        }
      },
    );

    return ScrollConfiguration(
      behavior: const _NoGlowScrollBehavior(),
      child: Scaffold(
        appBar: ChatRoomAppBar(chatRoomName: widget.chatRoom.name),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: Column(
              children: [
                // (로딩 표시) 이전 메시지 불러오는 중
                if (detailState.isLoadingMore)
                  const ChatMessageLoadingIndicator(),

                // 분리된 ListView 위젯
                ChatMessageListView(
                  scrollController: _scrollController,
                  messages: detailState.messages,
                  participants: detailState.participants,
                ),

                const Divider(height: 1, color: Colors.red),
                // 입력창
                ChatInputBar(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  onSend: _sendMessage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

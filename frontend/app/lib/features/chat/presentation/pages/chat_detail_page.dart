import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/chat/presentation/widgets/detail/chat_message_loading_indicator.dart';

import '../../data/models/chat_room.dart';
import '../../providers/chat_detail_provider.dart';
import '../../providers/chat_detail_notifier.dart';
import '../../providers/chat_room_provicer.dart';
import '../widgets/detail/chat_message_bubble.dart';
import '../widgets/detail/chat_room_app_bar.dart';
import '../widgets/detail/input_bar/chat_input_bar.dart';

/// Scroll Glow 제거용 커스텀 Behavior
/// Flutter 3.7+에서는 buildViewportChrome -> buildOverscrollIndicator로 변경
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

  // ChatDetailNotifier 참조
  late final ChatDetailNotifier _detailNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ChatDetailNotifier 인스턴스 초기화
    _detailNotifier =
        ref.read(chatDetailNotifierProvider(widget.chatRoom).notifier);

    // 화면 렌더링이 끝난 뒤 초기 작업
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ChatDetailNotifier 초기화
      await _detailNotifier.init();
      await _detailNotifier.startLocationTracking();

      // 채팅방 읽음 처리
      ref.read(chatRoomNotifierProvider.notifier)
          .markRoomAsRead(widget.chatRoom.streamId);
    });

    // 스크롤 리스너 (위로 스크롤 시 이전 메시지 로드)
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

  /// 위로 스크롤 시 이전 메시지 로딩
  void _onScroll() {
    final currentState = ref.read(chatDetailNotifierProvider(widget.chatRoom));
    // 스크롤 맨 위쪽 근접 & 아직 로딩 중이 아닐 때
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

  /// 메시지 전송
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // 지금 사용자가 "하단 근처(예: 100px 이내)"에 있는지 체크
    final currentOffset = _scrollController.offset;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final bool isNearBottom = (maxOffset - currentOffset) < 100;

    // 전송
    await _detailNotifier.sendMessage(text);
    _messageController.clear();

    // 이미 아래를 보고 있었다면 전송 후 자동 스크롤
    if (isNearBottom) {
      _scrollToBottom();
    }
  }

  /// "맨 아래로" 스크롤 (애니메이션 시간, 커브 조정 가능)
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    // ChatDetailState 구독
    final detailState = ref.watch(chatDetailNotifierProvider(widget.chatRoom));
    // 로그인한 내 정보

    return PopScope(
      canPop: false, // prevent back
      onPopInvokedWithResult: (bool didPop, Object? result)  async {
        return;
      },
      child: ScrollConfiguration(
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

                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: detailState.messages.length,
                      padding: const EdgeInsets.only(bottom: 10),
                      itemBuilder: (context, index) {
                        final msg = detailState.messages[index];
                        // senderId에 해당하는 참여자(User) 찾기
                        final sender = detailState.participants
                            .where((u) => u.id == msg.senderId)
                            .isNotEmpty
                            ? detailState.participants.firstWhere(
                              (u) => u.id == msg.senderId,
                        )
                            : null;

                        return ChatMessageBubble(
                          msg: msg,
                          sender: sender,
                        );
                      },
                    ),
                  ),

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
      ),
    );
  }
}

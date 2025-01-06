import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show PopScope;

import '../../data/models/chat_room.dart'; // ChatRoom 모델
import '../../providers/chat_detail_provider.dart';   // ChatDetailNotifier 관련 Provider
import '../../providers/chat_detail_notifier.dart';   // ChatDetailNotifier
import '../../providers/chat_room_provicer.dart';
import '../widgets/detail/chat_message_bubble.dart';
import '../widgets/detail/input_bar/chat_input_bar.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  final ChatRoom chatRoom;

  const ChatDetailPage({
    Key? key,
    required this.chatRoom,
  }) : super(key: key);

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

    // (A) ChatDetailNotifier 인스턴스 준비
    _detailNotifier =
        ref.read(chatDetailNotifierProvider(widget.chatRoom).notifier);

    // (B) 화면 렌더링 직후 처리할 로직
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1) ChatDetailNotifier 초기화
      await _detailNotifier.init();
      await _detailNotifier.startLocationTracking();

      ref
          .read(chatRoomNotifierProvider.notifier)
          .markRoomAsRead(widget.chatRoom.streamId);
    });

    // 스크롤 리스너
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detailNotifier.disposeNotifier(); // ChatDetailNotifier 해제

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentState = ref.read(chatDetailNotifierProvider(widget.chatRoom));
    if (_scrollController.position.pixels <= 300 && !currentState.isLoadingMore) {
      _detailNotifier.loadMoreMessages();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await _detailNotifier.sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ChatDetailState 구독
    final detailState = ref.watch(chatDetailNotifierProvider(widget.chatRoom));

    return PopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.chatRoom.name.isEmpty
              ? 'No Title'
              : widget.chatRoom.name),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.red),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(color: Colors.red, thickness: 1.0),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // (로딩 표시) 이전 메시지 불러오는 중
              if (detailState.isLoadingMore)
                Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(width: 10),
                      Text(
                        '이전 메시지를 불러오는 중...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

              // 메시지 목록
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: detailState.messages.length,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 10),
                  itemBuilder: (context, index) {
                    final msg = detailState.messages[index];
                    final isMe = (msg.senderId == detailState.userId);
                    final sendTime = _formatTime(msg.dateSent);

                    return ChatMessageBubble(
                      isMe: isMe,
                      content: msg.content,
                      unreadCount: msg.unreadCount,
                      sendTime: sendTime,
                      senderProfileUrl: null,
                      senderName: '알 수 없음',
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
    );
  }

  String _formatTime(DateTime dateTime) {
    try {
      final localTime = dateTime.toLocal();
      return DateFormat('a h:mm', 'ko_KR').format(localTime);
    } catch (e, stack) {
      debugPrint('[ChatDetailPage] 타임스탬프 변환 오류: $e\n$stack');
      return 'Unknown';
    }
  }
}

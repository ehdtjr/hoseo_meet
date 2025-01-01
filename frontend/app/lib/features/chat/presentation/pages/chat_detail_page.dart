// features/chat/presentation/pages/chat_detail_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_detail_notifier.dart';
import '../../providers/chat_detail_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/input_bar/chat_input_bar.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> chatRoom;

  const ChatDetailPage({
    Key? key,
    required this.chatRoom,
  }) : super(key: key);

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage>
    with WidgetsBindingObserver {
  // 컨트롤러/포커스
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  /// 수정 포인트: late final _notifier
  late final ChatDetailNotifier _notifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Notifier를 1회만 읽어서 _notifier에 저장
    _notifier = ref.read(chatDetailNotifierProvider(widget.chatRoom).notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 기존 init 로직
      await _notifier.init();
      // 위치 추적 (10m 이동 시 서버에 위치 전송)
      await _notifier.startLocationTracking();
    });

    // 스크롤 리스너
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // _notifier.disposeNotifier() (ref.read(...) 필요 없음)
    _notifier.disposeNotifier();

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    // state & notifier를 dispose에서 ref.read(...)로 가져오지 않고
    // build 시점에 watch하거나, 여기서 _notifier를 쓰거나...
    final currentState = ref.read(chatDetailNotifierProvider(widget.chatRoom));
    // 또는 final currentState = _notifier.state;
    // (Riverpod에서 Notifier의 state를 직접 접근해도 됩니다)

    if (_scrollController.position.pixels <= 300 &&
        !currentState.isLoadingMore) {
      _notifier.loadMoreMessages();
    }
  }

  Future<void> _sendMessage() async {
    await _notifier.sendMessage(_messageController.text);
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
    // 위젯 rebuild 시 notifier를 watch. (혹은 state만 watch)
    final state = ref.watch(chatDetailNotifierProvider(widget.chatRoom));

    return WillPopScope(
      onWillPop: () async {
        // 여기서 notifier.disposeNotifier()를 굳이 호출하지 않음
        // -> dispose()에서 자동으로 해제
        Navigator.pop(context, 'reload');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.chatRoom['name'] ?? 'No Title'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.red),
            onPressed: () async {
              // 여기서도 disposeNotifier()를 호출하지 않음 -> dispose()에서 처리
              Navigator.pop(context, 'reload');
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
              // 이전 메시지 로딩 중...
              if (state.isLoadingMore)
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
                  itemCount: state.messages.length,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 10),
                  itemBuilder: (context, index) {
                    final msg = state.messages[index];
                    final bool isMe = (msg.senderId == state.userId);
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

              // 메시지 입력창
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
      return DateFormat('a h:mm', 'ko_KR').format(dateTime);
    } catch (e) {
      debugPrint('[ChatDetailPage] 타임스탬프 변환 오류: $e');
      return 'Unknown';
    }
  }
}

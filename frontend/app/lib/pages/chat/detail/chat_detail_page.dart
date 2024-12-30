import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// API, Services...
import '../../../api/chat/load_message_service.dart';
import '../../../api/chat/send_message_service.dart';
import '../../../api/chat/message_read_service.dart';
import '../../../api/chat/activate_deactivate_service.dart';
import '../../../api/chat/socket_message_service.dart';
import '../../../api/login/authme_service.dart';
import '../../../api/login/login_service.dart';

// (1) Import 분리된 위젯
import 'chat_message_bubble.dart'; // 메시지 버블
import 'chat_input_bar.dart';      // 입력창

class ChatDetailPage extends StatefulWidget {
  final Map<String, dynamic> chatRoom;

  ChatDetailPage({Key? key, required this.chatRoom}) : super(key: key);

  @override
  _ChatDetailPageState createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> with WidgetsBindingObserver {
  // 1) API / 서비스
  late final LoadMessageService loadMessageService;
  late final SendMessageService sendMessageService;
  late final MessageReadService messageReadService;
  late final ActivateDeactivateService activateDeactivateService;

  // 사용자 ID
  int? _userId;

  // 2) UI
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false; // 이전 메시지 로딩 중 여부
  List<Map<String, dynamic>> messages = [];

  // 3) 타이머 / 웹소켓
  Timer? _activateTimer;
  late final SocketMessageService socketMessageService;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  // ----------------------------------------------------------
  // initState / dispose
  // ----------------------------------------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scrollController.addListener(_onScroll);

    final authService = AuthService();
    loadMessageService = LoadMessageService(authService);
    sendMessageService = SendMessageService(authService);
    messageReadService = MessageReadService(authService);
    activateDeactivateService = ActivateDeactivateService(authService);

    _fetchUserId();
    _loadMessagesAtFirstUnread();
    _markMessagesAsRead();

    _initWebSocket(authService);
    _activateRoomRegularly();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    WidgetsBinding.instance.removeObserver(this);

    _activateTimer?.cancel();
    _activateTimer = null;
    _deactivateCurrentChatRoom();

    _socketSubscription?.cancel();
    socketMessageService.closeWebSocket();
    socketMessageService.dispose();

    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 메시지 / 웹소켓 / 활성화
  // ----------------------------------------------------------
  Future<void> _loadMessagesAtFirstUnread() async {
    try {
      final previousMessages = await loadMessageService.loadMessages(
        streamId: widget.chatRoom['stream_id'],
        anchor: 'first_unread',
        numBefore: 30,
        numAfter: 30,
      );
      setState(() {
        messages.addAll(previousMessages.cast<Map<String, dynamic>>());
      });
    } catch (error) {
      print('[ChatDetailPage] 초기 메시지 로드 실패: $error');
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final oldestId = messages.isNotEmpty ? messages.first['id'] : null;

      final moreMessages = await loadMessageService.loadMessages(
        streamId: widget.chatRoom['stream_id'],
        anchor: oldestId?.toString() ?? 'first_unread',
        numBefore: 30,
        numAfter: 0,
      );

      if (moreMessages.isNotEmpty) {
        setState(() {
          messages.insertAll(0, moreMessages.cast<Map<String, dynamic>>());
        });
      } else {
        print('[ChatDetailPage] 더 이상 불러올 이전 메시지가 없습니다');
      }
    } catch (error) {
      print('[ChatDetailPage] 더 이전 메시지 로드 실패: $error');
    }
    setState(() => _isLoadingMore = false);
  }

  Future<void> _initWebSocket(AuthService authService) async {
    socketMessageService = SocketMessageService(authService.accessToken!);
    await socketMessageService.connectWebSocket();

    _socketSubscription =
        socketMessageService.messageStream.listen((incomingMessage) async {
          print('[ChatDetailPage] 수신 메시지: $incomingMessage');
          switch (incomingMessage['type']) {
            case 'read':
              _handleReadMessage(incomingMessage);
              break;
            case 'stream':
              await _handleStreamMessage(incomingMessage);
              break;
            default:
              print('[ChatDetailPage] 다룰 필요 없는 타입: ${incomingMessage['type']}');
              break;
          }
        });
  }

  void _handleReadMessage(Map<String, dynamic> incomingMessage) {
    print('[ChatDetailPage] 읽음 처리 메시지: $incomingMessage');
    final List<dynamic> readIds = incomingMessage['data']?['read_message'] ?? [];
    setState(() {
      for (var id in readIds) {
        final idx = messages.indexWhere((m) => m['id'] == id);
        if (idx != -1) {
          final currentCount = messages[idx]['unread_count'] ?? 0;
          messages[idx]['unread_count'] =
          (currentCount > 0) ? currentCount - 1 : 0;
        }
      }
    });
  }

  Future<void> _handleStreamMessage(Map<String, dynamic> incomingMessage) async {
    final data = incomingMessage['data'];
    if (data['stream_id'] == widget.chatRoom['stream_id']) {
      setState(() {
        messages.add(data);
      });
      _scrollToBottom();

      try {
        await messageReadService.markNewestMessageAsRead(
          streamId: widget.chatRoom['stream_id'],
        );
      } catch (error) {
        print('[ChatDetailPage] newest message read fail: $error');
      }
    } else {
      print('[ChatDetailPage] 다른 방 메시지');
    }
  }

  void _activateRoomRegularly() {
    _activateCurrentChatRoom();
    _activateTimer?.cancel();
    _activateTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _activateCurrentChatRoom();
    });
  }

  Future<void> _activateCurrentChatRoom() async {
    try {
      final streamId = widget.chatRoom['stream_id'];
      if (streamId != null) {
        await activateDeactivateService.activateRoom(streamId);
      }
    } catch (e) {
      print('[ChatDetailPage] activateRoom 오류: $e');
    }
  }

  Future<void> _deactivateCurrentChatRoom() async {
    try {
      await activateDeactivateService.deactivateRoom();
    } catch (e) {
      print('[ChatDetailPage] deactivateRoom 오류: $e');
    }
  }

  Future<void> _fetchUserId() async {
    try {
      final authMeService = AuthMeService(AuthService().accessToken!);
      await authMeService.fetchAndStoreUserId();
      setState(() {
        _userId = authMeService.userId;
      });
    } catch (e) {
      print('[ChatDetailPage] _fetchUserId 실패: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final unreadCount = widget.chatRoom['unread_message_count'] ?? 0;
      await messageReadService.markMessagesAsRead(
        streamId: widget.chatRoom['stream_id'],
        numAfter: unreadCount,
      );
    } catch (error) {
      print('[ChatDetailPage] markMessagesAsRead 오류: $error');
    }
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

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels <= 300 && !_isLoadingMore) {
      _loadMoreMessages();
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isNotEmpty && _userId != null) {
      try {
        await sendMessageService.sendMessage(
          streamId: widget.chatRoom['stream_id'],
          messageContent: content,
        );
        _messageController.clear();
        _scrollToBottom();
      } catch (error) {
        print('[ChatDetailPage] 메시지 전송 실패: $error');
      }
    }
  }

  // ----------------------------------------------------------
  // 시간 포맷
  // ----------------------------------------------------------
  String _formatTime(dynamic timestamp) {
    try {
      DateTime dateTime;
      if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp).toLocal();
      } else {
        throw Exception('Invalid timestamp format');
      }
      return DateFormat('a h:mm', 'ko_KR').format(dateTime);
    } catch (error) {
      print('[ChatDetailPage] 타임스탬프 변환 오류: $error');
      return 'Unknown';
    }
  }

  // ----------------------------------------------------------
  // 빌드: 메시지 아이템 → ChatMessageBubble
  // ----------------------------------------------------------
  Widget _buildMessageItem(BuildContext context, int index) {
    final msg = messages[index];
    final bool isMe = (msg['sender_id'] == _userId);

    final String senderName = msg['sender_name'] ?? '알 수 없음';
    final String? senderProfileUrl = msg['sender_profile_url'];
    final int unreadCount = msg['unread_count'] ?? 0;
    final String sendTime = _formatTime(msg['date_sent'] ?? 0);

    // (A) ChatMessageBubble 사용
    return ChatMessageBubble(
      isMe: isMe,
      content: msg['content'],
      unreadCount: unreadCount,
      sendTime: sendTime,
      senderProfileUrl: senderProfileUrl,
      senderName: senderName,
    );
  }

  // ----------------------------------------------------------
  // 빌드
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _deactivateCurrentChatRoom();
        Navigator.pop(context, 'reload');
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,

        appBar: AppBar(
          title: Text(widget.chatRoom['name'] ?? 'No Title'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.red),
            onPressed: () async {
              await _deactivateCurrentChatRoom();
              Navigator.pop(context, 'reload');
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.red),
              onPressed: () {
                // 필요 시 메뉴
              },
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(color: Colors.red, thickness: 1.0),
          ),
        ),

        body: SafeArea(
          child: Column(
            children: [
              // (A) 이전 메시지 로딩 중...
              if (_isLoadingMore)
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

              // (B) 메시지 목록
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 10),
                  itemBuilder: (context, index) {
                    return _buildMessageItem(context, index);
                  },
                ),
              ),

              // (C) 메시지 입력창: ChatInputBar 사용
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
}

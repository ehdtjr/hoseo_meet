import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 실제 프로젝트 경로에 맞춰 수정
import '../../api/chat/load_message_service.dart';
import '../../api/chat/send_message_service.dart';
import '../../api/chat/message_read_service.dart';
import '../../api/chat/activate_deactivate_service.dart';
import '../../api/chat/socket_message_service.dart';
import '../../api/login/authme_service.dart';
import '../../api/login/login_service.dart';

class ChatDetailPage extends StatefulWidget {
  final Map<String, dynamic> chatRoom;

  ChatDetailPage({required this.chatRoom});

  @override
  _ChatDetailPageState createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> with WidgetsBindingObserver {
  // ------------------------------------------------------------------------
  // 1) API / 서비스
  // ------------------------------------------------------------------------
  late final LoadMessageService loadMessageService;
  late final SendMessageService sendMessageService;
  late final MessageReadService messageReadService;
  late final ActivateDeactivateService activateDeactivateService;

  // 로그인된 사용자 ID
  int? _userId;

  // ------------------------------------------------------------------------
  // 2) UI
  // ------------------------------------------------------------------------
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  List<Map<String, dynamic>> messages = [];

  // ------------------------------------------------------------------------
  // 3) 타이머 / 웹소켓
  // ------------------------------------------------------------------------
  Timer? _activateTimer;
  late final SocketMessageService socketMessageService;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  // ------------------------------------------------------------------------
  // 4) initState / dispose
  // ------------------------------------------------------------------------
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

  // ------------------------------------------------------------------------
  // 5) 메시지 불러오기 / 웹소켓 / 방 활성화
  // ------------------------------------------------------------------------
  Future<void> _loadMessagesAtFirstUnread() async {
    try {
      final previousMessages = await loadMessageService.loadMessages(
        streamId: widget.chatRoom['stream_id'],
        anchor: 'first_unread',
        numBefore: 10,
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
    if (messages.isEmpty) return;

    setState(() => _isLoadingMore = true);

    try {
      final oldestId = messages.first['id'];
      final moreMessages = await loadMessageService.loadMessages(
        streamId: widget.chatRoom['stream_id'],
        anchor: oldestId.toString(),
        numBefore: 10,
        numAfter: 0,
      );
      if (moreMessages.isNotEmpty) {
        setState(() {
          messages.insertAll(0, moreMessages.cast<Map<String, dynamic>>());
        });
      } else {
        print('[ChatDetailPage] 더 이상 이전 메시지가 없습니다');
      }
    } catch (error) {
      print('[ChatDetailPage] 더 이전 메시지 로드 실패: $error');
    }

    setState(() => _isLoadingMore = false);
  }

  Future<void> _initWebSocket(AuthService authService) async {
    socketMessageService = SocketMessageService(authService.accessToken!);
    await socketMessageService.connectWebSocket();

    _socketSubscription = socketMessageService.messageStream.listen((incomingMessage) async {
      if (incomingMessage['stream_id'] == widget.chatRoom['stream_id']) {
        setState(() {
          messages.add(incomingMessage);
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
        print('[ChatDetailPage] 다른 방 메시지, 무시');
      }
    });
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

  // ------------------------------------------------------------------------
  // 6) 사용자 / 읽음 / 스크롤
  // ------------------------------------------------------------------------
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
    if (_scrollController.position.pixels <= 100 && !_isLoadingMore) {
      _loadMoreMessages();
    }
  }

  // ------------------------------------------------------------------------
  // 7) 메시지 전송
  // ------------------------------------------------------------------------
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

  // ------------------------------------------------------------------------
  // 8) 시간 포맷
  // ------------------------------------------------------------------------
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

  // ------------------------------------------------------------------------
  // 9) 메시지 아이템 빌드
  // ------------------------------------------------------------------------
  Widget _buildMessageItem(BuildContext context, int index) {
    final message = messages[index];
    final bool isMe = (message['sender_id'] == _userId);

    final String senderName = message['sender_name'] ?? '알 수 없음';
    final String? senderProfileUrl = message['sender_profile_url'];

    final int unreadCount = message['unread_count'] ?? 0;
    final String sendTime = _formatTime(message['date_sent'] ?? 0);

    // *** 내 메시지(오른쪽) ***
    if (isMe) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // (1) unreadCount 위, 시간 아래
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (unreadCount > 0)
                  Text('$unreadCount',
                      style: const TextStyle(color: Colors.red, fontSize: 14)),
                const SizedBox(height: 4),
                Text(sendTime,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(width: 6),

            // (2) 말풍선
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.pink.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message['content'] ?? '',
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // *** 상대방 메시지(왼쪽) ***
    else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 프로필
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade300,
              backgroundImage:
              (senderProfileUrl != null) ? NetworkImage(senderProfileUrl) : null,
            ),
            const SizedBox(width: 8),

            // 닉네임 + (말풍선 + 작은 Column)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // (a) 말풍선
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            message['content'] ?? '',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // (b) 안 읽은 수 / 시간 => crossAxisAlignment: start
                      Column(
                        // 숫자를 약간 왼쪽에 붙이려면 'start'로
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (unreadCount > 0)
                            Text(
                              '$unreadCount',
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            sendTime,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // ------------------------------------------------------------------------
  // 10) 빌드
  // ------------------------------------------------------------------------
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
          child: Stack(
            children: [
              // (1) 메시지 리스트
              Positioned.fill(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemBuilder: (context, index) {
                    return _buildMessageItem(context, index);
                  },
                ),
              ),

              // (2) 메시지 입력창
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          focusNode: _messageFocusNode,
                          controller: _messageController,
                          onTap: () {
                            FocusScope.of(context).requestFocus(_messageFocusNode);
                          },
                          decoration: InputDecoration(
                            hintText: '메시지를 입력하세요...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade200,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10.0,
                              horizontal: 20.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 전송 버튼
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.red,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // (3) 이전 메시지 로딩 중 인디케이터
              if (_isLoadingMore)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2),
                          SizedBox(width: 10),
                          Text(
                            '이전 메시지를 불러오는 중...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

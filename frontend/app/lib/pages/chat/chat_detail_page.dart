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
  bool _isLoadingMore = false;     // 이전 메시지 로딩 중 여부
  List<Map<String, dynamic>> messages = [];

  // 3) 타이머 / 웹소켓
  Timer? _activateTimer;
  late final SocketMessageService socketMessageService;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  // --------------------------
  // initState / dispose
  // --------------------------
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

  // --------------------------
  // 메시지 / 웹소켓 / 활성화
  // --------------------------
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

  // 이전 메시지 로드
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final oldestId = messages.isNotEmpty
          ? messages.first['id']
          : null;

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

  /// --------------------------
  /// WebSocket 초기화
  /// --------------------------
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

  /// "type: read" 처리
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

  /// "type: stream" 처리
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

  // --------------------------
  // 사용자 / 읽음 / 스크롤
  // --------------------------
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

  // --------------------------
  // 메시지 전송
  // --------------------------
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

  // --------------------------
  // 시간 포맷
  // --------------------------
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

  // --------------------------
  // 메시지 아이템 빌드
  // --------------------------
  Widget _buildMessageItem(BuildContext context, int index) {
    final message = messages[index];
    final bool isMe = (message['sender_id'] == _userId);

    final String senderName = message['sender_name'] ?? '알 수 없음';
    final String? senderProfileUrl = message['sender_profile_url'];

    final int unreadCount = message['unread_count'] ?? 0;
    final String sendTime = _formatTime(message['date_sent'] ?? 0);

    // (1) 내 메시지 (오른쪽)
    if (isMe) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 안 읽은 수 + 시간
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (unreadCount > 0)
                  Text(
                    '$unreadCount',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                Text(
                  sendTime,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 6),

            // 말풍선
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

    // (2) 상대방 메시지 (왼쪽)
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
              backgroundImage: (senderProfileUrl != null)
                  ? NetworkImage(senderProfileUrl)
                  : null,
            ),
            const SizedBox(width: 8),

            // 닉네임 + (말풍선 + unread/시간)
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
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (unreadCount > 0)
                            Text(
                              '$unreadCount',
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                            ),
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

  // --------------------------
  // 빌드
  // --------------------------
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
              // (A) "이전 메시지 로딩 중..." 표시
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

              // (B) 채팅 메시지 목록
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

              // (C) 메시지 입력창
              Container(
                // (1) 화면 폭에 맞게
                width: double.infinity,
                height: 72,
                color: Colors.white,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 왼쪽 여백
                    const SizedBox(width: 19),

                    // 케밥 메뉴 아이콘
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.red),
                        onPressed: () {
                          // TODO: 메뉴 열기 동작
                        },
                        // (1) 내부 패딩 없애기
                        padding: EdgeInsets.zero,
                        // (2) IconButton의 기본 constraints도 없애주면,
                        //     SizedBox 크기에 정확히 맞춰짐
                        constraints: const BoxConstraints(),
                        // (3) 필요하다면 iconSize로 아이콘 크기를 지정
                        iconSize: 20,
                      ),
                    ),

                    const SizedBox(width: 10),

                    // (2) Expanded로 감싸, 남은 공간 차지
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(236, 236, 236, 1),
                          borderRadius: BorderRadius.circular(115),
                        ),
                        child: TextField(
                          focusNode: _messageFocusNode,
                          controller: _messageController,
                          onTap: () {
                            FocusScope.of(context).requestFocus(_messageFocusNode);
                          },
                          decoration: const InputDecoration(
                            hintText: '메시지를 입력하세요...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 15,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // 전송 버튼
                    InkWell(
                      onTap: _sendMessage,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Color.fromRGBO(231, 36, 16, 1),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_upward,
                            color: Colors.red,
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 19),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

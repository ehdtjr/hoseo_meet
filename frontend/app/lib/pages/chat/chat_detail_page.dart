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
    // 스크롤 리스너/관찰자 해제
    _scrollController.removeListener(_onScroll);
    WidgetsBinding.instance.removeObserver(this);

    // 타이머/소켓 해제
    _activateTimer?.cancel();
    _activateTimer = null;
    _deactivateCurrentChatRoom();

    _socketSubscription?.cancel();
    socketMessageService.closeWebSocket();
    socketMessageService.dispose();

    // TextField 리소스 해제
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
      // 만약 messages가 비어 있더라도(= 0개라도) 이전 메시지를 로딩할 수 있도록
      final oldestId = messages.isNotEmpty
          ? messages.first['id']
          : null; // messages가 비어 있다면 null

      // anchor에 null이 들어가는 경우, 서버 API에서 "처음부터" 불러오거나
      // 별도의 로직으로 처리할 수 있도록 해야 함(백엔드 로직 확인)
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
  /// (수정된) WebSocket 초기화 메서드
  /// --------------------------
  Future<void> _initWebSocket(AuthService authService) async {
    socketMessageService = SocketMessageService(authService.accessToken!);
    await socketMessageService.connectWebSocket();

    _socketSubscription = socketMessageService.messageStream.listen((incomingMessage) async {
      print('[ChatDetailPage] 수신한 메시지: $incomingMessage');

      // (A) type 분기
      switch (incomingMessage['type']) {
        case 'read':
          _handleReadMessage(incomingMessage);
          break;

        case 'stream':
          await _handleStreamMessage(incomingMessage);
          break;

        default:
          print('[ChatDetailPage] 다른 방 메시지 or 다룰 필요 없는 타입: ${incomingMessage['type']}');
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
    final data = incomingMessage['data']; // 'data' 부분을 꺼냄

    // 현재 보고 있는 채팅방의 stream_id와 동일하면 새 메시지 추가
    if (data['stream_id'] == widget.chatRoom['stream_id']) {
      setState(() {
        // 실제 메시지 배열에 저장할 때는 `data`가 메시지 본문이므로, 이를 사용
        messages.add(data);
      });
      _scrollToBottom();

      // 새 메시지를 읽음 처리
      try {
        await messageReadService.markNewestMessageAsRead(
          streamId: widget.chatRoom['stream_id'],
        );
      } catch (error) {
        print('[ChatDetailPage] newest message read fail: $error');
      }
    } else {
      print('[ChatDetailPage] 다른 방 메시지 or type이 다름');
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

  /// --------------------------
  /// (A) 여유 거리(Threshold) 300으로 확장
  /// --------------------------
  void _onScroll() {
    final position = _scrollController.position;
    // 맨 위쪽 300px 이내로 당기면 이전 메시지 로드
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
                  // 닉네임
                  Text(
                    senderName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 말풍선
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

                      // 안 읽은 수 / 시간
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
      // 뒤로가기 시 방 비활성화
      onWillPop: () async {
        await _deactivateCurrentChatRoom();
        Navigator.pop(context, 'reload');
        return false;
      },
      child: Scaffold(
        // 키보드 올라올 때 화면 리사이즈
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
            )
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
            ],
          ),
        ),
      ),
    );
  }
}

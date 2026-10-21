import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/chat/load_message_service.dart';
import '../../api/chat/send_message_service.dart';
import '../../api/chat/message_read_service.dart';
import '../../api/login/authme_service.dart';
import '../../api/login/login_service.dart';

class ChatDetailPage extends StatefulWidget {
  final Map<String, dynamic> chatRoom;

  ChatDetailPage({required this.chatRoom});

  @override
  _ChatDetailPageState createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  late final LoadMessageService loadMessageService;
  late final SendMessageService sendMessageService;
  late final MessageReadService messageReadService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> messages = [];
  int? _userId;

  @override
  void initState() {
    super.initState();
    final authService = AuthService();
    loadMessageService = LoadMessageService(authService);
    sendMessageService = SendMessageService(authService);
    messageReadService = MessageReadService(authService);

    _fetchUserId();
    _loadPreviousMessages();
    _subscribeToMessageStream(authService.messageStream);
    _markMessagesAsRead();
  }

  Future<void> _fetchUserId() async {
    final authMeService = AuthMeService(AuthService().accessToken!);
    await authMeService.fetchAndStoreUserId();
    setState(() {
      _userId = authMeService.userId;
    });
  }

  Future<void> _loadPreviousMessages() async {
    try {
      final List<dynamic> previousMessages = await loadMessageService.loadMessages(widget.chatRoom['stream_id']);
      setState(() {
        messages.addAll(previousMessages.cast<Map<String, dynamic>>());
      });
      _scrollToBottom();
    } catch (error) {
      print('이전 메시지를 불러오는데 실패했습니다: $error');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final unreadMessageCount = widget.chatRoom['unread_message_count'] ?? 0;
      await messageReadService.markMessagesAsRead(
        streamId: widget.chatRoom['stream_id'],
        numAfter: unreadMessageCount,
      );
    } catch (error) {
      print('Error marking messages as read: $error');
    }
  }

  void _subscribeToMessageStream(Stream<Map<String, dynamic>> messageStream) {
    messageStream.listen((message) async {
      if (message['stream_id'] == widget.chatRoom['stream_id']) {
        setState(() {
          messages.add(message);
        });

        _scrollToBottom();

        try {
          await messageReadService.markNewestMessageAsRead(streamId: widget.chatRoom['stream_id']);
        } catch (error) {
          print('Error marking newest message as read: $error');
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

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
      print('타임스탬프 변환 오류: $error');
      return 'Unknown';
    }
  }

  Future<void> _sendMessage() async {
    String messageContent = _messageController.text.trim();
    if (messageContent.isNotEmpty && _userId != null) {
      try {
        await sendMessageService.sendMessage(
          streamId: widget.chatRoom['stream_id'],
          messageContent: messageContent,
        );
        _messageController.clear();
        _scrollToBottom();
      } catch (error) {
        print('메시지 전송 실패: $error');
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, 'reload');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.chatRoom['name'] ?? 'No Title'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(color: Colors.red, thickness: 1.0),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  bool isMe = message['sender_id'] == _userId;

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.purple.shade200,
                          ),
                          SizedBox(width: 8),
                        ],
                        Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.pink.shade100 : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              constraints: BoxConstraints(maxWidth: 200),
                              child: Text(
                                message['content'] ?? '',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _formatTime(message['date_sent'] ?? 0),
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.red),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

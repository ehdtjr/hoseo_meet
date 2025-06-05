import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../navigation/presentation/pages/main_tab_page.dart';
import '../../providers/chat_bot_provicer.dart';

class ChatBotPage extends ConsumerStatefulWidget {
  final bool sendHello;

  const ChatBotPage({super.key, this.sendHello = false});

  @override
  ConsumerState<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends ConsumerState<ChatBotPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  static const double _scrollThreshold = 200;

  bool _hasSentInitialMessage = false;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasSentInitialMessage && widget.sendHello) {
        ref.read(chatNotifierProvider.notifier).sendMessage('안녕하세요', showInUI: false);
        _hasSentInitialMessage = true;
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(chatNotifierProvider.notifier).sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return false;
    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    return (maxScroll - offset) < _scrollThreshold;
  }

  void _showTagCompleteDialog(BuildContext context) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, animation, __, ___) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.tag, color: Color(0xFFE72410)),
                SizedBox(width: 8),
                Text('태그 생성 완료', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              '대화를 바탕으로 맞춤 태그를 생성했어요.\n이제 메인 화면으로 이동합니다.',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MainTabPage()),
                  );
                },
                child: const Text('확인', style: TextStyle(color: Color(0xFFE72410))),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider);
    final messages = chatState.messages;
    final isStreaming = chatState.isStreaming;
    final isFinished = chatState.isFinished;

    ref.listen(chatNotifierProvider, (prev, next) {
      if (prev == null || next.messages.length > prev.messages.length) {
        if (_isNearBottom()) _scrollToBottom();
      }

      if (next.isFinished && !_dialogShown) {
        _dialogShown = true;
        _showTagCompleteDialog(context);
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainTabPage()),
            );
          },
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Echo',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              '대화를 통해 태그를 매칭합니다',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: messages.length,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                itemBuilder: (context, index) {
                  final m = messages[index];
                  if (m.role == 'system') {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          m.content,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  final isUser = m.role == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.pink.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                          bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        m.content,
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: isStreaming || isFinished,
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: TextStyle(
                          color: (isStreaming || isFinished) ? Colors.grey : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: (isStreaming || isFinished)
                              ? '대화가 종료되었습니다.'
                              : '메시지를 입력하세요',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          filled: true,
                          fillColor: (isStreaming || isFinished)
                              ? Colors.grey.shade200
                              : Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: (isStreaming || isFinished)
                                  ? Colors.grey
                                  : Colors.black38,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: (isStreaming || isFinished)
                                  ? Colors.grey
                                  : const Color(0xFFE72410),
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: (isStreaming || isFinished) ? null : _sendMessage,
                    icon: (isStreaming || isFinished)
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                      ),
                    )
                        : const Icon(Icons.send, color: Color(0xFFE72410)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

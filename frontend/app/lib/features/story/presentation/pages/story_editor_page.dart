import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/story_post.dart';
import '../../providers/story_post_provider.dart';

class StoryEditorPage extends ConsumerStatefulWidget {
  const StoryEditorPage({super.key});

  @override
  ConsumerState<StoryEditorPage> createState() => _StoryEditorPageState();
}

class _StoryEditorPageState extends ConsumerState<StoryEditorPage> {
  static const int maxTextLength = 20;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Offset _textPosition = const Offset(50, 50);
  double _textScale = 1.0;
  bool _isEditing = false;
  Color _selectedColor = Colors.white;
  double _selectedFontSize = 20;
  double _baseScale = 1.0;

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleImageTap(TapDownDetails details) {
    if (_textController.text.isEmpty) {
      setState(() {
        _textPosition = details.localPosition;
        _isEditing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
      });
    } else {
      _focusNode.unfocus();
      setState(() {
        _isEditing = false;
      });
    }
  }

  Future<void> _submitStory() async {
    final uploadedImageUrl = ref.read(uploadedImageUrlProvider);
    if (uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 이미지가 없습니다.")),
      );
      return;
    }

    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 텍스트를 입력해주세요.")),
      );
      return;
    }

    final storyPostNotifier = ref.read(storyPostProvider.notifier);

    try {
      final textOverlay = TextOverlay(
        text: _textController.text,
        position: Position(
          x: _textPosition.dx,
          y: _textPosition.dy,
        ),
        fontStyle: FontStyle(
          name: "Arial",
          size: _selectedFontSize.toInt(),
          bold: true,
          color: _selectedColor.value.toRadixString(16),
        ),
      );

      final newPost = await storyPostNotifier.createStoryPost(
        CreateStoryPost(
          imageUrl: uploadedImageUrl,
          textOverlay: textOverlay,
        ),
      );

      if (newPost != null) {
        ref.read(uploadedImageUrlProvider.notifier).state = null;
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ 스토리 업로드 성공!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ 스토리 업로드 실패")),
        );
      }
    } catch (e) {
      debugPrint("스토리 업로드 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 스토리 업로드 중 오류가 발생했습니다.")),
      );
    }
  }

  void _toggleTextEdit() {
    if (_textController.text.isNotEmpty) {
      setState(() {
        _isEditing = true;
        _focusNode.requestFocus();
      });
    }
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 200,
        child: GridView.count(
          crossAxisCount: 5,
          children: [
            Colors.white,
            Colors.black,
            Colors.red,
            Colors.blue,
            Colors.green,
            Colors.yellow,
            Colors.purple,
            Colors.orange,
            Colors.pink,
            Colors.teal,
          ].map((color) => GestureDetector(
            onTap: () {
              setState(() {
                _selectedColor = color;
              });
              Navigator.pop(context);
            },
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: color == _selectedColor ? 2 : 0,
                ),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.text_fields, color: Colors.white),
                  onPressed: _toggleTextEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.color_lens, color: Colors.white),
                  onPressed: _showColorPicker,
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _submitStory,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextArea() {
    if (_isEditing) {
      return Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 0,
        right: 0,
        child: TextField(
          controller: _textController,
          focusNode: _focusNode,
          style: TextStyle(
            color: _selectedColor,
            fontSize: _selectedFontSize,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
          ),
          textAlign: TextAlign.center,
          autofocus: true,
          onSubmitted: (value) {
            setState(() {
              _isEditing = false;
              _focusNode.unfocus();
            });
          },
          onChanged: (value) {
            if (value.length > maxTextLength) {
              _textController.text = value.substring(0, maxTextLength);
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: maxTextLength),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("❌ 최대 20자까지 입력 가능합니다.")),
              );
            }
            setState(() {});
          },
        ),
      );
    } else if (_textController.text.isNotEmpty) {
      return Positioned(
        left: _textPosition.dx,
        top: _textPosition.dy,
        child: GestureDetector(
          onScaleStart: (details) {
            _baseScale = _textScale;
            _focusNode.unfocus();
          },
          onScaleUpdate: (details) {
            setState(() {
              _textPosition += details.focalPointDelta;
              if (details.pointerCount == 2) {
                _textScale = (_baseScale * details.scale).clamp(0.5, 3.0);
                _selectedFontSize = 20 * _textScale;
              }
            });
          },
          onDoubleTap: () {
            setState(() {
              _isEditing = true;
              _focusNode.requestFocus();
            });
          },
          child: Container(
            padding: EdgeInsets.all(40),
            color: Colors.transparent,
            child: Text(
              _textController.text,
              style: TextStyle(
                color: _selectedColor,
                fontSize: _selectedFontSize,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final uploadedImageUrl = ref.watch(uploadedImageUrlProvider);

    if (uploadedImageUrl == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          _focusNode.unfocus();
          setState(() {
            _isEditing = false;
          });
        },
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                uploadedImageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: _handleImageTap,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
              _buildTextArea(),
              _buildTopToolbar(),
            ],
          ),
        ),
      ),
    );
  }
}

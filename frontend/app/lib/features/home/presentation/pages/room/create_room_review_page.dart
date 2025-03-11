import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/room/review/room_review_provider.dart';
import '../../widgets/room_page/create/image_add_section.dart';
import '../../widgets/room_page/create/review_content_input.dart';
import '../../widgets/room_page/create/star_rating.dart';
import '../../widgets/room_page/create/submit_button.dart';

class CreateRoomReviewPage extends ConsumerStatefulWidget {
  final String roomId; // roomId가 String으로 전달됨
  const CreateRoomReviewPage({Key? key, required this.roomId}) : super(key: key);

  @override
  ConsumerState<CreateRoomReviewPage> createState() =>
      _CreateRoomReviewPageState();
}

class _CreateRoomReviewPageState extends ConsumerState<CreateRoomReviewPage> {
  final _contentController = TextEditingController();
  double _selectedRating = 3.0; // 초기 평점
  final List<String> _selectedImageUrls = [];

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _showMessageDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          )
        ],
      ),
    );
  }

  Future<void> _onSubmit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showMessageDialog("리뷰 내용을 입력해주세요.");
      return;
    }
    // 선택된 이미지 경로들을 File 객체 리스트로 변환
    final imagesFiles = _selectedImageUrls.map((path) => File(path)).toList();

    // widget.roomId가 String이므로 int로 변환합니다.
    final roomIdInt = int.tryParse(widget.roomId) ?? 0;
    try {
      await ref
          .read(roomReviewProvider(roomIdInt).notifier)
          .createRoomReview(
        content: content,
        rating: _selectedRating.toInt(), // 평점은 int로 전환
        images: imagesFiles,
      );
      _showMessageDialog("리뷰 작성 완료");
      // 성공 후 추가 동작 (예: 이전 페이지로 이동 등)
    } catch (e) {
      _showMessageDialog("리뷰 작성 중 오류가 발생했습니다.\n$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('리뷰 작성', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 별점 선택 영역
              Container(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '평점',
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StarRatingWidget(
                      initialRating: _selectedRating,
                      onRatingChanged: (rating) {
                        setState(() {
                          _selectedRating = rating;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 리뷰 내용 입력 영역
              Container(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ReviewContentLabel(label: '리뷰 내용을 입력하세요.'),
                    const SizedBox(height: 20),
                    ReviewContentInput(controller: _contentController),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 이미지 추가 영역
              Container(
                padding: const EdgeInsets.all(10),
                child: ImageAddSection(
                  selectedImageUrls: _selectedImageUrls,
                  onImagesSelected: (List<String> newImages) {
                    setState(() {
                      _selectedImageUrls
                        ..clear()
                        ..addAll(newImages);
                    });
                  },
                ),
              ),
              const SizedBox(height: 30),
              // 제출 버튼 영역
              Container(
                padding: const EdgeInsets.all(10),
                child: Center(
                  child: SubmitButton(
                    text: '작성하기',
                    onPressed: _onSubmit,
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

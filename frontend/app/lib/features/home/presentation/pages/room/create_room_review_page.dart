import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../commons/file/image_utils.dart';
import '../../../providers/room/review/room_review_provider.dart';
import '../../widgets/room_page/review/create/image_add_section.dart';
import '../../widgets/room_page/review/create/review_content_input.dart';
import '../../widgets/room_page/review/create/star_rating.dart';
import '../../widgets/room_page/review/create/submit_button.dart';


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

  Future<void> _onSubmit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("리뷰 내용을 입력해주세요.")),
      );
      return;
    }

    final List<File> imageFiles = [];
    for (final path in _selectedImageUrls) {
      final originalFile = File(path);
      final webpFile = await ensureWebP(originalFile);
      imageFiles.add(webpFile);
    }

    final roomIdInt = int.tryParse(widget.roomId) ?? 0;

    try {
      await ref.read(roomReviewProvider(roomIdInt).notifier).createRoomReview(
        content: content,
        rating: _selectedRating.toInt(),
        images: imageFiles,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("리뷰 작성 완료")),
      );
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.of(context).pop();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("리뷰 작성 중 오류가 발생했습니다.\n$e")),
      );
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

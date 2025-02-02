import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../providers/story_post_provider.dart';
import '../pages/gallery_selction.dart';
import '../pages/story_editor_page.dart';
import 'dash_circle_painter.dart';

class AddNewCircularImageWidget extends ConsumerStatefulWidget {
  const AddNewCircularImageWidget({super.key});

  @override
  ConsumerState<AddNewCircularImageWidget> createState() => _AddNewCircularImageWidgetState();
}

class _AddNewCircularImageWidgetState extends ConsumerState<AddNewCircularImageWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _requestPermissionAndOpenGallery,
      child: SizedBox(
        width: 74,
        height: 74,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: const Size(74, 74), painter: DashedCirclePainter()),
            Container(
              width: 67.57,
              height: 67.57,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE72410).withOpacity(0.05),
              ),
              child: const Center(
                child: Icon(Icons.add, color: Color(0xFFE72410), size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPermissionAndOpenGallery() async {
    final permissionState = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );

    if (!mounted) return;

    if (permissionState.isAuth || permissionState.hasAccess) {
      await _openGallery();
    } else {
      _showPermissionRequestDialog();
    }
  }



  Future<void> _openGallery() async {
    if (!mounted) return;

    final selectedFile = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GallerySelectionPage()),
    );

    if (!mounted || selectedFile == null) return;

    final storyPostNotifier = ref.read(storyPostProvider.notifier);
    File file = File(selectedFile);

    try {
      String? uploadedImageUrl = await storyPostNotifier.uploadStoryImage(file);
      if (!mounted) return;

      if (uploadedImageUrl != null) {
        ref.read(uploadedImageUrlProvider.notifier).state = uploadedImageUrl;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StoryEditorPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ 이미지 업로드 실패")),
        );
      }
    } catch (e) {
      debugPrint('이미지 업로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 이미지 업로드 중 오류가 발생했습니다.")),
      );
    }
  }

  void _showPermissionRequestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("갤러리 접근 권한"),
        content: const Text("이미지 업로드를 위해 갤러리 접근 권한이 필요합니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("취소")),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await PhotoManager.openSetting();
            },
            child: const Text("설정으로 이동"),
          ),
        ],
      ),
    );
  }
}

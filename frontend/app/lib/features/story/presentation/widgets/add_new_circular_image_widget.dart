import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/story/presentation/pages/gallery_selction.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/story_post_provider.dart';
import 'dash_circle_painter.dart';

class AddNewCircularImageWidget extends StatefulWidget {
  const AddNewCircularImageWidget({super.key});

  @override
  State<AddNewCircularImageWidget> createState() => _AddNewCircularImageWidgetState();
}

class _AddNewCircularImageWidgetState extends State<AddNewCircularImageWidget> {
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
            CustomPaint(
              size: const Size(74, 74),
              painter: DashedCirclePainter(),
            ),
            Container(
              width: 67.57,
              height: 67.57,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE72410).withOpacity(0.05),
              ),
              child: const Center(
                child: Icon(
                  Icons.add,
                  color: Color(0xFFE72410),
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPermissionAndOpenGallery() async {
    try {
      // 현재 권한 상태 확인
      if (Platform.isAndroid) {
        final photosStatus = await Permission.photos.status;
        final storageStatus = await Permission.storage.status;
        debugPrint('현재 권한 상태: photos=${photosStatus}, storage=${storageStatus}');
      }

      final permission = await PhotoManager.requestPermissionExtend();
      debugPrint('PhotoManager 권한 상태: ${permission.isAuth}');

      if (!mounted) return;

      if (permission.isAuth) {
        await _openGallery();
      } else {
        if (Platform.isAndroid) {
          // Android 13 이상
          if (await Permission.photos.request().isGranted) {
            await _openGallery();
            return;
          }
          // Android 12 이하
          if (await Permission.storage.request().isGranted) {
            await _openGallery();
            return;
          }
        } else {
          // iOS
          if (await Permission.photos.request().isGranted) {
            await _openGallery();
            return;
          }
        }
        _showPermissionRequestDialog();
      }
    } catch (e, stackTrace) {
      debugPrint('권한 요청 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("권한 요청 중 오류가 발생했습니다.")),
      );
    }
  }

  void _showPermissionRequestDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("갤러리 접근 권한"),
        content: const Text("이미지 업로드를 위해 갤러리 접근 권한이 필요합니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (Platform.isAndroid) {
                // Android 13 이상
                final photosResult = await Permission.photos.request();
                if (!mounted) return;

                if (photosResult.isGranted) {
                  await _openGallery();
                  return;
                }

                // Android 12 이하
                final storageResult = await Permission.storage.request();
                if (!mounted) return;

                if (storageResult.isGranted) {
                  await _openGallery();
                } else {
                  _showSettingsDialog();
                }
              } else {
                final result = await Permission.photos.request();
                if (!mounted) return;

                if (result.isGranted) {
                  await _openGallery();
                } else {
                  _showSettingsDialog();
                }
              }
            },
            child: const Text("권한 요청"),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("권한 설정"),
        content: const Text("갤러리 접근이 거부되었습니다.\n설정에서 권한을 허용해주세요."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openAppSettings();
            },
            child: const Text("설정으로 이동"),
          ),
        ],
      ),
    );
  }

  Future<void> _openGallery() async {
    if (!mounted) return;

    try {
      final List<AssetEntity> assets = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      ).then((List<AssetPathEntity> paths) => paths.isNotEmpty
          ? paths.first.getAssetListPaged(page: 0, size: 100)
          : []);

      if (!mounted) return;

      if (assets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ 갤러리에 이미지가 없습니다.")),
        );
        return;
      }

      final selectedFile = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const GallerySelectionPage(),
        ),
      );

      if (!mounted) return;
      if (selectedFile == null) return;

      File file = File(selectedFile);
      debugPrint("📌 선택된 이미지: ${file.path}");

      _showUploadDialog(file);
    } catch (e) {
      debugPrint('갤러리 열기 오류: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("갤러리를 여는 중 오류가 발생했습니다.")),
      );
    }
  }

  void _showUploadDialog(File file) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => Consumer(
        builder: (context, ref, child) {
          final storyPostNotifier = ref.read(storyPostProvider.notifier);

          return AlertDialog(
            title: const Text("이미지 업로드"),
            content: const Text("이 이미지를 업로드하시겠습니까?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("취소"),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    String? uploadedImageUrl =
                    await storyPostNotifier.uploadStoryImage(file);
                    if (!mounted) return;
                    Navigator.pop(dialogContext);

                    if (uploadedImageUrl != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("✅ 이미지 업로드 성공")),
                      );
                      storyPostNotifier.resetAndLoad();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("❌ 이미지 업로드 실패")),
                      );
                    }
                  } catch (e) {
                    debugPrint('이미지 업로드 오류: $e');
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("이미지 업로드 중 오류가 발생했습니다.")),
                    );
                  }
                },
                child: const Text("업로드"),
              ),
            ],
          );
        },
      ),
    );
  }
}

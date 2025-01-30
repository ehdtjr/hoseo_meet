import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../providers/story_post_provider.dart';
import '../pages/story_editor_page.dart';

class GallerySelectionPage extends ConsumerStatefulWidget {
  const GallerySelectionPage({super.key});

  @override
  _GallerySelectionPageState createState() => _GallerySelectionPageState();
}

class _GallerySelectionPageState extends ConsumerState<GallerySelectionPage> {
  List<AssetEntity> images = [];
  AssetEntity? selectedImage;
  final Map<String, Uint8List?> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _loadGalleryImages();
  }

  Future<void> _loadGalleryImages() async {
    try {
      await PhotoManager.setIgnorePermissionCheck(true);

      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );

      if (!permission.isAuth && !permission.hasAccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ 갤러리 접근 권한이 필요합니다.")),
        );
        return;
      }

      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        hasAll: true,
      );

      if (albums.isNotEmpty) {
        final recentAlbum = albums.first;
        final List<AssetEntity> assets = await recentAlbum.getAssetListPaged(
          page: 0,
          size: 100,
        );

        if (mounted) {
          setState(() {
            images = assets;
          });
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ 갤러리에 이미지가 없습니다.")),
        );
      }
    } catch (e) {
      debugPrint('갤러리 로드 오류: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("갤러리 로드 중 오류가 발생했습니다.")),
      );
    }
  }

  Future<Uint8List?> _getThumbnail(AssetEntity asset) async {
    if (_thumbnailCache.containsKey(asset.id)) {
      return _thumbnailCache[asset.id];
    }

    final thumbnail = await asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
      quality: 100,
      format: ThumbnailFormat.jpeg,
    );

    if (thumbnail != null) {
      await precacheImage(MemoryImage(thumbnail), context);
      _thumbnailCache[asset.id] = thumbnail;
    }
    return thumbnail;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("갤러리에서 선택"),
        actions: [
          if (selectedImage != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () async {
                try {
                  final File? file = await selectedImage!.file;
                  if (file != null && mounted) {
                    // 업로드 후 StoryEditorPage로 직접 이동
                    final storyPostNotifier = ref.read(storyPostProvider.notifier);
                    String? uploadedImageUrl = await storyPostNotifier.uploadStoryImage(file);

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
                  }
                } catch (e) {
                  debugPrint('파일 변환 오류: $e');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("이미지 선택 중 오류가 발생했습니다.")),
                  );
                }
              },
            ),
        ],
      ),
      body: images.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        cacheExtent: 1000,
        itemCount: images.length,
        itemBuilder: (context, index) {
          final asset = images[index];
          return RepaintBoundary(
            child: FutureBuilder<Uint8List?>(
              future: _getThumbnail(asset),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) return const SizedBox();

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedImage = asset;
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        cacheWidth: 200,
                        cacheHeight: 200,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) return child;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: frame != null ? child : Container(color: Colors.grey[200]),
                          );
                        },
                      ),
                      if (selectedImage == asset)
                        Container(
                          color: Colors.black.withOpacity(0.3),
                          child: const Center(
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _thumbnailCache.clear();
    super.dispose();
  }
}

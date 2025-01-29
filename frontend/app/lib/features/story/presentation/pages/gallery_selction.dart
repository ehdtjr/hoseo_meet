import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class GallerySelectionPage extends StatefulWidget {
  const GallerySelectionPage({super.key});

  @override
  _GallerySelectionPageState createState() => _GallerySelectionPageState();
}

class _GallerySelectionPageState extends State<GallerySelectionPage> {
  List<AssetEntity> images = [];
  AssetEntity? selectedImage;

  @override
  void initState() {
    super.initState();
    _loadGalleryImages();
  }

  /// ✅ 갤러리에서 이미지 목록 가져오기
  Future<void> _loadGalleryImages() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 갤러리 접근 권한이 필요합니다.")),
      );
      return;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );

    if (albums.isNotEmpty) {
      final List<AssetEntity> assets =
      await albums.first.getAssetListPaged(page: 0, size: 100);

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("갤러리에서 선택")),
      body: images.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final asset = images[index];
          return FutureBuilder<Uint8List?>(
            future: asset.thumbnailData,
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
                    Image.memory(snapshot.data!, fit: BoxFit.cover),
                    if (selectedImage == asset)
                      Container(
                        color: Colors.black.withOpacity(0.4),
                        child: const Center(
                          child: Icon(Icons.check_circle, color: Colors.white, size: 30),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (selectedImage == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("이미지를 선택해주세요.")),
            );
            return;
          }

          final File? file = await selectedImage!.file;
          if (file != null && mounted) {
            Navigator.pop(context, file.path);
          }
        },
        child: const Icon(Icons.check),
      ),
    );
  }
}

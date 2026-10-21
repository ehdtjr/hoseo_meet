import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class MenuImagePickerScreen extends StatefulWidget {
  const MenuImagePickerScreen({super.key});

  @override
  State<MenuImagePickerScreen> createState() => _MenuImagePickerScreenState();
}

class _MenuImagePickerScreenState extends State<MenuImagePickerScreen> {
  List<AssetEntity> images = [];
  final Map<String, Uint8List?> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final permission = await PhotoManager.requestPermissionExtend();

    if (!permission.isAuth && !permission.hasAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 갤러리 접근 권한이 필요합니다.")),
      );
      return;
    }

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return;

    final assets = await albums.first.getAssetListPaged(page: 0, size: 100);
    setState(() {
      images = assets;
    });
  }

  Future<Uint8List?> _getThumbnail(AssetEntity asset) async {
    if (_thumbnailCache.containsKey(asset.id)) return _thumbnailCache[asset.id];

    final data = await asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    _thumbnailCache[asset.id] = data;
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("메뉴 이미지 선택")),
      body: images.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final asset = images[index];
          return FutureBuilder<Uint8List?>(
            future: _getThumbnail(asset),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return GestureDetector(
                onTap: () async {
                  final file = await asset.file;
                  if (file != null && mounted) {
                    Navigator.pop(context, file.path); // 이미지 경로 반환
                  }
                },
                child: Image.memory(snapshot.data!, fit: BoxFit.cover),
              );
            },
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

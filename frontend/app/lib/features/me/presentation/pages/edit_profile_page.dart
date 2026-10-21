import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../commons/file/image_utils.dart';
import '../../../auth/providers/user_profile_provider.dart';
import '../../../home/presentation/widgets/room_page/review/create/gallery_picker_screen.dart';

class EditProfileImagePage extends ConsumerStatefulWidget {
  const EditProfileImagePage({super.key});

  @override
  ConsumerState<EditProfileImagePage> createState() => _EditProfileImagePageState();
}

class _EditProfileImagePageState extends ConsumerState<EditProfileImagePage> {
  String? _selectedImagePath;
  bool _isUploading = false;

  Future<void> _openGalleryPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GalleryPickerScreen()),
    );

    if (result != null && result is List<String> && result.isNotEmpty) {
      setState(() {
        _selectedImagePath = result.first;
      });
    }
  }

  Future<void> _saveImage() async {
    if (_selectedImagePath == null) return;
    setState(() => _isUploading = true);

    try {
      final originalFile = File(_selectedImagePath!);
      final fileToUpload = await ensureWebP(originalFile);

      await ref.read(userProfileNotifierProvider.notifier).uploadProfileImage(fileToUpload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 이미지가 변경되었습니다')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 업로드 중 오류가 발생했습니다')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _selectedImagePath != null ? FileImage(File(_selectedImagePath!)) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 이미지 변경'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _openGalleryPicker,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 90,
                      backgroundColor: const Color(0xFFE0E0E0),
                      backgroundImage: image,
                      child: image == null
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(Icons.camera_alt_outlined, size: 20, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedImagePath != null && !_isUploading ? _saveImage : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedImagePath != null
                        ? const Color(0xFFE72410)
                        : Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isUploading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text(
                    '저장',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white, // 🔧 수정: 조화로운 색상
                    ),
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

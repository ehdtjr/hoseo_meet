import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'gallery_picker_screen.dart';

class ImageAddSection extends StatelessWidget {
  final List<String> selectedImageUrls;
  final ValueChanged<List<String>> onImagesSelected;

  const ImageAddSection({
    Key? key,
    required this.selectedImageUrls,
    required this.onImagesSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이미지 추가',
          style: TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // 이미지 추가 버튼
              GestureDetector(
                onTap: () async {
                  // GalleryPickerScreen로 이동하여 다중 이미지 선택 후 결과(파일 경로 리스트)를 받음
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GalleryPickerScreen(),
                    ),
                  );
                  if (result != null && result is List<String>) {
                    onImagesSelected(result);
                  }
                },
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_a_photo, size: 30, color: Colors.grey),
                        SizedBox(height: 4),
                        Text(
                          '이미지 추가',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 선택된 이미지 미리보기 리스트
              Row(
                children: selectedImageUrls.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(entry.value),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final list = List<String>.from(selectedImageUrls);
                              list.removeAt(entry.key);
                              onImagesSelected(list);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

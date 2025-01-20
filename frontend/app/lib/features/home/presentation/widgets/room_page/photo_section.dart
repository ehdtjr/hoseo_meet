import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'dart:math'; // 랜덤 높이를 위해 추가

class PhotoSection extends StatelessWidget {
  const PhotoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final random = Random(); // 랜덤 객체 생성
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "사진",
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        MasonryGridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
          ),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          itemCount: 20, // 더 많은 아이템
          itemBuilder: (context, index) {
            // 랜덤 높이를 설정
            final height = 80 + random.nextInt(100); // 80~180 사이의 랜덤 높이
            return Container(
              height: height.toDouble(),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image, color: Colors.white),
            );
          },
        ),
      ],
    );
  }
}

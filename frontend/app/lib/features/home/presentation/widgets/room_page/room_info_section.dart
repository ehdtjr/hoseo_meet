import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RoomInfoSection extends StatelessWidget {
  final String postId;

  const RoomInfoSection({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.min, // 콘텐츠 높이만큼만 차지하도록 설정
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center, // 아이콘과 텍스트 높이 정렬
            children: [
              SvgPicture.asset(
                'assets/icons/fi-rr-marker.svg', // 에셋 경로
                width: 12,
                height: 12,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '충남 아산시 배방읍 호서로79번길 14',
                  style: TextStyle(
                    color: Color(0xFF5F5F5F), // 텍스트 색상
                    fontSize: 13,
                    height: 1.66,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center, // 아이콘과 텍스트 높이 정렬
            children: [
              SvgPicture.asset(
                'assets/icons/phone.svg', // 에셋 경로
                width: 12,
                height: 12,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '0507-1469-2369',
                  style: TextStyle(
                    color: Color(0xFF5F5F5F), // 텍스트 색상
                    fontSize: 13,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    height: 1.66,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center, // 아이콘과 텍스트 높이 정렬
            children: [
              SvgPicture.asset(
                'assets/icons/fi-rr-info.svg', // 에셋 경로
                width: 12,
                height: 12,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '년세: 400 • 반년세: 200 • 보증금: 30',
                  style: TextStyle(
                    color: Color(0xFF5F5F5F), // 텍스트 색상
                    fontSize: 13,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    height: 1.66,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

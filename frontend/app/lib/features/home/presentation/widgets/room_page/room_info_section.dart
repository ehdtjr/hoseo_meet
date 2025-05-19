import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../data/models/room_post_detail.dart';

class RoomInfoSection extends StatelessWidget {
  final RoomDetail roomDetail;

  const RoomInfoSection({Key? key, required this.roomDetail}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.min, // 콘텐츠 높이만큼만 차지하도록 설정
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 주소 표시
          Row(
            crossAxisAlignment: CrossAxisAlignment.center, // 아이콘과 텍스트 높이 정렬
            children: [
              SvgPicture.asset(
                'assets/icons/fi-rr-marker.svg', // 에셋 경로
                width: 12,
                height: 12,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  roomDetail.address,
                  style: const TextStyle(
                    color: Color(0xFF5F5F5F), // 텍스트 색상
                    fontSize: 13,
                    height: 1.66,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 연락처 표시
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/phone.svg',
                width: 12,
                height: 12,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  roomDetail.contact,
                  style: const TextStyle(
                    color: Color(0xFF5F5F5F),
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
          // 가격, 보증금, 옵션 등의 추가 정보 표시
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/fi-rr-info.svg',
                width: 12,
                height: 12,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '가격: ${roomDetail.price} • 보증금: ${roomDetail.fee} • 옵션: ${roomDetail.options}',
                  style: const TextStyle(
                    color: Color(0xFF5F5F5F),
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

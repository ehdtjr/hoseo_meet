import 'package:flutter/material.dart';
import 'package:hoseomeet/features/home/presentation/widgets/home_map_widgets.dart'; // 가정
import 'package:hoseomeet/widgets/search_bar.dart';


class HomePage extends StatefulWidget { // Stateful로 변경 (탭 이동 시 setState)
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  Widget build(BuildContext context) {
    return
      Scaffold(
      // 지도와 기타 오버레이
      body: Stack(
        children: [
          // (1) 지도
          Positioned.fill(
            child: Container(
              color: Colors.grey[300],
              child: HomeMap(), // 실제론 NaverMap 등
            ),
          ),

          // (2) 상단 검색바 - (Positioned) / (만약 따로 Positioned로 두셨다면)
          const Positioned(
            top: 60,
            left: 24,
            right: 24,
            child: SearchBarWidget(), // 가정: 사용자 정의 검색바
          ),

          // (3) 카테고리 Row
          _buildCategoryRow(),

          // (4) PostList 영역
          // _buildPostList(),
        ]
      )
    );
  }
  Widget _buildCategoryRow() {
    return Positioned(
      top: 122,
      left: 24,
      right: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCategoryChip('자취방'),
            const SizedBox(width: 8),
            _buildCategoryChip('음식점'),
            const SizedBox(width: 8),
            _buildCategoryChip('카페'),
            const SizedBox(width: 8),
            _buildCategoryChip('술집'),
            const SizedBox(width: 8),
            _buildCategoryChip('편의점'),
            const SizedBox(width: 8),
            _buildCategoryChip('놀거리'),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(43),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x1C000000),
            blurRadius: 6.90,
          ),
        ],
      ),
      child: Row(
        children: [
          const FlutterLogo(size: 13),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              height: 1.60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 74, // leave space for bottom bar
      child: Container(
        height: 205,
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(36),
              topRight: Radius.circular(36),
            ),
          ),
        ),
        child: const Stack(
          children: [
            Positioned(
              left: 25,
              top: 47,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '지금 ',
                      style: TextStyle(
                        color: Color(0xFF2E2E2E),
                        fontSize: 21,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        height: 1.60,
                      ),
                    ),
                    TextSpan(
                      text: '소소',
                      style: TextStyle(
                        color: Color(0xFFE72410),
                        fontSize: 21,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        height: 1.60,
                      ),
                    ),
                    TextSpan(
                      text: '님을 기다리고 있어요!',
                      style: TextStyle(
                        color: Color(0xFF2E2E2E),
                        fontSize: 21,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        height: 1.60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ... 추가 게시글 목록
          ],
        ),
      ),
    );
  }
}

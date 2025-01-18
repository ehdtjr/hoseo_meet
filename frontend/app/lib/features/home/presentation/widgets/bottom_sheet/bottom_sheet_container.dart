import 'package:flutter/material.dart';
import 'package:hoseomeet/features/home/presentation/widgets/bottom_sheet/bottom_category_list/meet/meet_container.dart';
import '../../../data/models/category.dart';
import 'bottom_category_list/meet/meet_header.dart';
import 'bottom_category_list/room/room_header.dart'; // RoomHeaderWidget 임포트
import 'bottom_category_list/room/room_container.dart'; // RoomContainerWidget 임포트

class BottomSheetContainer extends StatelessWidget {
  final ScrollController scrollController;
  final Category? selectedCategory;
  final String userName;

  const BottomSheetContainer({
    super.key,
    required this.scrollController,
    required this.selectedCategory,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(36),
          topRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // ListView with fixed height
          Container(
            height: 100, // Fixed height for ListView
            width: double.infinity, // Full width
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 25),
              children: <Widget>[
                // Divider with custom padding
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  child: Center(
                    child: Container(
                      height: 2,
                      width: 168,
                      color: const Color(0xFFE72410),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 선택된 카테고리에 따라 다른 헤더 위젯 표시
                _buildHeaderWidget(), // 수정된 부분
              ],
            ),
          ),

          // 선택된 카테고리에 따라 다른 Container 위젯 표시
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: _buildContainerWidget(), // 수정된 부분
            ),
          ),
        ],
      ),
    );
  }

  /// 선택된 카테고리에 따라 적절한 헤더 위젯을 반환합니다.
  Widget _buildHeaderWidget() {
    switch (selectedCategory?.name) {
      case '자취방':
        return RoomHeaderWidget(userName: userName);
      default:
        return MeetHeaderWidget(userName: userName); // 기본값은 MeetHeaderWidget
    }
  }

  /// 선택된 카테고리에 따라 적절한 Container 위젯을 반환합니다.
  Widget _buildContainerWidget() {
    switch (selectedCategory?.name) {
      case '자취방':
        return const RoomContainerWidget(); // 자취방용 컨테이너
      default:
        return const MeetContainerWidget(); // 기본값은 MeetContainerWidget
    }
  }
}

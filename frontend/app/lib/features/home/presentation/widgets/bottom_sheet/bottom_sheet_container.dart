import 'package:flutter/material.dart';
import 'package:hoseomeet/features/home/presentation/widgets/bottom_sheet/bottom_category_list/meet/meet_container.dart';
import '../../../data/models/category.dart';
import 'bottom_category_list/meet/meet_header.dart';

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
            height: 90, // Fixed height for ListView
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
                MeetHeaderWidget(userName: userName),
              ],
            ),
          ),

          // MeetContainer widget occupies the remaining
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: MeetContainerWidget(),
            ),
          ),

        ],
      ),
    );
  }
}

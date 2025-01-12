import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// 기존 위젯 import
import '../../../chat/providers/chat_category_provider.dart';
import '../widgets/meet_page/meet_page_item.dart';
import '../widgets/meet_page/meet_page_serchbar.dart';
import '../widgets/meet_page/meet_circula_image_list.dart';
import '../widgets/meet_page/category_bar.dart';

class MeetPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: MeetSearchBarWidget(),
        ),
      ),
      body: Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, top: 15.0, bottom: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      child: MeetCircularImageList(),
                    ),
                    const SizedBox(height: 25),
                    CategoryBar(
                      selectedCategory: ChatCategory.all,
                      onCategorySelected: (category) {
                        print('Selected Category: $category');
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(
              height: 2,
              thickness: 2,
              color: Colors.red,
            ),
            Expanded(  // 남은 공간을 ListView가 차지하도록 Expanded로 감싸기
              child: ListView.builder(
                itemCount: 5,  // 임시로 5개 아이템 표시
                itemBuilder: (context, index) {
                  return MeetPageItem();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

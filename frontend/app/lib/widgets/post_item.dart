import 'package:flutter/material.dart';

// 게시글 아이템을 구성하는 함수
Widget buildPostItem(Map<String, dynamic> post) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 27.0), // 패딩 조정
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 카테고리 라벨
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red), // 빨간 테두리로 표시
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                post["type"],
                style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        // 제목
        Text(
          post["title"],
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        // 설명
        Text(
          post["content"],
          style: TextStyle(fontSize: 12 ,color: Colors.grey[600], fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        // 타임스탬프, 조회수, 참가자 수
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${formatTimestamp(post["created_at"])} · 조회 ${post["page_view"]}',
              style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Image.asset(
                  'assets/img/icon/joinuser.png',
                  width: 16,
                  height: 16,
                ),
                SizedBox(width: 4),
                Text(
                  '${post["join_people"]}/${post["max_people"]}',
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        Divider(color: Colors.red, thickness: 1.0), // 게시글 분리선
      ],
    ),
  );
}

// 타임스탬프 포맷팅 함수
String formatTimestamp(String timestamp) {
  DateTime postDate = DateTime.parse(timestamp);
  DateTime now = DateTime.now();
  Duration difference = now.difference(postDate);

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}분 전';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}시간 전';
  } else {
    return '${difference.inDays}일 전';
  }
}

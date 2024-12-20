import 'package:flutter/material.dart';
import '../api/meet/chatroom_join_service.dart';

class MeetPostModal extends StatelessWidget {
  final Map<String, dynamic> post;
  final ChatroomJoinService _chatroomJoinService = ChatroomJoinService();

  MeetPostModal({required this.post});

  String _getCategoryName(String type) {
    switch (type) {
      case "meet":
        return "모임";
      case "delivery":
        return "배달";
      case "taxi":
      case "carpool":
        return "택시·카풀";
      default:
        return "기타";
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: AssetImage('assets/img/profile-placeholder.png'),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'zeongh134',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Spacer(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getCategoryName(post['type'] ?? ""),
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      SizedBox(height: 4),
                      Icon(Icons.more_horiz, color: Colors.grey),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Divider(color: Colors.red, thickness: 1.0),
              Text(
                post['title'],
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(post['content']),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '${formatTimestamp(post["created_at"])} · 조회 ${post["page_views"]}',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        '${post["join_people"] ?? 0}/${post["max_people"]}명',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _chatroomJoinService.joinChatroom(
                          postId: post['id'], // `postId`로 수정된 부분
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('채팅방 참여 성공')),
                        );
                      } catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('참여 실패: $error')),
                        );
                      } finally {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      '참여하기',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

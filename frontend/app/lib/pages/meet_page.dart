import 'package:flutter/material.dart';
import '../widgets/category_button.dart';
import 'create_post_page.dart';
import '../api/meet/meet_search_service.dart';

class MeetPage extends StatefulWidget {
  @override
  _MeetPageState createState() => _MeetPageState();
}

class _MeetPageState extends State<MeetPage> {
  String selectedCategory = "전체"; // 초기 선택된 카테고리
  List<Map<String, dynamic>> posts = []; // API에서 불러온 게시글 리스트
  bool isLoading = true; // 로딩 상태

  final MeetSearchService _meetSearchService = MeetSearchService();

  @override
  void initState() {
    super.initState();
    _fetchPosts(); // 페이지 로드 시 API 호출
  }

  Future<void> _fetchPosts({String? type}) async {
    setState(() {
      isLoading = true;
    });
    try {
      List<Map<String, dynamic>> fetchedPosts = await _meetSearchService.fetchPosts(type: type);
      setState(() {
        posts = fetchedPosts;
      });
    } catch (error) {
      print('게시글을 불러오는데 실패했습니다: $error');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showPostDetail(Map<String, dynamic> post) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
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
                        onPressed: () {
                          Navigator.of(context).pop();
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
      },
    );
  }

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

  void _onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
    });
    String? type;
    if (category == "모임") type = "meet";
    else if (category == "배달") type = "delivery";
    else if (category == "택시·카풀") type = "taxi-carpool";
    _fetchPosts(type: type);
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            height: 40,
            child: TextField(
              decoration: InputDecoration(
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    'assets/img/icon/search-icon.png',
                    width: 24,
                    height: 24,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                isDense: true,
              ),
            ),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4.0,
                  offset: Offset(0, 2),
                ),
              ],
              borderRadius: BorderRadius.circular(25.0),
            ),
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 35,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  CategoryButton(
                    text: "전체",
                    isSelected: selectedCategory == "전체",
                    onPressed: () {
                      _onCategorySelected("전체");
                    },
                  ),
                  CategoryButton(
                    text: "모임",
                    isSelected: selectedCategory == "모임",
                    onPressed: () {
                      _onCategorySelected("모임");
                    },
                  ),
                  CategoryButton(
                    text: "배달",
                    isSelected: selectedCategory == "배달",
                    onPressed: () {
                      _onCategorySelected("배달");
                    },
                  ),
                  CategoryButton(
                    text: "택시·카풀",
                    isSelected: selectedCategory == "택시·카풀",
                    onPressed: () {
                      _onCategorySelected("택시·카풀");
                    },
                  ),
                ],
              ),
            ),
            Divider(color: Colors.red, thickness: 1.0),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return GestureDetector(
                  onTap: () {
                    _showPostDetail(post);
                  },
                  child: _buildPostItem(post),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreatePostPage()),
          );
        },
        child: Image.asset(
          'assets/img/icon/meet-postadd.png',
          width: 48,
          height: 48,
        ),
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 27.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getCategoryName(post["type"] ?? ""),
                  style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            post["title"],
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            post["content"],
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatTimestamp(post["created_at"])} · 조회 ${post["page_views"]}',
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
                    '${post["join_people"] ?? 0}/${post["max_people"]}',
                    style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          Divider(color: Colors.red, thickness: 1.0),
        ],
      ),
    );
  }
}

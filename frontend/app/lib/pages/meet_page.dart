import 'package:flutter/material.dart';
import '../widgets/category_button.dart';
import '../widgets/meet_searchbar.dart';
import '../widgets/meet_post_list.dart'; // MeetPostList import
import 'create_post_page.dart';
import '../api/meet/meet_search_service.dart';
import '../widgets/meet_post_modal.dart';

class MeetPage extends StatefulWidget {
  @override
  _MeetPageState createState() => _MeetPageState();
}

class _MeetPageState extends State<MeetPage> {
  String selectedCategory = "전체";
  List<Map<String, dynamic>> posts = [];
  bool isLoading = true;
  final MeetSearchService _meetSearchService = MeetSearchService();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPosts();
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
        return MeetPostModal(post: post);
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
        title: MeetSearchBar(controller: _searchController),
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
            MeetPostList(
              posts: posts,
              onTap: _showPostDetail,
              getCategoryName: _getCategoryName,
              formatTimestamp: formatTimestamp,
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
}

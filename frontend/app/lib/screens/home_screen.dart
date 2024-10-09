import 'package:flutter/material.dart';
import '../pages/home_page.dart';
import '../pages/meet_page.dart';
import '../pages/chat_page.dart';
import '../pages/profile_page.dart';
import '../widgets/custom_bottom_navigation_bar_item.dart'; // CustomBottomNavigationBarItem 가져오기

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    MeetPage(),
    ChatPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize( //appbar 삭제
        child: AppBar(),
        preferredSize: Size.fromHeight(0),

      ),
      // appBar: AppBar(
      //   elevation: 0, // AppBar의 기본 그림자 제거
      //   scrolledUnderElevation: 0, // 스크롤 시에도 그림자가 생기지 않도록 설정
      //   automaticallyImplyLeading: false, // 뒤로가기 화살표 숨김
      // ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 아이콘 확대 효과 제거
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        unselectedLabelStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold), // 라벨 크기 줄이고 굵게 설정
        selectedLabelStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold), // 라벨 크기 줄이고 굵게 설정
        selectedItemColor: Color(0xFFE72410), // 활성화된 아이템의 라벨 색상 설정
        unselectedItemColor: Colors.grey, // 비활성화된 아이템의 라벨 색상 설정
        items: [
          CustomBottomNavigationBarItem.build(
            assetPath: 'assets/img/icon/home.png',
            activeAssetPath: 'assets/img/icon/homered.png',
            label: 'HOME',
            isActive: _currentIndex == 0,
          ),
          CustomBottomNavigationBarItem.build(
            assetPath: 'assets/img/icon/meet.png',
            activeAssetPath: 'assets/img/icon/meetred.png',
            label: 'MEET',
            isActive: _currentIndex == 1,
          ),
          CustomBottomNavigationBarItem.build(
            assetPath: 'assets/img/icon/chat.png',
            activeAssetPath: 'assets/img/icon/chatred.png',
            label: 'CHAT',
            isActive: _currentIndex == 2,
          ),
          CustomBottomNavigationBarItem.build(
            assetPath: 'assets/img/icon/me.png',
            activeAssetPath: 'assets/img/icon/mered.png',
            label: 'ME',
            isActive: _currentIndex == 3,
          ),
        ],
      ),
    );
  }
}

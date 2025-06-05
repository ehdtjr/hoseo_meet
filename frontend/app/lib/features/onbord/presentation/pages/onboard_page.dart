import 'package:campusmeet/features/chat_bot/presentation/pages/chat_bot_page.dart';
import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatelessWidget {
  void _onIntroEnd(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ChatBotPage(sendHello: true)),
    );
  }

  // 첫 번째 페이지: 이미지 사용
  PageViewModel _buildPageWithImage({
    required String imagePath,
    required String subtitle,
  }) {
    return PageViewModel(
      titleWidget: Padding(
        padding: const EdgeInsets.only(top: 48.0, bottom: 24.0),
        child: Column(
          children: [
            Image.asset(
              imagePath,
              height: 160,
            ),
            const SizedBox(height: 24),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      bodyWidget: const SizedBox.shrink(),
      decoration: const PageDecoration(
        imageFlex: 0,
        bodyFlex: 1,
        footerFlex: 0,
        bodyAlignment: Alignment.center,
        contentMargin: EdgeInsets.symmetric(horizontal: 32),
      ),
    );
  }

  // 일반 페이지: 아이콘 사용
  PageViewModel _buildPage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return PageViewModel(
      titleWidget: Padding(
        padding: const EdgeInsets.only(top: 48.0, bottom: 24.0),
        child: Column(
          children: [
            Icon(icon, size: 80, color: Color(0xFFE72410)),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      bodyWidget: const SizedBox.shrink(),
      decoration: const PageDecoration(
        imageFlex: 0,
        bodyFlex: 1,
        footerFlex: 0,
        bodyAlignment: Alignment.center,
        contentMargin: EdgeInsets.symmetric(horizontal: 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: Colors.white, // 완전 흰색 배경
      pages: [
        _buildPageWithImage(
          imagePath: 'assets/img/login_logo.png',
          subtitle: '가까운 거리에서, 가까운 사람들과\n자연스럽게 연결돼보세요.',
        ),
        _buildPage(
          icon: Icons.location_on_outlined,
          title: '실시간 위치 기반 탐색',
          subtitle: '지도를 통해 내 주변 자취방 정보를\n한눈에 확인할 수 있어요.',
        ),
        _buildPage(
          icon: Icons.groups_2_outlined,
          title: '커뮤니티와 소통',
          subtitle: '스토리 기능으로\n일상과 생각을 자연스럽게 나눠보세요.',
        ),
        _buildPage(
          icon: Icons.chat_bubble_outline_rounded,
          title: '실시간 채팅 기능',
          subtitle: '궁금한 점은 바로 채팅!\n직접 대화하며 빠르게 해결해요.',
        ),
      ],
      onDone: () => _onIntroEnd(context),
      showSkipButton: true,
      skip: const Text("건너뛰기", style: TextStyle(color: Colors.grey)),
      next: const Icon(Icons.east_rounded, color: Color(0xFFE72410), size: 28),
      done: const Text(
        "시작하기",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFFE72410),
        ),
      ),
      dotsDecorator: const DotsDecorator(
        size: Size(8, 8),
        activeSize: Size(20, 8),
        activeColor: Color(0xFFE72410),
        color: Colors.grey,
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
    );
  }
}

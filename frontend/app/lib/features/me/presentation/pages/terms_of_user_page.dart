import 'package:flutter/material.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이용규칙'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. 목적',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '본 이용규칙은 커뮤니티 서비스 이용에 있어 회원 간의 원활한 소통과 건전한 커뮤니티 문화를 조성하기 위한 기본적인 기준을 제공합니다.',
              ),
              SizedBox(height: 20),
              Text(
                '2. 회원의 의무',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• 타인의 권리를 침해하거나 불쾌감을 주는 행위를 하지 않습니다.\n'
                    '• 커뮤니티 내에서 예의 바른 언행을 유지합니다.\n'
                    '• 허위정보 또는 광고성 게시물을 게재하지 않습니다.\n'
                    '• 서비스의 정상적인 운영을 방해하지 않습니다.',
              ),
              SizedBox(height: 20),
              Text(
                '3. 금지 행위',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '다음 행위는 금지되며, 적발 시 사전 통보 없이 게시물 삭제 또는 계정 제재 조치가 이루어질 수 있습니다.\n\n'
                    '• 욕설, 비방, 혐오 발언 등 비윤리적인 표현 사용\n'
                    '• 음란물, 폭력적 콘텐츠 등 부적절한 게시물 등록\n'
                    '• 도배, 스팸, 광고성 게시물 작성\n'
                    '• 타인의 개인정보 무단 수집 또는 유포\n'
                    '• 자동화된 프로그램을 통한 비정상적 사용',
              ),
              SizedBox(height: 20),
              Text(
                '4. 제재 기준 및 절차',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• 이용규칙 위반 정도에 따라 경고, 일정 기간 활동 제한, 영구 정지 등의 조치가 취해질 수 있습니다.\n'
                    '• 중대한 위반 사항은 사전 경고 없이 즉시 제재될 수 있습니다.\n'
                    '• 제재에 대한 이의 제기는 고객센터를 통해 신청 가능합니다.',
              ),
              SizedBox(height: 20),
              Text(
                '5. 이용규칙의 변경',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '본 이용규칙은 운영 정책에 따라 변경될 수 있으며, 변경 시 앱 내 공지 또는 알림을 통해 사전 안내합니다.',
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

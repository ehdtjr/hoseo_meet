import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart'; // 홈 화면 import
import '../pages/signup/sign_up_page.dart'; // 회원가입 페이지 import
import '../api/login/login_service.dart'; // AuthService import
import 'dart:convert'; // jsonDecode 사용을 위해 추가
import '../../firebase/create_token.dart'; // FCM 토큰 발급 관리 클래스 import

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController(); // FCM 토큰을 표시할 컨트롤러
  final AuthService _authService = AuthService();
  String? _accessToken; // 휘발성 토큰
  final String domain = "@vision.hoseo.edu";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose(); // 컨트롤러 해제
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _accessToken = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double horizontalPadding = screenWidth * 0.2 * 0.8;
    final double buttonWidth = screenWidth * 0.6;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset(
                'assets/img/loginlogo.png',
                width: screenWidth * 0.4,
              ),
              SizedBox(height: 32),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: 'User ID',
                  ),
                ),
              ),
              // 도메인 텍스트를 명시적으로 추가
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8.0),
                child: Text(
                  "@vision.hoseo.edu",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                  ),
                  obscureText: true,
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: buttonWidth,
                child: ElevatedButton(
                  onPressed: () async {
                    // ID에 도메인 추가
                    final username = '${_usernameController.text.trim()}$domain';

                    // 로그인 요청
                    final response = await _authService.loginUser(
                      username: username,
                      password: _passwordController.text,
                    );

                    if (response.statusCode == 200) {
                      final responseBody = jsonDecode(response.body);
                      _accessToken = responseBody['access_token'];

                      // 홈 화면으로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => HomeScreen()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('로그인 실패: ${response.body}')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    '로그인',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: buttonWidth,
                child: ElevatedButton(
                  onPressed: () {
                    // 회원가입 페이지로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignUpPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    '회원가입',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: buttonWidth,
                child: ElevatedButton(
                  onPressed: () async {
                    // FCM 토큰 발급 버튼 클릭 시
                    final token = await TokenManager.createToken();
                    if (token != null) {
                      _tokenController.text = token; // 발급된 토큰을 텍스트 필드에 출력
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('FCM 토큰 발급 성공')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('FCM 토큰 발급 실패')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'FCM 토큰 발급',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: TextField(
                  controller: _tokenController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'FCM Token',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.copy),
                      onPressed: () {
                        // 클립보드에 복사
                        final token = _tokenController.text;
                        if (token.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: token));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('토큰이 복사되었습니다.')),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: buttonWidth,
                child: ElevatedButton(
                  onPressed: () async {
                    // FCM 토큰 삭제 버튼 클릭 시
                    await TokenManager.deleteToken();
                    _tokenController.clear(); // 토큰 필드를 비움
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('FCM 토큰이 삭제되었습니다.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'FCM 토큰 삭제',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      // 아이디 찾기 클릭 시 수행할 작업
                    },
                    child: Text(
                      '아이디 찾기',
                      style: TextStyle(
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      // 비밀번호 찾기 클릭 시 수행할 작업
                    },
                    child: Text(
                      '비밀번호 찾기',
                      style: TextStyle(
                        color: Colors.black,
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

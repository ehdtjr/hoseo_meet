import 'package:flutter/material.dart';
import 'sign_up_details_page.dart'; // SignUpDetailsPage import

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _isAllAgreed = false;
  bool _termsOfService = false;
  bool _privacyPolicy = false;
  bool _communityRules = false;
  bool _adInfoAgreement = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '회원가입',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '약관 동의',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            CheckboxListTile(
              title: Text('아래 약관에 모두 동의합니다.'),
              value: _isAllAgreed,
              onChanged: (bool? value) {
                setState(() {
                  _isAllAgreed = value ?? false;
                  _termsOfService = _isAllAgreed;
                  _privacyPolicy = _isAllAgreed;
                  _communityRules = _isAllAgreed;
                  _adInfoAgreement = _isAllAgreed;
                });
              },
              activeColor: Colors.red,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            Divider(),
            _buildCheckbox('서비스 이용약관 동의 (필수)', _termsOfService, (bool? value) {
              setState(() {
                _termsOfService = value ?? false;
              });
            }),
            _buildCheckbox('개인정보 처리방침 동의 (필수)', _privacyPolicy, (bool? value) {
              setState(() {
                _privacyPolicy = value ?? false;
              });
            }),
            _buildCheckbox('커뮤니티 이용규칙 확인 (필수)', _communityRules, (bool? value) {
              setState(() {
                _communityRules = value ?? false;
              });
            }),
            _buildCheckbox('광고성 정보 수신 동의 (선택)', _adInfoAgreement, (bool? value) {
              setState(() {
                _adInfoAgreement = value ?? false;
              });
            }),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _termsOfService && _privacyPolicy && _communityRules
                  ? () {
                // 휴대폰 인증 시 다음 페이지로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpDetailsPage()),
                );
              }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _termsOfService && _privacyPolicy && _communityRules
                    ? Colors.red
                    : Colors.grey[300],
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Center(
                child: Text(
                  '휴대폰 인증',
                  style: TextStyle(
                    color: _termsOfService && _privacyPolicy && _communityRules
                        ? Colors.white
                        : Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // 아이핀 인증 처리
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Center(
                child: Text(
                  '아이핀 인증',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(String title, bool value, Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 16),
      ),
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: Colors.red,
    );
  }
}

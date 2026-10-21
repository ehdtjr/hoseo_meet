import 'package:campusmeet/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Login form renders without Firebase or a signed-in session',
      (WidgetTester tester) async {
    await pumpLogin(tester);

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('아이디'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('캠퍼스밋 로그인'), findsOneWidget);
    expect(find.text('회원가입'), findsOneWidget);
    expect(find.text('비밀번호 찾기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty login shows validation instead of sending a request',
      (WidgetTester tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('캠퍼스밋 로그인'));
    await tester.pumpAndSettle();

    expect(find.text('입력 오류'), findsOneWidget);
    expect(find.text('아이디와 비밀번호를 입력해주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

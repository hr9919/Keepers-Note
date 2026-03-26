import 'package:flutter/material.dart';
import 'dart:async';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'main_wrapper.dart'; // ★ 하단 바를 위해 반드시 필요합니다!
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 카카오 SDK 초기화 (최신 앱 키 유지)
  KakaoSdk.init(nativeAppKey: '13e6e9e30bad4b0e8a92e1561bab73b0');

  // 자동 로그인 체크 로직
  bool isLoggedIn = false;
  try {
    if (await AuthApi.instance.hasToken()) {
      try {
        await UserApi.instance.me();
        isLoggedIn = true;
      } catch (e) {
        await TokenManagerProvider.instance.manager.clear();
      }
    }
  } catch (e) {
    print("로그인 상태 체크 에러: $e");
  }

  runApp(KeepersNoteApp(isLoggedIn: isLoggedIn));
}

class KeepersNoteApp extends StatelessWidget {
  final bool isLoggedIn;
  const KeepersNoteApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Keeper's Note",
      theme: ThemeData(useMaterial3: true),
      home: SplashScreen(isLoggedIn: isLoggedIn),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final bool isLoggedIn;
  const SplashScreen({super.key, required this.isLoggedIn});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      // ★ 수정 포인트: 로그인 성공 시 HomeScreen이 아닌 MainWrapper로 보냅니다!
      Widget nextScreen = widget.isLoggedIn
          ? const MainWrapper()       // <- 내비게이션 바가 살아납니다.
          : const OnboardingScreen();

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1000),
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // ★ 스플래시 UI 복구: 배경 그라데이션 + 중앙 캐릭터 + 텍스트
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_gradient.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Town\n',
                          style: TextStyle(
                            color: Color(0xFF868686),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 2.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Keeper’s Note\n',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 44,
                            fontWeight: FontWeight.w600,
                            height: 1.02,
                          ),
                        ),
                        TextSpan(
                          text: '키퍼노트',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            height: 1.41,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Container(
              width: 252,
              height: 268,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/splash_art_shadow.png"),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '타운 키퍼를 위한 가이드북',
              style: TextStyle(
                color: Color(0xFF616161),
                fontSize: 18,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
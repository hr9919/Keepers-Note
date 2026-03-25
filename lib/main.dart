import 'package:flutter/material.dart';
import 'dart:async'; // 타이머 사용을 위해 필요
import 'onboarding_screen.dart';

void main() {
  runApp(const KeepersNoteApp());
}

class KeepersNoteApp extends StatelessWidget {
  const KeepersNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Keeper's Note",
      // 테마에 기본 폰트 설정 등을 추가하면 더 좋습니다.
      theme: ThemeData(useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}

// 화면 전환 로직을 위해 StatefulWidget으로 변경
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // 1초(또는 2초) 뒤에 실행
    Timer(const Duration(seconds: 3), () {
      // Navigator.pushReplacement 대신 PageRouteBuilder를 사용해 커스텀 애니메이션 적용
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          // 전환 애니메이션 지속 시간 (1000ms = 1초 동안 부드럽게)
          transitionDuration: const Duration(milliseconds: 1000),

          // 이동할 화면 지정
          pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),

          // 애니메이션 효과 설정 (FadeTransition)
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation, // 0.0에서 1.0으로 서서히 밝아짐
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
            // 1. 메인 타이틀
            IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Town\n',
                          style: TextStyle(
                            color: Color(0xFF868686),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 2.5,
                          ),
                        ),
                        const TextSpan(
                          text: 'Keeper’s Note\n',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 44,
                            fontWeight: FontWeight.w600,
                            height: 1.02,
                          ),
                        ),
                        const TextSpan(
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

            const SizedBox(height: 40), // 피그마 비율에 맞춰 살짝 조정

            // 2. 가이드북 로고 이미지
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

            const SizedBox(height: 20), // 0보다는 약간의 여백 권장

            // 3. 하단 슬로건
            const Text(
              '타운 키퍼를 위한 가이드북',
              style: TextStyle(
                color: Color(0xFF616161),
                fontSize: 18, // 조금 더 세련되게 크기 조정
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
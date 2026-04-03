import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main_wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  Future<void> _handleKakaoLogin() async {
    try {
      debugPrint('--- [Log] 카카오 로그인 시작 ---');
      bool isInstalled = await isKakaoTalkInstalled();

      OAuthToken token = isInstalled
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();

      User kakaoUser = await UserApi.instance.me();
      String nickname = kakaoUser.kakaoAccount?.profile?.nickname ?? "키퍼";

      _syncWithBackend(kakaoUser.id, nickname);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainWrapper()),
            (route) => false,
      );
    } catch (error) {
      debugPrint('--- [Error] 로그인 실패: $error ---');
    }
  }

  Future<void> _syncWithBackend(int? kakaoId, String nickname) async {
    try {
      await http.post(
        Uri.parse('http://161.33.30.40:8080/api/user/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"kakaoId": kakaoId, "nickname": nickname}),
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('--- [Log] 서버 동기화 실패: $e ---');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ★ 핵심: 시스템 하단 바 높이를 가져옵니다.
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

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
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (int page) => setState(() => _currentPage = page),
              children: [
                _buildPage(image: "assets/images/onboarding_1.png", title: "인터랙티브 맵", desc: "원하는 자원의 위치를 확인하고\n마음대로 메모하세요."),
                _buildPage(image: "assets/images/onboarding_2.png", title: "효율적인 가이드", desc: "타운 생활에 필요한 모든 정보를\n한눈에 확인하세요."),
                _buildPage(image: "assets/images/onboarding_3.png", title: "나만의 기록", desc: "오늘 있었던 일을 기록하고\n성장하는 키퍼가 되어보세요."),
                _buildPage(image: "assets/images/onboarding_4.png", title: "애완동물 관리", desc: "애완동물의 종류를 검색하고,\n내 애완동물의 최애 간식을 관리하세요.", isLastPage: true),
              ],
            ),

            // ★ 인디케이터 위치 (시스템 바 높이 반영)
            Positioned(
              bottom: bottomPadding > 0 ? bottomPadding + 60 : 70,
              left: 0,
              right: 0,
              child: Center(child: _buildIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({required String image, required String title, required String desc, bool isLastPage = false}) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        SizedBox(height: screenHeight * 0.12),
        SizedBox(
          height: screenHeight * 0.38,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Image.asset(image, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 30),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, fontFamily: 'SF Pro')),
        const SizedBox(height: 16),
        Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, height: 1.4, fontFamily: 'SF Pro')),

        const Spacer(), // 유동적인 간격 확보

        if (isLastPage)
          Padding(
            // ★ 버튼 하단 여백: 시스템 바가 있으면 더 띄워줍니다.
            padding: EdgeInsets.only(left: 30, right: 30, bottom: bottomPadding > 0 ? bottomPadding + 100 : 110),
            child: GestureDetector(
              onTap: _handleKakaoLogin,
              child: Container(
                height: 54,
                decoration: ShapeDecoration(
                  color: const Color(0xFFFEE500),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                  shadows: const [BoxShadow(color: Color(0x19000000), blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/kakao_logo.png', height: 24),
                    const SizedBox(width: 10),
                    const Text("카카오로 시작하기", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'SF Pro')),
                  ],
                ),
              ),
            ),
          )
        else
        // 마지막 페이지가 아닐 때도 인디케이터 공간을 위해 Spacer 유지
          SizedBox(height: bottomPadding > 0 ? bottomPadding + 150 : 160),
      ],
    );
  }

  Widget _buildIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        return Container(
          width: 6, height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: ShapeDecoration(
            color: _currentPage == index ? const Color(0xFF616161) : const Color(0xFFCACACA),
            shape: const OvalBorder(),
          ),
        );
      }),
    );
  }
}
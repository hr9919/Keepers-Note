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

  // 1. 카카오 로그인 핸들러 (실기기 대응 보완)
  Future<void> _handleKakaoLogin() async {
    try {
      print('--- [Log] 카카오 로그인 시작 ---');
      bool isInstalled = await isKakaoTalkInstalled();

      // 카카오 인증 (앱이 있으면 앱으로, 없으면 계정창으로)
      OAuthToken token = isInstalled
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();

      print('--- [Log] 카카오 인증 성공! 토큰: ${token.accessToken} ---');

      // 사용자 정보 획득
      User kakaoUser = await UserApi.instance.me();
      String nickname = kakaoUser.kakaoAccount?.profile?.nickname ?? "키퍼";
      print('--- [Log] 사용자 확인: $nickname (ID: ${kakaoUser.id}) ---');

      // 2. 백엔드 동기화 (비동기로 실행하여 화면 전환을 방해하지 않음)
      _syncWithBackend(kakaoUser.id, nickname);

      // 3. ★ 즉시 화면 이동 (가장 중요)
      if (!mounted) return;
      print('--- [Log] 메인 화면(MainWrapper)으로 진입합니다 ---');
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainWrapper()),
        (route) => false,
      );

    } catch (error) {
      print('--- [Error] 로그인 실패: $error ---');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 처리 중 에러가 발생했습니다: $error')),
        );
      }
    }
  }

  // 백엔드 통신 함수 분리
  Future<void> _syncWithBackend(int? kakaoId, String nickname) async {
    try {
      final response = await http.post(
        Uri.parse('http://161.33.30.40:8080/api/user/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "kakaoId": kakaoId,
          "nickname": nickname,
        }),
      ).timeout(const Duration(seconds: 3));
      print('--- [Log] 서버 응답 상태: ${response.statusCode} ---');
    } catch (e) {
      print('--- [Log] 서버 동기화 실패(무시하고 진행): $e ---');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

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
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                _buildPage(context: context, image: "assets/images/onboarding_1.png", title: "인터랙티브 맵", desc: "원하는 자원의 위치를 확인하고\n마음대로 메모하세요."),
                _buildPage(context: context, image: "assets/images/onboarding_2.png", title: "효율적인 가이드", desc: "타운 생활에 필요한 모든 정보를\n한눈에 확인하세요."),
                _buildPage(context: context, image: "assets/images/onboarding_3.png", title: "나만의 기록", desc: "오늘 있었던 일을 기록하고\n성장하는 키퍼가 되어보세요."),
                _buildPage(context: context, image: "assets/images/onboarding_4.png", title: "애완동물 관리", desc: "애완동물의 종류를 검색하고,\n내 애완동물의 최애 간식을 관리하세요."),
              ],
            ),
            
            // 인디케이터 위치
            Positioned(
              bottom: bottomPadding > 0 ? bottomPadding + 110 : 120,
              left: 0,
              right: 0,
              child: Center(child: _buildIndicator()),
            ),

            // 마지막 페이지에서만 로그인 버튼 표시
            if (_currentPage == 3)
              Positioned(
                bottom: bottomPadding > 0 ? bottomPadding + 20 : 40,
                left: 30,
                right: 30,
                child: GestureDetector(
                  onTap: _handleKakaoLogin,
                  child: Container(
                    height: 54,
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFEE500),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                      shadows: const [
                        BoxShadow(
                          color: Color(0x19000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Image.asset(
                              'assets/images/kakao_logo.png',
                              height: 24,
                            ),
                          ),
                        ),
                        const Center(
                          child: Text(
                            "카카오로 시작하기",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SF Pro',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({required BuildContext context, required String image, required String title, required String desc}) {
    final double screenHeight = MediaQuery.of(context).size.height;
    return Column(
      children: [
        SizedBox(height: screenHeight * 0.12),
        SizedBox(
          height: screenHeight * 0.42,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Image.asset(image, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: 301,
          child: Column(
            children: [
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, height: 1.4)),
            ],
          ),
        ),
        const Spacer(flex: 3),
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

import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:http/http.dart' as http; // ★ 추가
import 'dart:convert'; // ★ 추가
import 'main_wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  // ★ 카카오 로그인 및 백엔드 동기화 로직
  Future<void> _handleKakaoLogin() async {
    try {
      bool isInstalled = await isKakaoTalkInstalled();

      // 1. 카카오 인증 진행
      OAuthToken token = isInstalled
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();

      print('카카오 로그인 성공! 토큰: ${token.accessToken}');

      // 2. 카카오 사용자 정보 가져오기
      User kakaoUser = await UserApi.instance.me();

      // 3. ★ 우리 백엔드 서버에 유저 정보 전송 (회원가입/로그인 처리)
      final response = await http.post(
        Uri.parse('http://161.33.30.40:8080/api/user/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "kakaoId": kakaoUser.id,
          "nickname": kakaoUser.kakaoAccount?.profile?.nickname ?? "사용자",
        }),
      );

      if (response.statusCode == 200) {
        print('서버와 유저 정보 동기화 완료!');

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainWrapper()),
                (route) => false,
          );
        }
      } else {
        print('서버 동기화 실패: ${response.statusCode}');
        // 알림창 등을 띄워 유저에게 알릴 수 있습니다.
      }

    } catch (error) {
      print('로그인 과정 중 에러 발생: $error');
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
                _buildPage(
                  context: context,
                  image: "assets/images/onboarding_4.png",
                  title: "애완동물 관리",
                  desc: "애완동물의 종류를 검색하고,\n내 애완동물의 최애 간식을 관리하세요.",
                ),
              ],
            ),

            Positioned(
              bottom: bottomPadding > 0 ? bottomPadding + 110 : 120, // 버튼 위치 고려해 살짝 위로 조정
              left: 0,
              right: 0,
              child: Center(child: _buildIndicator()),
            ),

            // onboarding_screen.dart의 버튼 부분 수정본

            if (_currentPage == 3)
              Positioned(
                bottom: bottomPadding > 0 ? bottomPadding + 20 : 40,
                left: 30,
                right: 30,
                child: GestureDetector(
                  onTap: _handleKakaoLogin, // 카카오 로그인 함수 연결
                  child: Container(
                    height: 54, // 높이 고정
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFEE500), // 카카오 노란색
                      shape: RoundedRectangleBorder(
                        // ★ [수정] 모서리를 완전히 둥글게 만듭니다. (높이의 절반 이상)
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
                        // ★ [추가] 카카오 로고 이미지를 왼쪽에 배치합니다.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24), // 왼쪽 여백
                            child: Image.asset(
                              'assets/images/kakao_logo.png', // ★ 로고 이미지 파일명
                              height: 24, // 로고 크기 조절
                            ),
                          ),
                        ),
                        // 중앙 텍스트
                        const Center(
                          child: Text(
                            "카카오로 시작하기",
                            style: TextStyle(
                              color: Colors.black, // 글자는 검정색
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

  Widget _buildPage({
    required BuildContext context,
    required String image,
    required String title,
    required String desc,
  }) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Column(
      children: [
        SizedBox(height: screenHeight * 0.12),
        SizedBox(
          height: screenHeight * 0.42,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Image.asset(
              image,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: 301,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SF Pro',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  height: 1.4,
                  fontFamily: 'SF Pro',
                ),
              ),
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
          width: 6,
          height: 6,
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
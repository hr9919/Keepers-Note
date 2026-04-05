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

      await (isInstalled
          ? UserApi.instance.loginWithKakaoTalk()
          : UserApi.instance.loginWithKakaoAccount());

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
      await http
          .post(
        Uri.parse('http://161.33.30.40:8080/api/user/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "kakaoId": kakaoId,
          "nickname": nickname,
        }),
      )
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('--- [Log] 서버 동기화 실패: $e ---');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              children: const [
                _OnboardingPage(
                  image: "assets/images/onboarding_1.png",
                  title: "인터랙티브 맵",
                  desc: "원하는 자원의 위치를 확인하고\n마음대로 메모하세요.",
                ),
                _OnboardingPage(
                  image: "assets/images/onboarding_2.png",
                  title: "효율적인 가이드",
                  desc: "타운 생활에 필요한 모든 정보를\n한눈에 확인하세요.",
                ),
                _OnboardingPage(
                  image: "assets/images/onboarding_3.png",
                  title: "숙제 도우미",
                  desc: "오늘 해야할 일들을 정리하고\n성장하는 타운 키퍼가 되어보세요.",
                ),
                _OnboardingPage(
                  image: "assets/images/onboarding_4.png",
                  title: "애완동물 관리",
                  desc: "애완동물의 종류를 검색하고,\n내 애완동물의 최애 간식을 관리하세요.",
                  isLastPage: true,
                ),
              ],
            ),

            Positioned(
              bottom: bottomPadding > 0 ? bottomPadding + 80 : 80,
              left: 0,
              right: 0,
              child: Center(child: _buildIndicator()),
            ),

            Positioned.fill(
              child: IgnorePointer(
                ignoring: _currentPage != 3,
                child: _currentPage == 3
                    ? Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildBottomLoginButton(context),
                )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomLoginButton(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double horizontalPadding =
    MediaQuery.of(context).size.width < 380 ? 20 : 30;
    final double buttonBottom =
    bottomPadding > 0 ? bottomPadding + 130 : 130;

    return Padding(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: buttonBottom,
      ),
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
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/kakao_logo.png', height: 24),
              const SizedBox(width: 10),
              const Text(
                "카카오로 시작하기",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SF Pro',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _currentPage == index ? 18 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: ShapeDecoration(
            color: _currentPage == index
                ? const Color(0xFF616161)
                : const Color(0xFFCACACA),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String image;
  final String title;
  final String desc;
  final bool isLastPage;

  const _OnboardingPage({
    required this.image,
    required this.title,
    required this.desc,
    this.isLastPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            // 1. 상단 유연한 여백 (비율 2)
            const Spacer(flex: 2),

            // 2. 이미지 영역 (높이 고정 비율)
            SizedBox(
              height: screenHeight * 0.32,
              child: Image.asset(
                image,
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 40),

            // 3. 텍스트 영역
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: Color(0xFF3A3A3A),
              ),
            ),

            // 4. 하단 유연한 여백 (비율 3)
            const Spacer(flex: 3),

            // 5. 하단 고정 여백 통일 ★
            // 모든 페이지를 마지막 페이지의 버튼 자리(140)에 맞춥니다.
            // 이렇게 하면 페이지를 넘겨도 텍스트 위치가 변하지 않습니다.
            const SizedBox(height: 140),
          ],
        ),
      ),
    );
  }
}
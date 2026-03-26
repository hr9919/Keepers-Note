import 'package:flutter/material.dart';
// ★ main_wrapper.dart 임포트 확인 (파일명 다르면 수정)
import 'main_wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    // ★ 핵심: 기기 하단 시스템 내비게이션 바 높이를 가져옵니다.
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
                  isLast: true,
                ),
              ],
            ),

            // ★ 인디케이터 위치 (시스템 바 높이 반영하되, 균형 있게 조정)
            Positioned(
              // 시스템 바가 있으면 그만큼 더 위로 (기본 90 + 패딩), 없으면 100
              bottom: bottomPadding > 0 ? bottomPadding + 90 : 100,
              left: 0,
              right: 0,
              child: Center(child: _buildIndicator()),
            ),

            if (_currentPage == 3)
            // ★ 시작하기 버튼 위치 (시스템 바 높이 반영하되, 균형 있게 조정)
              Positioned(
                // 시스템 바가 있으면 그 높이에 15px 여백, 없으면 기본 40px
                bottom: bottomPadding > 0 ? bottomPadding + 15 : 40,
                left: 40,
                right: 40,
                child: GestureDetector(
                  onTap: () {
                    print("키퍼노트 시작!");
                    //HomeScreen 대신 MainWrapper를 새로운 Root로 설정
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const MainWrapper()),
                          (route) => false,
                    );
                  },
                  child: Container(
                    height: 48,
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFF7A65),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(44),
                      ),
                      shadows: const [
                        BoxShadow(
                          color: Color(0x19000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "바로 시작하기",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ★ 배치 균형과 이미지 크기가 최종 개선된 헬퍼 함수
  Widget _buildPage({
    required BuildContext context,
    required String image,
    required String title,
    required String desc,
    bool isLast = false,
  }) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Column(
      children: [
        // ★ 상단 여백 조절
        SizedBox(height: screenHeight * 0.12),

        // ★ 이미지 영역 고정 비율
        SizedBox(
          height: screenHeight * 0.42,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Image.asset(
              image,
              fit: BoxFit.contain, // 비율 유지
            ),
          ),
        ),

        // ★ 이미지와 타이틀 사이 고정 간격
        const SizedBox(height: 30),

        // 텍스트 영역
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

        // ★★★ [여기서부터 수정합니다] 고정 여백(160) 대신 Spacer를 사용합니다!
        const Spacer(flex: 3), // 이미지와 텍스트 위쪽 간격에 비례해 아래쪽에도 여백 확보

        // ★ 인디케이터와 버튼이 들어갈 공간을 '유동적'으로 확보합니다.
        // const SizedBox(height: 160), // ★ 이 부분을 주석 처리하거나 삭제하세요!
      ],
    );
  }

  Widget _buildIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        return Container(
          width: 6, // 크기 살짝 키움 (가독성)
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
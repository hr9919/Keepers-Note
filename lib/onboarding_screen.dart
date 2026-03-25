import 'package:flutter/material.dart';
import 'home_screen.dart';

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
                _buildPage(context: context,image: "assets/images/onboarding_1.png", title: "인터랙티브 맵", desc: "원하는 자원의 위치를 확인하고\n마음대로 메모하세요."),
                _buildPage(context: context,image: "assets/images/onboarding_2.png", title: "효율적인 가이드", desc: "타운 생활에 필요한 모든 정보를\n한눈에 확인하세요."),
                _buildPage(context: context,image: "assets/images/onboarding_3.png", title: "나만의 기록", desc: "오늘 있었던 일을 기록하고\n성장하는 키퍼가 되어보세요."),
                _buildPage(
                  context: context,
                  image: "assets/images/onboarding_4.png",
                  title: "애완동물 관리",
                  desc: "애완동물의 종류를 검색하고,\n내 애완동물의 최애 간식을 관리하세요.",
                  isLast: true,
                ),
              ],
            ),

            // 인디케이터 위치 (모든 페이지 120으로 고정)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(child: _buildIndicator()),
            ),

            if (_currentPage == 3)
              Positioned(
                bottom: 50,
                left: 40,
                right: 40,
                child: GestureDetector(
                  onTap: () {
                    print("키퍼노트 시작!");

                    // 현재 스택의 모든 화면(온보딩)을 지우고 HomeScreen을 새로운 Root로 설정
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                          (route) => false,
                    );
                  },
                  child: Container(
                    width: 280,
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

  // ★ 이미지 배치 로직이 개선된 헬퍼 함수
  Widget _buildPage({
    required BuildContext context, // ★ context를 인자로 받아야 MediaQuery 사용 가능
    required String image,
    required String title,
    required String desc,
    bool isLast = false,
  }) {
    // 기기 전체 높이 계산
    final double screenHeight = MediaQuery.of(context).size.height;

    return Column(
      children: [
        // 1. 상단 여백: 화면 높이의 8% 정도로 설정 (노치 기기에서 적당함)
        SizedBox(height: screenHeight * 0.20),

        // 2. 이미지 영역: 화면 높이의 약 40% 차지하게 설정
        SizedBox(
          height: screenHeight * 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Image.asset(
              image,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // 3. 이미지와 텍스트 사이 간격: 화면 높이의 5% 정도
        SizedBox(height: screenHeight * 0.005),

        // 4. 텍스트 영역
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
                ),
              ),
            ],
          ),
        ),

        // 5. 하단 유동적 여백: 남는 공간을 Spacer가 채움
        const Spacer(),

        // 인디케이터와 버튼을 위한 최소한의 하단 가드 (약 15%)
        SizedBox(height: screenHeight * 0.15),
      ],
    );
  }

  Widget _buildIndicator() {
    return SizedBox(
      width: 50,
      height: 5,
      child: Stack(
        children: List.generate(4, (index) {
          return Positioned(
            left: index * 15.0,
            child: Container(
              width: 5,
              height: 5,
              decoration: ShapeDecoration(
                color: _currentPage == index ? const Color(0xFF616161) : const Color(0xFFCACACA),
                shape: const OvalBorder(),
              ),
            ),
          );
        }),
      ),
    );
  }
}
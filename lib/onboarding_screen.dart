import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

import 'main_wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const String _baseUrl = 'http://161.33.30.40:8080';

  int _currentPage = 0;
  final PageController _pageController = PageController();

  bool _isLoggingIn = false;

  void _showLoginMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _handleKakaoLogin() async {
    if (_isLoggingIn) return;

    setState(() => _isLoggingIn = true);

    try {
      debugPrint('--- [Log] 카카오 로그인 시작 ---');

      OAuthToken token;

      if (await isKakaoTalkInstalled()) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
          debugPrint('--- [Log] 카카오톡으로 로그인 성공 ---');
        } catch (error, stack) {
          debugPrint('--- [Error] 카카오톡으로 로그인 실패: $error ---');
          debugPrint('$stack');

          if (error is PlatformException && error.code == 'CANCELED') {
            debugPrint('--- [Log] 사용자가 로그인 취소 ---');
            _showLoginMessage('로그인이 취소되었어요.');
            return;
          }

          try {
            token = await UserApi.instance.loginWithKakaoAccount();
            debugPrint('--- [Log] 카카오계정으로 로그인 성공 ---');
          } catch (accountError, accountStack) {
            debugPrint('--- [Error] 카카오계정으로 로그인 실패: $accountError ---');
            debugPrint('$accountStack');
            _showLoginMessage('카카오 로그인에 실패했어요. 다시 시도해주세요.');
            return;
          }
        }
      } else {
        try {
          token = await UserApi.instance.loginWithKakaoAccount();
          debugPrint('--- [Log] 카카오계정으로 로그인 성공 ---');
        } catch (error, stack) {
          debugPrint('--- [Error] 카카오계정으로 로그인 실패: $error ---');
          debugPrint('$stack');
          _showLoginMessage('카카오 로그인에 실패했어요. 다시 시도해주세요.');
          return;
        }
      }

      debugPrint(
        '--- [Log] accessToken 존재: ${token.accessToken.isNotEmpty} ---',
      );

      final User kakaoUser = await UserApi.instance.me();
      final int? kakaoId = kakaoUser.id;
      final String nickname =
          kakaoUser.kakaoAccount?.profile?.nickname ?? '키퍼';

      debugPrint('--- [Log] kakaoId=$kakaoId nickname=$nickname ---');

      if (kakaoId == null) {
        debugPrint('--- [Error] kakaoId null ---');
        _showLoginMessage('사용자 정보를 불러오지 못했어요. 다시 시도해주세요.');
        return;
      }

      final bool synced = await _syncWithBackend(kakaoId, nickname);
      if (!synced) {
        debugPrint('--- [Error] 서버 동기화 실패 ---');
        _showLoginMessage('서버 연결이 불안정해요. 잠시 후 다시 시도해주세요.');
        return;
      }

      if (!mounted) return;

      debugPrint('--- [Log] 메인 화면으로 이동 ---');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainWrapper()),
            (route) => false,
      );
    } catch (error, stack) {
      debugPrint('--- [Error] 로그인 실패: $error ---');
      debugPrint('$stack');
      _showLoginMessage('로그인 중 문제가 발생했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  Future<bool> _syncWithBackend(int kakaoId, String nickname) async {
    try {
      final response = await http
          .post(
        Uri.parse('$_baseUrl/api/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'kakaoId': kakaoId,
          'nickname': nickname,
        }),
      )
          .timeout(const Duration(seconds: 5));

      debugPrint('--- [Log] 서버 응답 코드: ${response.statusCode} ---');
      debugPrint('--- [Log] 서버 응답 바디: ${response.body} ---');

      return response.statusCode == 200;
    } catch (e, stack) {
      debugPrint('--- [Log] 서버 동기화 실패: $e ---');
      debugPrint('$stack');
      return false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                  image: 'assets/images/onboarding_1.png',
                  title: '인터랙티브 맵',
                  desc: '원하는 자원의 위치를 확인하고\n마음대로 메모하세요.',
                ),
                _OnboardingPage(
                  image: 'assets/images/onboarding_2.png',
                  title: '효율적인 가이드',
                  desc: '타운 생활에 필요한 모든 정보를\n한눈에 확인하세요.',
                ),
                _OnboardingPage(
                  image: 'assets/images/onboarding_3.png',
                  title: '숙제 도우미',
                  desc: '오늘 해야할 일들을 정리하고\n성장하는 타운 키퍼가 되어보세요.',
                ),
                _OnboardingPage(
                  image: 'assets/images/onboarding_4.png',
                  title: '애완동물 관리',
                  desc: '애완동물의 종류를 검색하고,\n내 애완동물의 최애 간식을 관리하세요.',
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
    final double buttonBottom = bottomPadding > 0 ? bottomPadding + 130 : 130;

    return Padding(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: buttonBottom,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(27),
          onTap: _isLoggingIn ? null : _handleKakaoLogin,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _isLoggingIn ? 0.72 : 1.0,
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
                  if (_isLoggingIn) ...[
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '로그인 중...',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ] else ...[
                    Image.asset('assets/images/kakao_logo.png', height: 24),
                    const SizedBox(width: 10),
                    const Text(
                      '카카오로 시작하기',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
            const Spacer(flex: 2),
            SizedBox(
              height: screenHeight * 0.32,
              child: Image.asset(
                image,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 40),
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
            const Spacer(flex: 3),
            const SizedBox(height: 140),
          ],
        ),
      ),
    );
  }
}
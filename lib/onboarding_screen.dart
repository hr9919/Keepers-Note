import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'main_wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  final Uri? initialDeepLink;

  const OnboardingScreen({
    super.key,
    this.initialDeepLink,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _LoginProvider {
  none,
  kakao,
  apple,
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const String _baseUrl = 'https://api.keepers-note.o-r.kr';

  int _currentPage = 0;
  final PageController _pageController = PageController();

  _LoginProvider _loadingProvider = _LoginProvider.none;

  bool get _isLoggingIn => _loadingProvider != _LoginProvider.none;
  bool get _isKakaoLoggingIn => _loadingProvider == _LoginProvider.kakao;
  bool get _isAppleLoggingIn => _loadingProvider == _LoginProvider.apple;

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

    setState(() => _loadingProvider = _LoginProvider.kakao);

    try {
      OAuthToken token;

      if (await isKakaoTalkInstalled()) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          if (error is PlatformException && error.code == 'CANCELED') {
            _showLoginMessage('로그인이 취소되었어요.');
            return;
          }
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      if (token.accessToken.isEmpty) {
        _showLoginMessage('카카오 로그인에 실패했어요.');
        return;
      }

      final User kakaoUser = await UserApi.instance.me();
      final String? providerUserId = kakaoUser.id?.toString();
      final String nickname =
          kakaoUser.kakaoAccount?.profile?.nickname ?? '키퍼';
      final String? profileImageUrl =
          kakaoUser.kakaoAccount?.profile?.profileImageUrl;

      if (providerUserId == null || providerUserId.isEmpty) {
        _showLoginMessage('사용자 정보를 불러오지 못했어요.');
        return;
      }

      final bool synced = await _syncWithBackend(
        provider: 'KAKAO',
        providerUserId: providerUserId,
        nickname: nickname,
        profileImageUrl: profileImageUrl,
      );

      if (!synced) {
        _showLoginMessage('서버 연결이 불안정해요. 잠시 후 다시 시도해주세요.');
        return;
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => MainWrapper(
            initialDeepLink: widget.initialDeepLink,
          ),
        ),
            (route) => false,
      );
    } catch (error, stack) {
      debugPrint('--- [Error] 카카오 로그인 실패: $error ---');
      debugPrint('$stack');
      _showLoginMessage('로그인 중 문제가 발생했어요.');
    } finally {
      if (mounted) {
        setState(() => _loadingProvider = _LoginProvider.none);
      }
    }
  }

  Future<void> _handleAppleLogin() async {
    if (_isLoggingIn) return;

    setState(() => _loadingProvider = _LoginProvider.apple);

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final providerUserId = credential.userIdentifier;
      if (providerUserId == null || providerUserId.isEmpty) {
        _showLoginMessage('애플 계정 정보를 불러오지 못했어요.');
        return;
      }

      final fullName = [
        credential.givenName,
        credential.familyName,
      ].where((e) => e != null && e!.trim().isNotEmpty).join(' ').trim();

      final nickname = fullName.isNotEmpty ? fullName : 'Apple 사용자';

      final bool synced = await _syncWithBackend(
        provider: 'APPLE',
        providerUserId: providerUserId,
        nickname: nickname,
        profileImageUrl: null,
      );

      if (!synced) {
        _showLoginMessage('서버 연결이 불안정해요. 잠시 후 다시 시도해주세요.');
        return;
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => MainWrapper(
            initialDeepLink: widget.initialDeepLink,
          ),
        ),
            (route) => false,
      );
    } catch (e, stack) {
      debugPrint('--- [Error] 애플 로그인 실패: $e ---');
      debugPrint('$stack');
      _showLoginMessage('애플 로그인 중 문제가 발생했어요.');
    } finally {
      if (mounted) {
        setState(() => _loadingProvider = _LoginProvider.none);
      }
    }
  }

  Future<bool> _syncWithBackend({
    required String provider,
    required String providerUserId,
    required String nickname,
    String? profileImageUrl,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('$_baseUrl/api/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider': provider,
          'providerUserId': providerUserId,
          'nickname': nickname,
          'profileImageUrl': profileImageUrl,
        }),
      )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final serverUserId = data['id']?.toString();

      if (serverUserId == null || serverUserId.isEmpty) {
        return false;
      }

      await _saveSession(
        provider: provider,
        providerUserId: providerUserId,
        nickname: data['nickname']?.toString() ?? nickname,
        profileImageUrl: data['profileImageUrl']?.toString(),
        userId: serverUserId,
      );

      return true;
    } catch (e, stack) {
      debugPrint('--- [Log] 서버 동기화 실패: $e ---');
      debugPrint('$stack');
      return false;
    }
  }

  Future<void> _saveSession({
    required String provider,
    required String providerUserId,
    required String nickname,
    String? profileImageUrl,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('authProvider', provider);
    await prefs.setString('providerUserId', providerUserId);
    await prefs.setString('nickname', nickname);
    await prefs.setString('userId', userId);

    if (profileImageUrl != null && profileImageUrl.trim().isNotEmpty) {
      await prefs.setString('profileImageUrl', profileImageUrl);
    } else {
      await prefs.remove('profileImageUrl');
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
                  child: _buildLoginButtons(context),
                )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButtons(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double horizontalPadding =
    MediaQuery.of(context).size.width < 380 ? 20 : 30;
    final double bottomSpace = bottomPadding > 0 ? bottomPadding + 54 : 54;

    return Padding(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: bottomSpace,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildKakaoLoginButton(),
          const SizedBox(height: 12),
          _buildAppleLoginButton(),
        ],
      ),
    );
  }

  Widget _buildKakaoLoginButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(27),
        onTap: _isLoggingIn ? null : _handleKakaoLogin,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _isLoggingIn && !_isKakaoLoggingIn ? 0.72 : 1.0,
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
                if (_isKakaoLoggingIn) ...[
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
    );
  }

  Widget _buildAppleLoginButton() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: _isLoggingIn && !_isAppleLoggingIn ? 0.72 : 1.0,
      child: IgnorePointer(
        ignoring: _isLoggingIn,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(27),
              onTap: _handleAppleLogin,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(27),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isAppleLoggingIn) ...[
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '로그인 중...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.apple,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Apple로 로그인',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
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
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'onboarding_screen.dart';
import 'main_wrapper.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:app_links/app_links.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  KakaoSdk.init(
    nativeAppKey: '13e6e9e30bad4b0e8a92e1561bab73b0',
  );

  runApp(const KeepersNoteApp());
}

class KeepersNoteApp extends StatelessWidget {
  const KeepersNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: "Keeper's Note",
      theme: ThemeData(useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _minimumSplashDuration = Duration(milliseconds: 1400);
  static const String _baseUrl = 'http://161.33.30.40:8080';

  late final AnimationController _animationController;

  late final Animation<double> _screenFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _bookFade;
  late final Animation<Offset> _bookSlide;
  late final Animation<double> _captionFade;
  late final Animation<Offset> _captionSlide;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  Uri? _pendingDeepLink;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _screenFade = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _titleFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.00, 0.45, curve: Curves.easeOutCubic),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.00, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _bookFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.18, 0.72, curve: Curves.easeOutCubic),
    );

    _bookSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.18, 0.72, curve: Curves.easeOutCubic),
      ),
    );

    _captionFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.42, 0.88, curve: Curves.easeOutCubic),
    );

    _captionSlide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.42, 0.88, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
    _prepareAndNavigate();
  }

  Future<void> _initDeepLinks() async {
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('초기 딥링크 수신: $initialUri');
        _pendingDeepLink = initialUri;
      }
    } catch (e) {
      debugPrint('초기 딥링크 처리 실패: $e');
    }

    // 앱이 완전히 종료된 상태에서 카카오 스킴으로 열린 경우
    try {
      final String? kakaoUrl = await receiveKakaoScheme();
      if (kakaoUrl != null && kakaoUrl.isNotEmpty) {
        final Uri uri = Uri.parse(kakaoUrl);
        debugPrint('카카오 초기 스킴 수신: $uri');

        final String? target = uri.queryParameters['target'];
        final String? postId = uri.queryParameters['postId'];

        if (target == 'community_post' && postId != null) {
          final converted = Uri.parse(
            'https://keepersnote.app/community/post/$postId',
          );
          debugPrint('카카오 공유 링크 변환: $converted');
          _pendingDeepLink = converted;
        }
      }
    } catch (e) {
      debugPrint('카카오 초기 스킴 처리 실패: $e');
    }

    // 앱이 실행 중일 때 카카오 스킴으로 들어오는 경우
    _linkSubscription = _appLinks.uriLinkStream.listen(
          (Uri uri) {
        debugPrint('실시간 딥링크 수신: $uri');
        _pendingDeepLink = uri;
      },
      onError: (Object error) {
        debugPrint('실시간 딥링크 수신 오류: $error');
      },
    );

    kakaoSchemeStream.listen((String? url) {
      if (url == null || url.isEmpty) return;

      final Uri uri = Uri.parse(url);
      debugPrint('카카오 실시간 스킴 수신: $uri');

      final String? target = uri.queryParameters['target'];
      final String? postId = uri.queryParameters['postId'];

      if (target == 'community_post' && postId != null) {
        final converted = Uri.parse(
          'https://keepersnote.app/community/post/$postId',
        );
        debugPrint('카카오 공유 링크 변환: $converted');
        _pendingDeepLink = converted;
      }
    });
  }

  void _log(String message) {
    debugPrint('[Splash/Login] $message');
  }

  Future<void> _prepareAndNavigate() async {
    final stopwatch = Stopwatch()..start();

    await _initDeepLinks();

    bool isLoggedIn = false;
    try {
      isLoggedIn = await _checkLoginStatus();
    } catch (e, s) {
      _log('prepareAndNavigate error: $e');
      debugPrint('$s');
      isLoggedIn = false;
    }

    stopwatch.stop();

    final elapsed = stopwatch.elapsed;
    if (elapsed < _minimumSplashDuration) {
      await Future.delayed(_minimumSplashDuration - elapsed);
    }

    if (!mounted || _isNavigating) return;
    _isNavigating = true;

    final Widget nextScreen = isLoggedIn
        ? MainWrapper(initialDeepLink: _pendingDeepLink)
        : const OnboardingScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: child,
          );
        },
      ),
    );
  }

  Future<bool> _checkLoginStatus() async {
    try {
      _log('자동 로그인 체크 시작');

      final hasToken = await AuthApi.instance.hasToken();
      _log('hasToken = $hasToken');

      if (!hasToken) {
        return false;
      }

      final user = await _safeGetKakaoUser();
      if (user == null) {
        _log('사용자 정보 조회 실패 → 토큰 삭제');
        await _clearKakaoToken();
        return false;
      }

      final kakaoId = user.id;
      final nickname = user.kakaoAccount?.profile?.nickname ?? '사용자';

      _log('kakaoId = $kakaoId');
      _log('nickname = $nickname');

      if (kakaoId == null) {
        _log('kakaoId null → 토큰 삭제');
        await _clearKakaoToken();
        return false;
      }

      final synced = await _syncUserToServer(
        kakaoId: kakaoId,
        nickname: nickname,
      );

      _log('서버 동기화 결과 = $synced');

      if (!synced) {
        await _clearKakaoToken();
      }

      return synced;
    } catch (e, s) {
      _log('로그인 상태 체크 에러: $e');
      debugPrint('$s');
      await _clearKakaoToken();
      return false;
    }
  }

  Future<User?> _safeGetKakaoUser() async {
    try {
      _log('UserApi.instance.me() 호출');
      final user = await UserApi.instance.me();
      _log('me() 성공');
      return user;
    } catch (e, s) {
      _log('me() 실패: $e');
      debugPrint('$s');
      return null;
    }
  }

  Future<bool> _syncUserToServer({
    required int kakaoId,
    required String nickname,
  }) async {
    try {
      _log('서버 동기화 요청 시작');

      final response = await http
          .post(
        Uri.parse('$_baseUrl/api/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'kakaoId': kakaoId,
          'nickname': nickname,
        }),
      )
          .timeout(const Duration(seconds: 8));

      _log('서버 응답 코드 = ${response.statusCode}');
      _log('서버 응답 바디 = ${response.body}');

      return response.statusCode == 200;
    } catch (e, s) {
      _log('서버 동기화 실패: $e');
      debugPrint('$s');
      return false;
    }
  }

  Future<void> _clearKakaoToken() async {
    try {
      _log('토큰 삭제');
      await TokenManagerProvider.instance.manager.clear();
    } catch (e, s) {
      _log('토큰 삭제 실패: $e');
      debugPrint('$s');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _screenFade,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/bg_gradient.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 7),
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.50),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.56),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'TOWN',
                              style: TextStyle(
                                color: Color(0xFFA8A8A8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                                height: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "Keeper’s Note",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF252525),
                              fontSize: 34,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.6,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '키퍼노트',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF6B6B6B),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              height: 1.08,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SlideTransition(
                    position: _bookSlide,
                    child: FadeTransition(
                      opacity: _bookFade,
                      child: Container(
                        width: 244,
                        height: 258,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(
                              "assets/images/splash_art_shadow.png",
                            ),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SlideTransition(
                    position: _captionSlide,
                    child: FadeTransition(
                      opacity: _captionFade,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.44),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.50),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          '타운 키퍼를 위한 가이드북',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF707070),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.15,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS 실기기 문제 분리용 카카오 로그인 헬퍼
/// 실제 로그인 버튼 쪽에서 이 함수를 쓰면 됨.
Future<OAuthToken?> signInWithKakaoForStableIOS() async {
  try {
    debugPrint('[KakaoLogin] 로그인 시작');

    if (Platform.isIOS) {
      debugPrint('[KakaoLogin] iOS → loginWithKakaoAccount 사용');
      return await UserApi.instance.loginWithKakaoAccount();
    }

    final installed = await isKakaoTalkInstalled();
    debugPrint('[KakaoLogin] isKakaoTalkInstalled = $installed');

    if (installed) {
      try {
        debugPrint('[KakaoLogin] loginWithKakaoTalk 시도');
        return await UserApi.instance.loginWithKakaoTalk();
      } catch (e, s) {
        debugPrint('[KakaoLogin] loginWithKakaoTalk 실패: $e');
        debugPrint('$s');
        debugPrint('[KakaoLogin] loginWithKakaoAccount fallback');
        return await UserApi.instance.loginWithKakaoAccount();
      }
    }

    debugPrint('[KakaoLogin] 카카오톡 미설치 → account 로그인');
    return await UserApi.instance.loginWithKakaoAccount();
  } catch (e, s) {
    debugPrint('[KakaoLogin] 전체 실패: $e');
    debugPrint('$s');
    return null;
  }
}
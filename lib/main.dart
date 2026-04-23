import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'onboarding_screen.dart';
import 'main_wrapper.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _defaultNotificationChannel =
AndroidNotificationChannel(
  'keepers_note_default_channel',
  'Keepers Note Notifications',
  description: '키퍼노트 기본 알림 채널',
  importance: Importance.max,
);

Uri? _initialPushDeepLink;
StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
StreamSubscription<RemoteMessage>? _onForegroundMessageSubscription;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Uri? _deepLinkFromPushData(Map<String, dynamic> data) {
  final String? target = data['target']?.toString();
  if (target == null || target.isEmpty) return null;

  if (target == 'community_post') {
    final String? postId = data['postId']?.toString();
    if (postId == null || postId.isEmpty) return null;

    final Map<String, String> query = <String, String>{
      'target': 'community_post',
      'postId': postId,
    };

    final String? commentId = data['commentId']?.toString();
    final String? notificationId = data['notificationId']?.toString();

    if (commentId != null && commentId.isNotEmpty) {
      query['commentId'] = commentId;
    }
    if (notificationId != null && notificationId.isNotEmpty) {
      query['notificationId'] = notificationId;
    }

    return Uri.https('keepersnote.app', '/community/post/$postId', query);
  }

  if (target == 'event') {
    final String? eventId = data['eventId']?.toString();
    if (eventId == null || eventId.isEmpty) return null;
    return Uri.https('keepersnote.app', '/event/$eventId', <String, String>{
      'target': 'event',
      'eventId': eventId,
    });
  }

  if (target == 'uid_request' ||
      target == 'uid_rejected' ||
      target == 'uid_approved') {
    return Uri(
      scheme: 'keepersnote',
      host: 'community',
      queryParameters: <String, String>{'target': target},
    );
  }

  return null;
}

Uri? _deepLinkFromRemoteMessage(RemoteMessage? message) {
  if (message == null) return null;
  return _deepLinkFromPushData(message.data);
}

Future<void> _showForegroundLocalNotification(RemoteMessage message) async {
  final RemoteNotification? notification = message.notification;
  final AppleNotification? apple = message.notification?.apple;
  final AndroidNotification? android = message.notification?.android;

  final String title = notification?.title ?? message.data['title']?.toString() ?? '';
  final String body = notification?.body ?? message.data['body']?.toString() ?? '';

  if (title.isEmpty && body.isEmpty) {
    return;
  }

  final Uri? deepLink = _deepLinkFromRemoteMessage(message);

  await flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _defaultNotificationChannel.id,
        _defaultNotificationChannel.name,
        channelDescription: _defaultNotificationChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: android?.smallIcon,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        subtitle: apple?.subtitle,
      ),
    ),
    payload: deepLink?.toString(),
  );
}

void _navigateToDeepLink(Uri uri) {
  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    _initialPushDeepLink = uri;
    return;
  }

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => MainWrapper(initialDeepLink: uri),
    ),
        (route) => false,
  );
}

Future<void> _configureLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosSettings =
  DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  const InitializationSettings initializationSettings =
  InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final String? payload = response.payload;
      if (payload == null || payload.isEmpty) return;

      final Uri uri = Uri.parse(payload);
      _navigateToDeepLink(uri);
    },
    onDidReceiveBackgroundNotificationResponse:
    _onDidReceiveBackgroundNotificationResponse,
  );

  final NotificationAppLaunchDetails? launchDetails =
  await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  if (launchDetails?.didNotificationLaunchApp == true) {
    final String? payload = launchDetails?.notificationResponse?.payload;
    if (payload != null && payload.isNotEmpty) {
      _initialPushDeepLink = Uri.tryParse(payload);
    }
  }

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_defaultNotificationChannel);
  }
}

@pragma('vm:entry-point')
void _onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {
  final String? payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  _initialPushDeepLink = Uri.tryParse(payload);
}

Future<void> _configureFirebaseMessaging() async {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  await messaging.setAutoInitEnabled(true);

  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  _onForegroundMessageSubscription?.cancel();
  _onForegroundMessageSubscription = FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
      debugPrint('FCM foreground message: ${message.data}');
      await _showForegroundLocalNotification(message);
    },
  );

  _onMessageOpenedAppSubscription?.cancel();
  _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
      debugPrint('FCM notification opened: ${message.data}');
      final Uri? uri = _deepLinkFromRemoteMessage(message);
      if (uri != null) {
        _navigateToDeepLink(uri);
      }
    },
  );

  final RemoteMessage? initialMessage = await messaging.getInitialMessage();
  final Uri? initialUri = _deepLinkFromRemoteMessage(initialMessage);
  if (initialUri != null) {
    _initialPushDeepLink = initialUri;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  KakaoSdk.init(
    nativeAppKey: '13e6e9e30bad4b0e8a92e1561bab73b0',
  );

  try {
    await _configureLocalNotifications();
    await _configureFirebaseMessaging();
  } catch (e, s) {
    debugPrint('post init error: $e');
    debugPrint('$s');
  }

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
  static const String _baseUrl = 'https://api.keepers-note.o-r.kr';

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
  StreamSubscription<String?>? _kakaoSchemeSubscription;
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
    _pendingDeepLink = _initialPushDeepLink ?? _pendingDeepLink;

    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('초기 딥링크 수신: $initialUri');
        _pendingDeepLink = initialUri;
      }
    } catch (e) {
      debugPrint('초기 딥링크 처리 실패: $e');
    }

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

    _linkSubscription = _appLinks.uriLinkStream.listen(
          (Uri uri) {
        debugPrint('실시간 딥링크 수신: $uri');
        _pendingDeepLink = uri;
      },
      onError: (Object error) {
        debugPrint('실시간 딥링크 수신 오류: $error');
      },
    );

    _kakaoSchemeSubscription = kakaoSchemeStream.listen((String? url) {
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
        : OnboardingScreen(initialDeepLink: _pendingDeepLink);

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

      final prefs = await SharedPreferences.getInstance();
      final provider = prefs.getString('authProvider');
      final providerUserId = prefs.getString('providerUserId');
      final nickname = prefs.getString('nickname') ?? '사용자';
      final profileImageUrl = prefs.getString('profileImageUrl');

      if (provider == null || providerUserId == null) {
        _log('저장된 세션 없음');
        return false;
      }

      if (provider == 'KAKAO') {
        final hasToken = await AuthApi.instance.hasToken();
        _log('hasToken = $hasToken');
        if (!hasToken) {
          await _clearSavedSession();
          return false;
        }
      }

      final synced = await _syncUserToServer(
        provider: provider,
        providerUserId: providerUserId,
        nickname: nickname,
        profileImageUrl: profileImageUrl,
      );

      _log('서버 동기화 결과 = $synced');

      if (!synced) {
        await _clearSavedSession();
        if (provider == 'KAKAO') {
          await _clearKakaoToken();
        }
      }

      return synced;
    } catch (e, s) {
      _log('로그인 상태 체크 에러: $e');
      debugPrint('$s');
      await _clearSavedSession();
      await _clearKakaoToken();
      return false;
    }
  }

  Future<bool> _syncUserToServer({
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
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return false;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', data['id'].toString());

      return true;
    } catch (e, s) {
      _log('서버 동기화 실패: $e');
      debugPrint('$s');
      return false;
    }
  }

  Future<void> _clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authProvider');
    await prefs.remove('providerUserId');
    await prefs.remove('nickname');
    await prefs.remove('profileImageUrl');
    await prefs.remove('userId');
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
    _kakaoSchemeSubscription?.cancel();
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

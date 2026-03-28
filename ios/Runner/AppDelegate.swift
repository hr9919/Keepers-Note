import UIKit
import Flutter
import KakaoSDKAuth     // ★ 에러가 난다면 1단계의 pod install이 실패한 겁니다.
import KakaoSDKCommon

@UIApplicationMain // @main 대신 이걸 써야 플러터와 더 잘 맞습니다.
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if (AuthApi.isKakaoTalkLoginUrl(url)) {
      return AuthController.handleOpenUrl(url: url)
    }
    return super.application(app, open: url, options: options)
  }
}
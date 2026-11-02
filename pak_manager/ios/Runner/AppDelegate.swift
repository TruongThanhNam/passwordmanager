import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // API Pigeon của app (AD-14), đăng ký theo UIScene qua engine ngầm định.
    if let messenger = engineBridge.pluginRegistry.registrar(forPlugin: "PlatformApiImpl")?
      .messenger()
    {
      PlatformApiSetup.setUp(binaryMessenger: messenger, api: PlatformApiImpl())
    }
  }
}

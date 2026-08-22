import Flutter
import UIKit

/// APNs registration has to happen during launch, before Firebase's swizzled
/// delegate looks for a device token — otherwise the first cold start comes up
/// without one and the token only appears on the second run.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    registerForPushDelivery(on: application)

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func registerForPushDelivery(on application: UIApplication) {
    application.registerForRemoteNotifications()
  }
}

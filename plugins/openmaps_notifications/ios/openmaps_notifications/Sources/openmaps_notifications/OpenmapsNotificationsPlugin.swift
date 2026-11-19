import Flutter
import UIKit
import UserNotifications

/// Shows OpenMaps' incoming-push notifications.
///
/// Registered as a plugin so it is present on the background Flutter engine that
/// `firebase_messaging` starts for data-only messages, where the gift wrap is
/// decrypted. Notifications are scheduled locally with `trigger: nil` so they
/// appear immediately even while the app is backgrounded.
public class OpenmapsNotificationsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "openmaps/push_notifications",
      binaryMessenger: registrar.messenger()
    )
    let instance = OpenmapsNotificationsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "show":
      show(
        id: arguments["id"] as? Int ?? 0,
        title: arguments["title"] as? String ?? "",
        body: arguments["body"] as? String ?? "",
        result: result
      )
    case "cancel":
      let identifier = "\(arguments["id"] as? Int ?? 0)"
      let center = UNUserNotificationCenter.current()
      center.removeDeliveredNotifications(withIdentifiers: [identifier])
      center.removePendingNotificationRequests(withIdentifiers: [identifier])
      result(nil)
    case "requestPermission":
      UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .badge, .sound]
      ) { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func show(
    id: Int,
    title: String,
    body: String,
    result: @escaping FlutterResult
  ) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let identifier = "\(id)"
    UNUserNotificationCenter.current().removeDeliveredNotifications(
      withIdentifiers: [identifier]
    )
    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request) { _ in }
    result(nil)
  }
}

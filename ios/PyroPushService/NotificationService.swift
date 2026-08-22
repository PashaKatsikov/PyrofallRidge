import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// Notification Service Extension. Its only job is handing the payload to
/// Firebase so an `fcm_options.image` attachment can be downloaded and shown.
/// If the download runs out of time, iOS calls `serviceExtensionTimeWillExpire`
/// and we deliver whatever we have rather than dropping the notification.
final class NotificationService: UNNotificationServiceExtension {
  private var pendingHandler: ((UNNotificationContent) -> Void)?
  private var draft: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    guard
      let draft = request.content.mutableCopy() as? UNMutableNotificationContent
    else {
      contentHandler(request.content)
      return
    }

    pendingHandler = contentHandler
    self.draft = draft
    enrich(draft, then: contentHandler)
  }

  override func serviceExtensionTimeWillExpire() {
    guard let pendingHandler, let draft else { return }
    pendingHandler(draft)
  }

  private func enrich(
    _ content: UNMutableNotificationContent,
    then contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    #if canImport(FirebaseMessaging)
    Messaging.serviceExtension().populateNotificationContent(
      content,
      withContentHandler: contentHandler
    )
    #else
    contentHandler(content)
    #endif
  }
}

import Orion
import WebKit

class CloseHook: ClassHook<WKWebView> {
  func _close() {
    NotificationCenter.default.post(name: WebViewEvent.Closed, object: orig.target)
    return orig._close()
  }
}

struct WebViewEvent {
  static let Closed = Notification.Name("WebViewClosed")
}
import WebKit

class FeedbackHandler: NSObject, WKScriptMessageHandler {
  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    if message.name != "feedback" { return }
    if let type = message.body as? String {
      self.triggerFeedback(type: type)
    }
  }

  func triggerFeedback(type: String) {
    switch type {
    case "selection":
      UISelectionFeedbackGenerator().selectionChanged()
      break
    case "light":
      UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle.light)
        .impactOccurred()
      break
    case "medium":
      UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle.medium)
        .impactOccurred()
      break
    case "heavy":
      UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle.heavy)
        .impactOccurred()
      break
    case "rigid":
      UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle.rigid)
        .impactOccurred()
      break
    case "soft":
      UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle.soft)
        .impactOccurred()
      break
    case "success":
      UINotificationFeedbackGenerator().notificationOccurred(
        UINotificationFeedbackGenerator.FeedbackType.success)
      break
    case "warning":
      UINotificationFeedbackGenerator().notificationOccurred(
        UINotificationFeedbackGenerator.FeedbackType.warning)
      break
    case "error":
      UINotificationFeedbackGenerator().notificationOccurred(
        UINotificationFeedbackGenerator.FeedbackType.error)
      break
    default:
      break
    }
  }
}

import WebKit

class AudioHandler: NSObject, WKScriptMessageHandler {
  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    if message.name != "audio" { return }
    if let info = message.body as? NSDictionary {
      if info["action"] as? String == "setSource" {
        // [[AudioHandler sharedInstance] setContent:body[@"data"]];
        // [[AudioHandler sharedInstance] setMeta:@{
        // 		@"title": @"Hello",
        // 		@"artist": @"Metasome"
        // }];
      }
    }
  }
}

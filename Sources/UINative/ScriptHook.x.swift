import Orion
import WebKit

class ScriptHook: ClassHook<WKUserContentController> {
  func `init`() -> Target {
    let target = orig.`init`()

    do {
      let path = "/Library/PreferenceBundles/UINativeResources.bundle"
      let api = Bundle(path: path)?.path(
        forResource: "WebApi", ofType: "js")

      let code = try String(contentsOfFile: api!)
      let script = WKUserScript.init(
        source: code,
        injectionTime: WKUserScriptInjectionTime.atDocumentStart,
        forMainFrameOnly: true
      )

      target.addUserScript(script)
      target.add(FeedbackHandler(), name: "feedback")
      target.add(AudioHandler(), name: "audio")
    } catch {}

    return target
  }
}

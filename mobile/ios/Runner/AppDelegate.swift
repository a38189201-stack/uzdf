import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var methodChannel: FlutterMethodChannel?
  private var secureOverlay: UIView?
  private var methodChannelTimer: Timer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyA6NEfgtmZFEIPrX4MB02jAxvFl8kPoT9s")

    // Subscribe to screenshot notifications
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )

    // NOTE: GeneratedPluginRegistrant is called by FlutterSceneDelegate automatically.
    // Do NOT call it here again to avoid double-registration crash.
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Set up method channel after Flutter engine is ready via window
    // (polls every 100ms until the view controller is ready to ensure registration works 100%)
    self.methodChannelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
      guard let self = self else {
        timer.invalidate()
        return
      }
      if let controller = self.getActiveWindow()?.rootViewController as? FlutterViewController {
        self.methodChannel = FlutterMethodChannel(
          name: "uzdf.security",
          binaryMessenger: controller.binaryMessenger
        )
        self.setupMethodChannel()
        timer.invalidate()
        self.methodChannelTimer = nil
      }
    }

    return result
  }

  @objc private func didTakeScreenshot() {
    methodChannel?.invokeMethod("onScreenshotTaken", arguments: nil)
  }

  private func setupMethodChannel() {
    methodChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "setSecure" {
        let secure: Bool
        if let args = call.arguments as? [String: Any], let s = args["secure"] as? Bool {
          secure = s
        } else if let s = call.arguments as? Bool {
          secure = s
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected boolean", details: nil))
          return
        }
        self.setSecure(secure)
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
  // MARK: — Safe secure overlay (does NOT touch rootViewController.view hierarchy)
  private func setSecure(_ secure: Bool) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let tag = 9911

      if secure {
        // Prevent duplicate overlays in the active window
        guard let window = self.getActiveWindow() else { return }
        guard window.viewWithTag(tag) == nil else { return }

        // Safe approach: place a blurred overlay on top, never moving rootView
        let overlay = UIView(frame: window.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .black
        overlay.tag = tag

        // Blur effect
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = overlay.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addSubview(blurView)

        // Lock icon
        let lockLabel = UILabel()
        lockLabel.text = "🔒"
        lockLabel.font = .systemFont(ofSize: 48)
        lockLabel.sizeToFit()
        lockLabel.center = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY)
        lockLabel.autoresizingMask = [
          .flexibleLeftMargin, .flexibleRightMargin,
          .flexibleTopMargin, .flexibleBottomMargin
        ]
        overlay.addSubview(lockLabel)

        window.addSubview(overlay)
        self.secureOverlay = overlay
      } else {
        // Tag-based cleanup: search all windows of all active scenes to ensure overlay is removed
        if #available(iOS 13.0, *) {
          UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { window in
              window.viewWithTag(tag)?.removeFromSuperview()
            }
        }
        // Fallbacks for older iOS versions / alternative window hierarchies
        UIApplication.shared.keyWindow?.viewWithTag(tag)?.removeFromSuperview()
        self.window?.viewWithTag(tag)?.removeFromSuperview()
        
        self.secureOverlay?.removeFromSuperview()
        self.secureOverlay = nil
      }
    }
  }

  // MARK: — Safe window lookup compatible with iOS 13+ Scenes and iPad
  private func getActiveWindow() -> UIWindow? {
    // Prefer the window already assigned to AppDelegate
    if let window = self.window, !window.isHidden {
      return window
    }
    // For multi-scene iPad (iOS 13+)
    if #available(iOS 13.0, *) {
      return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }
        .flatMap { $0.windows }
        .first(where: { $0.isKeyWindow })
    }
    return UIApplication.shared.keyWindow
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

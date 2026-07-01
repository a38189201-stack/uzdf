import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var methodChannel: FlutterMethodChannel?
  private var secureOverlay: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyClf2QwFJHt9tUK4YguaMyiM6WG64jR3u4")

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
    // (works in both Scene-based and legacy window-based scenarios)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      guard let self = self else { return }
      if let controller = self.window?.rootViewController as? FlutterViewController {
        self.methodChannel = FlutterMethodChannel(
          name: "uzdf.security",
          binaryMessenger: controller.binaryMessenger
        )
        self.setupMethodChannel()
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

      if secure {
        guard self.secureOverlay == nil else { return }
        guard let window = self.getActiveWindow() else { return }

        // Safe approach: place a blurred overlay on top, never moving rootView
        let overlay = UIView(frame: window.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .black

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
}

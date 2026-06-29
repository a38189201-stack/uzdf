import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var methodChannel: FlutterMethodChannel?
  private var secureTextField: UITextField?
  private var secureContainer: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyClf2QwFJHt9tUK4YguaMyiM6WG64jR3u4")
    
    let controller = window?.rootViewController as? FlutterViewController ?? 
      (UIApplication.shared.windows.first?.rootViewController as? FlutterViewController)
      
    if let binaryMessenger = controller?.binaryMessenger {
      methodChannel = FlutterMethodChannel(name: "uzdf.security", binaryMessenger: binaryMessenger)
      methodChannel?.setMethodCallHandler { [weak self] (call, result) in
        guard let self = self else { return }
        if call.method == "setSecure" {
          if let args = call.arguments as? [String: Any], let secure = args["secure"] as? Bool {
            self.setSecure(secure)
            result(true)
          } else if let secure = call.arguments as? Bool {
            self.setSecure(secure)
            result(true)
          } else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected boolean", details: nil))
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // Subscribe to screenshot notifications
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func didTakeScreenshot() {
    methodChannel?.invokeMethod("onScreenshotTaken", arguments: nil)
  }

  private func getActiveWindow() -> UIWindow? {
    if let window = self.window {
      return window
    }
    if #available(iOS 13.0, *) {
      return UIApplication.shared.connectedScenes
        .filter { $0.activationState == .foregroundActive }
        .first(where: { $0 is UIWindowScene })
        .flatMap { $0 as? UIWindowScene }?
        .windows
        .first(where: { $0.isKeyWindow })
    }
    return UIApplication.shared.keyWindow
  }

  private func setSecure(_ secure: Bool) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      guard let window = self.getActiveWindow() else { return }
      
      if secure {
        guard self.secureTextField == nil else { return }
        
        let field = UITextField()
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false
        window.addSubview(field)
        
        if let container = field.subviews.first {
          container.frame = window.bounds
          container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
          window.addSubview(container)
          
          if let rootView = window.rootViewController?.view {
            container.addSubview(rootView)
          }
          self.secureTextField = field
          self.secureContainer = container
        }
      } else {
        guard let field = self.secureTextField, let container = self.secureContainer else { return }
        
        if let rootView = container.subviews.first {
          window.addSubview(rootView)
        }
        
        container.removeFromSuperview()
        field.removeFromSuperview()
        self.secureTextField = nil
        self.secureContainer = nil
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

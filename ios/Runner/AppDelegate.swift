import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var passkeyHandler: AnyObject?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "spectator/passkeys",
            binaryMessenger: controller.binaryMessenger)

        if #available(iOS 16.0, *) {
            let handler = PasskeyHandler()
            passkeyHandler = handler
            channel.setMethodCallHandler { [weak handler] call, result in
                guard let handler = handler else { return }
                guard let args = call.arguments as? [String: Any] else {
                    result(FlutterError(code: "BAD_ARGS",
                                        message: "Expected a Map argument",
                                        details: nil))
                    return
                }
                switch call.method {
                case "createCredential":
                    handler.handleCreateCredential(options: args, result: result)
                case "getCredential":
                    handler.handleGetCredential(options: args, result: result)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        } else {
            channel.setMethodCallHandler { _, result in
                result(FlutterError(code: "UNSUPPORTED",
                                    message: "Passkeys require iOS 16 or later.",
                                    details: nil))
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

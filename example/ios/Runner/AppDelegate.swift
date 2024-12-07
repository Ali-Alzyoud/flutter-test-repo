import UIKit
import Flutter
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate {

    let channelName: String = "PushNotificationChannel"
    var deviceToken: String = ""

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let pushNotificationChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
        
        UNUserNotificationCenter.current().delegate = self

        pushNotificationChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "requestNotificationPermissions":
                self?.requestNotificationPermissions(result: result)
                
            case "registerForPushNotifications":
                self?.registerForPushNotifications(application: application, result: result)
                
            case "retrieveDeviceToken":
                self?.getDeviceToken(result: result)
                
            case "onPushNotificationResponse":
                if let arguments = call.arguments as? [String: Any],
                   let requestId = arguments["requestId"] as? String,
                   let shouldShow = arguments["shouldShow"] as? Bool,
                   let completion = self?.notificationCompletions[requestId] {

                    // Debug print statement
                    print("requestId \(requestId)")

                    // Call the completion handler with the result
                    completion(shouldShow)

                    // Remove the completion handler from the dictionary
                    self?.notificationCompletions.removeValue(forKey: requestId)
                    result(nil) // Indicate completion if needed
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for onPushNotificationResponse", details: nil))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)

        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - Notification Display Handling for Foreground
        
        override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                             willPresent notification: UNNotification,
                                             withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            print("userNotificationCenter willPresent")
            
            let userInfo = notification.request.content.userInfo
          
            // Check if `ItemEntity` exists to decide if notification should be shown
            if let aps = userInfo["aps"] as? [String: Any],
               let itemEntity = aps["ItemEntity"] as? String {
                print("willPresent \(itemEntity)")
                
                handleNotificationWithItemEntity(userInfo: userInfo) { shouldShow in
                    if shouldShow {
                        print("shouldShow \(shouldShow)")
                        if #available(iOS 14.0, *) {
                            completionHandler([.banner, .sound, .badge])
                        } else {
                            print("not shouldShow \(shouldShow)")
                            // Fallback on earlier versions
                            completionHandler([.sound, .badge])

                        } // Show the notification
                    } else {
                        completionHandler([]) // Do not show the notification
                    }
                }
            } else {
                // If no `ItemEntity`, show the notification by default
                if #available(iOS 14.0, *) {
                    completionHandler([.banner, .sound, .badge])
                } else {
                    // Fallback on earlier versions
                    completionHandler([.sound, .badge])
                }
            }
        }
    
    
    // MARK: - Notification Tap Handling
    
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationTap(userInfo: userInfo)
        completionHandler()
    }
    
    private var notificationCompletions = [String: (Bool) -> Void]()

    private func handleNotificationWithItemEntity(userInfo: [AnyHashable: Any], completion: @escaping (Bool) -> Void) {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            completion(true) // Default to true if the controller is not found
            return
        }

        let pushNotificationChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)

        // Generate a unique request ID
        let requestId = UUID().uuidString

        // Store the completion handler with the request ID
        notificationCompletions[requestId] = completion

        // Send the notification data and request ID to Flutter
        var arguments = userInfo
        arguments["requestId"] = requestId

        pushNotificationChannel.invokeMethod("onPushNotificationCheck", arguments: arguments)
    }


    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let controller = window?.rootViewController as? FlutterViewController else { return }
        let pushNotificationChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
        
        // Send the notification data to Flutter
//        if let customData = userInfo["customKey"] as? String {
            pushNotificationChannel.invokeMethod("onPushNotificationTap", arguments: userInfo)
//        }
    }
    
    private func requestNotificationPermissions(result: @escaping FlutterResult) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                result(FlutterError(code: "PERMISSION_ERROR", message: "Failed to request permissions", details: error.localizedDescription))
                return
            }
            result(granted)
        }
    }

    private func registerForPushNotifications(application: UIApplication, result: @escaping FlutterResult) {
        application.registerForRemoteNotifications()
        result("Device Token registration initiated")
    }
    
    private func getDeviceToken(result: @escaping FlutterResult) {
        if deviceToken.isEmpty {
            result(FlutterError(code: "UNAVAILABLE", message: "Device token not available", details: nil))
        } else {
            result(deviceToken)
        }
    }

    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        self.deviceToken = tokenParts.joined()
    }
    
//    override func userNotificationCenter(_ center: UNUserNotificationCenter,
//                                         willPresent notification: UNNotification,
//                                         withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
//        // Show notification even if the app is in the foreground
//        if #available(iOS 14.0, *) {
//            completionHandler([.banner, .sound, .badge])
//        } else {
//            // Fallback on earlier versions
//        }
//    }
}

import Flutter
import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    private let VPN_CHANNEL = "com.theholylabs.network/vpn"
    private let FCM_CHANNEL = "com.theholylabs.network/fcm"
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Don't configure Firebase here - Flutter will do it
        // This prevents the "Firebase app has not yet been configured" warning
        print("🔥 Firebase will be initialized by Flutter")
        
        // Register Flutter plugins first
        GeneratedPluginRegistrant.register(with: self)
        
        let controller = window?.rootViewController as! FlutterViewController
        
        // Setup VPN Method Channel
        setupVPNMethodChannel(controller: controller)
        
        // Setup FCM Method Channel
        setupFCMMethodChannel(controller: controller)
        
        // Configure FCM and notifications AFTER Flutter initializes Firebase
        // We'll do this in a delayed manner to ensure Firebase is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.configureFCMAndNotifications()
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - VPN Method Channel
    
    private func setupVPNMethodChannel(controller: FlutterViewController) {
        let vpnChannel = FlutterMethodChannel(name: VPN_CHANNEL, binaryMessenger: controller.binaryMessenger)
        
        vpnChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handleVPNMethodCall(call: call, result: result)
        }
        
        // Listen for VPN status changes
        NotificationCenter.default.addObserver(
            forName: .vpnStatusChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo {
                vpnChannel.invokeMethod("onVPNStatusChanged", arguments: userInfo)
            }
        }
    }
    
    private func handleVPNMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let vpnManager = VPNManager.shared
        
        switch call.method {
        case "initialize":
            // VPN Manager initializes automatically
            result(true)
            
        case "getCurrentStatus":
            let status = vpnManager.getCurrentStatus()
            result(status)
            
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let serverAddress = args["serverAddress"] as? String,
                  let countryCode = args["countryCode"] as? String,
                  let countryName = args["countryName"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
                return
            }
            
            vpnManager.connectVPN(serverAddress: serverAddress, countryCode: countryCode, countryName: countryName) { success, error in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "VPN_CONNECT_ERROR", message: error, details: nil))
                }
            }
            
        case "disconnect":
            vpnManager.disconnectVPN { success, error in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "VPN_DISCONNECT_ERROR", message: error, details: nil))
                }
            }
            
        case "checkVPNPermission":
            // On iOS, VPN permission is granted when the user allows the VPN configuration
            vpnManager.checkVPNPermission { granted in
                result(granted)
            }
            
        case "requestVPNPermission":
            // On iOS, VPN permission is requested when trying to connect
            vpnManager.requestVPNPermission { granted in
                result(granted)
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - FCM Method Channel
    
    private func setupFCMMethodChannel(controller: FlutterViewController) {
        let fcmChannel = FlutterMethodChannel(name: FCM_CHANNEL, binaryMessenger: controller.binaryMessenger)
        
        fcmChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handleFCMMethodCall(call: call, result: result)
        }
        
        // Listen for FCM token updates
        NotificationCenter.default.addObserver(
            forName: .fcmTokenUpdated,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo {
                fcmChannel.invokeMethod("onFCMTokenUpdated", arguments: userInfo)
            }
        }
    }
    
    private func handleFCMMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let fcmManager = FCMManager.shared
        
        switch call.method {
        case "initialize":
            fcmManager.initialize { success, error in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "FCM_INIT_ERROR", message: error, details: nil))
                }
            }
            
        case "getFCMToken":
            if let token = fcmManager.getFCMToken() {
                result(token)
            } else {
                result(FlutterError(code: "FCM_TOKEN_ERROR", message: "FCM token not available", details: nil))
            }
            
        case "requestNotificationPermissions":
            requestNotificationPermissions { granted in
                result(granted)
            }
            
        case "subscribeToTopic":
            guard let topic = call.arguments as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic is required", details: nil))
                return
            }
            
            fcmManager.subscribeToTopic(topic) { success, error in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "FCM_SUBSCRIBE_ERROR", message: error, details: nil))
                }
            }
            
        case "unsubscribeFromTopic":
            guard let topic = call.arguments as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic is required", details: nil))
                return
            }
            
            fcmManager.unsubscribeFromTopic(topic) { success, error in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "FCM_UNSUBSCRIBE_ERROR", message: error, details: nil))
                }
            }
            
        case "subscribeToSubscriptionTopics":
            guard let isSubscribed = call.arguments as? Bool else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Subscription status is required", details: nil))
                return
            }
            
            fcmManager.subscribeToSubscriptionTopics(isSubscribed: isSubscribed) { success, error in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "FCM_SUBSCRIPTION_TOPICS_ERROR", message: error, details: nil))
                }
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - FCM Configuration (from working mobile project)
    
    private func configureFCMAndNotifications() {
        print("🔥 Configuring FCM without requesting permissions")
        
        // Set up FCM delegate but don't request permissions yet
        Messaging.messaging().delegate = self
        print("📱 FCM delegate set")
        
        // Set up notification center delegate but don't request permissions
        UNUserNotificationCenter.current().delegate = self
        print("🔔 UNUserNotificationCenter delegate set")
        
        print("✅ FCM configured - permissions will be requested from onboarding")
    }
    
    // New method to request notification permissions when called from Flutter
    private func requestNotificationPermissions(completion: @escaping (Bool) -> Void) {
        print("🔔 Requesting notification permissions from Flutter...")
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                print("📱 Notification permission granted: \(granted)")
                if let error = error {
                    print("❌ Notification permission error: \(error)")
                }
                
                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                        print("📱 Registered for remote notifications")
                    }
                }
                
                completion(granted)
            }
        )
    }
    
    private func requestFCMToken() {
        print("🔥 Explicitly requesting FCM token...")
        
        Messaging.messaging().token { token, error in
            if let error = error {
                print("❌ Error fetching FCM registration token: \(error)")
            } else if let token = token {
                print("🔥 FCM registration token received via explicit request: \(token)")
                print("✅ FCM Token: \(token)")
                print("📱 Token length: \(token.count)")
            } else {
                print("❌ FCM token is nil")
            }
        }
    }
    
    // Handle APNs token registration
    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 APNs token registered successfully")
        
        // Set the APNS token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        
        // Now set up FCM delegate and request token
        Messaging.messaging().delegate = self
        print("📱 FCM delegate set after APNS token")
        
        // Request FCM token after APNS token is set
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.requestFCMToken()
        }
    }
    
    // Handle APNs registration failure
    override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 FCM registration token received: \(String(describing: fcmToken))")
        
        if let token = fcmToken {
            print("✅ FCM Token: \(token)")
            print("📱 Token length: \(token.count)")
        } else {
            print("❌ FCM Token is nil")
        }
        
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate {
    // Handle notifications when app is in foreground
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                          willPresent notification: UNNotification,
                          withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("📱 Foreground notification received: \(userInfo)")
        
        // Show notification even when app is in foreground
        completionHandler([[.alert, .badge, .sound]])
    }
    
    // Handle notification tap
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                          didReceive response: UNNotificationResponse,
                          withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 Notification tapped: \(userInfo)")
        
        // Handle notification tap - you can add navigation logic here
        completionHandler()
    }
}

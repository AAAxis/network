import Flutter
import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications
import RevenueCat
import RevenueCatUI
import SwiftUI
import XRayVPNFramework

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    private let VPN_CHANNEL = "com.theholylabs.network/vpn"
    private let FCM_CHANNEL = "com.theholylabs.network/fcm"
    private let PAYWALL_CHANNEL = "com.theholylabs.network/paywall"
    private let XRAY_CHANNEL = "native_xray"
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
        
        print("📱 iOS AppDelegate: didFinishLaunchingWithOptions called")
        
        // Initialize XRayVPN first (as per README step 14)
        print("🚀 Initializing XRayVPN...")
        Task {
            await XRayVPN.initialize(
                appGroup: "group.com.theholylabs.network",
                tunnelBundleId: "com.theholylabs.network.PacketTunnelProvider",
                completion: {
                    print("✅ XRayVPN initialized successfully")
                }
            )
        }
        
        // Don't configure Firebase here - Flutter will do it
        // This prevents the "Firebase app has not yet been configured" warning
        print("🔥 Firebase will be initialized by Flutter")
        
        print("📦 Registering Flutter plugins...")
        // Register Flutter plugins first
        GeneratedPluginRegistrant.register(with: self)
        print("✅ Flutter plugins registered")
        
        print("🔍 Checking for FlutterViewController...")
        print("   - Window exists: \(window != nil)")
        print("   - RootViewController exists: \(window?.rootViewController != nil)")
        print("   - RootViewController type: \(type(of: window?.rootViewController ?? UIViewController()))")
        
        guard let controller = window?.rootViewController as? FlutterViewController else {
            print("❌ ERROR: Could not get FlutterViewController")
            print("   Attempting to call super.application anyway...")
            let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
            print("   Super returned: \(result)")
            return result
        }
        
        print("✅ FlutterViewController found: \(controller)")
        
        // Setup VPN Method Channel
        print("🔧 Setting up VPN Method Channel...")
        setupVPNMethodChannel(controller: controller)
        
        // Setup FCM Method Channel
        print("🔧 Setting up FCM Method Channel...")
        setupFCMMethodChannel(controller: controller)
        
        // Setup Paywall Method Channel
        print("🔧 Setting up Paywall Method Channel...")
        setupPaywallMethodChannel(controller: controller)
        
        // Setup XRay/VLESS Method Channel
        print("🔧 Setting up XRay/VLESS Method Channel...")
        setupXRayMethodChannel(controller: controller)
        
        // Configure FCM and notifications AFTER Flutter initializes Firebase
        // We'll do this in a delayed manner to ensure Firebase is ready
        print("⏰ Scheduling FCM configuration in 1 second...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("⏰ FCM configuration time - calling configureFCMAndNotifications...")
            self.configureFCMAndNotifications()
        }
        
        print("📱 Calling super.application...")
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        print("✅ super.application returned: \(result)")
        print("📱 AppDelegate: didFinishLaunchingWithOptions completed")
        return result
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
                  let username = args["username"] as? String,
                  let password = args["password"] as? String,
                  let sharedSecret = args["sharedSecret"] as? String,
                  let countryCode = args["countryCode"] as? String,
                  let countryName = args["countryName"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                return
            }
            
            vpnManager.connectVPN(serverAddress: serverAddress, username: username, password: password, sharedSecret: sharedSecret, countryCode: countryCode, countryName: countryName) { success, error in
                result(success)
            }
            
        case "disconnect":
            vpnManager.disconnectVPN { success, error in
                result(success)
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
            if let topic = call.arguments as? String {
                Messaging.messaging().subscribe(toTopic: topic) { error in
                    if let error = error {
                        result(FlutterError(code: "FCM_SUBSCRIBE_ERROR", message: error.localizedDescription, details: nil))
                    } else {
                        result(true)
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Topic is required", details: nil))
            }
            
        case "unsubscribeFromTopic":
            if let topic = call.arguments as? String {
                Messaging.messaging().unsubscribe(fromTopic: topic) { error in
                    if let error = error {
                        result(FlutterError(code: "FCM_UNSUBSCRIBE_ERROR", message: error.localizedDescription, details: nil))
                    } else {
                        result(true)
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Topic is required", details: nil))
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - FCM Configuration
    
    private func configureFCMAndNotifications() {
        // This is called after Flutter initializes Firebase
        // Set up notification delegates - FCMManager handles MessagingDelegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register for remote notifications
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    private func requestNotificationPermissions(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Error requesting notification permissions: \(error)")
                completion(false)
                return
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
            
            completion(granted)
        }
    }
    
    // MARK: - Paywall Method Channel
    
    private func setupPaywallMethodChannel(controller: FlutterViewController) {
        let paywallChannel = FlutterMethodChannel(name: PAYWALL_CHANNEL, binaryMessenger: controller.binaryMessenger)
        
        paywallChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handlePaywallMethodCall(call: call, result: result)
        }
    }
    
    private func handlePaywallMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "presentPaywall":
            Task { @MainActor in
                do {
                    // Get current offering from RevenueCat
                    let offerings = try await Purchases.shared.offerings()
                    guard let offering = offerings.current else {
                        result(FlutterError(code: "NO_OFFERING", message: "No current offering available", details: nil))
                        return
                    }
                    
                    // Present native RevenueCat paywall using templates configured in dashboard
                    guard let rootViewController = window?.rootViewController else {
                        result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller", details: nil))
                        return
                    }
                    
                    // Create SwiftUI paywall view using native RevenueCat templates
                    let paywallView = PaywallView(offering: offering)
                    
                    // Create hosting controller
                    let hostingController = UIHostingController(rootView: paywallView)
                    hostingController.modalPresentationStyle = .pageSheet
                    if let sheet = hostingController.sheetPresentationController {
                        sheet.detents = [.large()]
                        sheet.prefersGrabberVisible = true
                    }
                    
                    // Present the paywall
                    rootViewController.present(hostingController, animated: true) {
                        result(true)
                    }
                    
                    // Listen for purchase completion (dismisses automatically)
                    // RevenueCat handles the purchase flow natively
                    
                } catch {
                    print("❌ Error presenting paywall: \(error)")
                    result(FlutterError(code: "PAYWALL_ERROR", message: error.localizedDescription, details: nil))
                }
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - XRay/VLESS Method Channel
    
    private func setupXRayMethodChannel(controller: FlutterViewController) {
        let xrayChannel = FlutterMethodChannel(name: XRAY_CHANNEL, binaryMessenger: controller.binaryMessenger)
        
        xrayChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handleXRayMethodCall(call: call, result: result)
        }
        
        // Listen for VPN status changes for VLESS connections
        NotificationCenter.default.addObserver(
            forName: .vpnStatusChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo {
                xrayChannel.invokeMethod("onVPNStatusChanged", arguments: userInfo)
            }
        }
    }
    
    private func handleXRayMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let xrayManager = XRayManager.shared
        
        switch call.method {
        case "connectVless":
            guard let args = call.arguments as? [String: Any],
                  let vlessUri = args["vlessUri"] as? String,
                  let countryCode = args["countryCode"] as? String,
                  let countryName = args["countryName"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                return
            }
            
            xrayManager.connectVless(vlessUri: vlessUri, countryCode: countryCode, countryName: countryName) { success, error in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "VLESS_CONNECT_ERROR", message: error ?? "Connection failed", details: nil))
                }
            }
            
        case "disconnectVless":
            xrayManager.disconnectVless { success, error in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "VLESS_DISCONNECT_ERROR", message: error ?? "Disconnect failed", details: nil))
                }
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
// Note: Notification.Name extensions are defined in VPNManager.swift and FCMManager.swift
// Note: MessagingDelegate is handled by FCMManager
// Note: FlutterAppDelegate already conforms to UNUserNotificationCenterDelegate, so we override methods

extension AppDelegate {
    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 Notification tapped: \(userInfo)")
        completionHandler()
    }
}

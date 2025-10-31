//
//  FCMManager.swift
//  Runner
//
//  Created for Flutter VPN App
//

import Foundation
import Firebase
import FirebaseMessaging
import UserNotifications

class FCMManager: NSObject {
    static let shared = FCMManager()
    
    private var fcmToken: String?
    
    override init() {
        super.init()
        setupFirebase()
    }
    
    private func setupFirebase() {
        // Configure Firebase
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Set FCM delegate
        Messaging.messaging().delegate = self
        
        // Request notification permissions
        requestNotificationPermissions()
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Error requesting notification permissions: \(error)")
                return
            }
            
            print("📱 Notification permissions granted: \(granted)")
            
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    // MARK: - Public Methods for Flutter
    
    func initialize(completion: @escaping (Bool, String?) -> Void) {
        // Get FCM token
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("❌ Error fetching FCM token: \(error)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let token = token else {
                completion(false, "FCM token is nil")
                return
            }
            
            self?.fcmToken = token
            print("🔥 FCM Token: \(token)")
            completion(true, nil)
        }
    }
    
    func getFCMToken() -> String? {
        return fcmToken
    }
    
    func subscribeToTopic(_ topic: String, completion: @escaping (Bool, String?) -> Void) {
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error = error {
                print("❌ Error subscribing to topic \(topic): \(error)")
                completion(false, error.localizedDescription)
            } else {
                print("✅ Subscribed to topic: \(topic)")
                completion(true, nil)
            }
        }
    }
    
    func unsubscribeFromTopic(_ topic: String, completion: @escaping (Bool, String?) -> Void) {
        Messaging.messaging().unsubscribe(fromTopic: topic) { error in
            if let error = error {
                print("❌ Error unsubscribing from topic \(topic): \(error)")
                completion(false, error.localizedDescription)
            } else {
                print("✅ Unsubscribed from topic: \(topic)")
                completion(true, nil)
            }
        }
    }
    
    func subscribeToSubscriptionTopics(isSubscribed: Bool, completion: @escaping (Bool, String?) -> Void) {
        let topic = isSubscribed ? "premium_users" : "free_users"
        let unsubscribeTopic = isSubscribed ? "free_users" : "premium_users"
        
        // Unsubscribe from old topic
        unsubscribeFromTopic(unsubscribeTopic) { [weak self] _, _ in
            // Subscribe to new topic
            self?.subscribeToTopic(topic, completion: completion)
        }
    }
}

// MARK: - MessagingDelegate

extension FCMManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        
        self.fcmToken = fcmToken
        print("🔥 FCM Token updated: \(fcmToken)")
        
        // Notify Flutter about token update
        NotificationCenter.default.post(
            name: .fcmTokenUpdated,
            object: nil,
            userInfo: ["token": fcmToken]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let fcmTokenUpdated = Notification.Name("fcmTokenUpdated")
}

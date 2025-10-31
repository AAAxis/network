import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _fcmToken;

  // Get FCM token
  static String? get fcmToken => _fcmToken;

  // Initialize FCM (without requesting permissions)
  static Future<void> initialize() async {
    try {
      print('🔥 FCM: Initializing without requesting permissions');
      
      // Set up message handlers without requesting permissions
      _setupMessageHandlers();
      
      print('✅ FCM: Initialized (permissions will be requested from onboarding)');
    } catch (e) {
      print('❌ FCM: Error initializing: $e');
    }
  }

  // Request permissions and get token (called from onboarding)
  static Future<bool> requestPermissionsAndGetToken() async {
    try {
      print('🔔 FCM: Requesting permissions from onboarding...');
      
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ FCM: Notification permissions granted');
        
        // Get FCM token
        await _getFCMToken();
        
        return true;
      } else {
        print('❌ FCM: Notification permissions denied');
        return false;
      }
    } catch (e) {
      print('❌ FCM: Error requesting permissions: $e');
      return false;
    }
  }

  // Get FCM token
  static Future<void> _getFCMToken() async {
    try {
      final token = await _messaging.getToken();
      
      if (token != null) {
        _fcmToken = token;
        print('🔥 FCM Token: $token');
      } else {
        print('⚠️ FCM: No token available');
      }
    } catch (e) {
      print('❌ FCM: Error fetching token: $e');
    }
  }

  // Set up message handlers
  static void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 FCM: Foreground message received: ${message.messageId}');
      print('📱 FCM: Message data: ${message.data}');
      print('📱 FCM: Message notification: ${message.notification?.title}');
    });

    // Handle background message when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 FCM: Message opened app: ${message.messageId}');
      print('📱 FCM: Message data: ${message.data}');
    });
  }
}


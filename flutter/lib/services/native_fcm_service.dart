import 'package:flutter/services.dart';
import 'dart:io';

// Platform-specific imports
import 'native_fcm_service_ios.dart';

class NativeFCMService {
  static const MethodChannel _channel = MethodChannel('com.theholylabs.network/fcm');
  
  // Callback for notification taps
  static Function(Map<dynamic, dynamic>)? onNotificationTap;
  
  // Initialize native FCM service
  static Future<void> initialize() async {
    if (Platform.isIOS) {
      // Use native iOS implementation
      await NativeFCMServiceIOS.initialize();
    } else {
      // Use Android implementation
      try {
        // Set up method call handler for native -> Flutter communication
        _channel.setMethodCallHandler(_handleMethodCall);
        
        print('✅ Native FCM Service initialized');
      } catch (e) {
        print('❌ Error initializing Native FCM Service: $e');
      }
    }
  }
  
  // Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationTap':
        final data = call.arguments as Map<dynamic, dynamic>;
        print('📱 Notification tapped: $data');
        onNotificationTap?.call(data);
        break;
      default:
        print('⚠️ Unknown method call: ${call.method}');
    }
  }
  
  // Get FCM token from native code
  static Future<String?> getFCMToken() async {
    if (Platform.isIOS) {
      // Use native iOS implementation
      return await NativeFCMServiceIOS.getFCMToken();
    } else {
      // Use Android implementation
      try {
        final String? token = await _channel.invokeMethod('getFCMToken');
        if (token != null && token.isNotEmpty) {
          print('🔥 FCM Token from native: $token');
          return token;
        } else {
          print('⚠️ FCM Token is null or empty');
          return null;
        }
      } catch (e) {
        print('❌ Error getting FCM token from native: $e');
        return null;
      }
    }
  }
  
  // Subscribe to a topic
  static Future<bool> subscribeToTopic(String topic) async {
    if (Platform.isIOS) {
      // Use native iOS implementation
      return await NativeFCMServiceIOS.subscribeToTopic(topic);
    } else {
      // Use Android implementation
      try {
        await _channel.invokeMethod('subscribeToTopic', topic);
        print('✅ Subscribed to topic: $topic');
        return true;
      } catch (e) {
        print('❌ Error subscribing to topic $topic: $e');
        return false;
      }
    }
  }
  
  // Unsubscribe from a topic
  static Future<bool> unsubscribeFromTopic(String topic) async {
    if (Platform.isIOS) {
      // Use native iOS implementation
      return await NativeFCMServiceIOS.unsubscribeFromTopic(topic);
    } else {
      // Use Android implementation
      try {
        await _channel.invokeMethod('unsubscribeFromTopic', topic);
        print('✅ Unsubscribed from topic: $topic');
        return true;
      } catch (e) {
        print('❌ Error unsubscribing from topic $topic: $e');
        return false;
      }
    }
  }
  
  // Subscribe to subscription tier topics
  static Future<void> subscribeToSubscriptionTopics(bool isSubscribed) async {
    if (Platform.isIOS) {
      // Use native iOS implementation
      await NativeFCMServiceIOS.subscribeToSubscriptionTopics(isSubscribed);
    } else {
      // Use Android implementation - manual topic management
      if (isSubscribed) {
        await subscribeToTopic('premium_users');
        await unsubscribeFromTopic('free_users');
      } else {
        await subscribeToTopic('free_users');
        await unsubscribeFromTopic('premium_users');
      }
    }
  }
  
  // Get FCM token from SharedPreferences (fallback)
  static Future<String?> getFCMTokenFromPrefs() async {
    try {
      // This reads the token that was saved by native code
      // You can access it via shared_preferences plugin
      return null; // Implement with shared_preferences if needed
    } catch (e) {
      print('❌ Error getting FCM token from preferences: $e');
      return null;
    }
  }
}


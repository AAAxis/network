import 'package:flutter/services.dart';

class NativeFCMServiceIOS {
  static const MethodChannel _channel = MethodChannel('com.theholylabs.network/fcm');
  
  static Function(Map<dynamic, dynamic>)? onFCMTokenUpdated;
  
  static Future<void> initialize() async {
    try {
      // Set up method call handler for callbacks from native
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Initialize native FCM manager
      await _channel.invokeMethod('initialize');
      print('✅ iOS FCM Service initialized');
    } catch (e) {
      print('❌ Error initializing iOS FCM Service: $e');
      rethrow;
    }
  }
  
  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onFCMTokenUpdated':
        if (onFCMTokenUpdated != null) {
          onFCMTokenUpdated!(call.arguments as Map<dynamic, dynamic>);
        }
        break;
      default:
        print('⚠️ Unhandled method call: ${call.method}');
    }
  }
  
  static Future<String?> getFCMToken() async {
    try {
      final token = await _channel.invokeMethod('getFCMToken');
      return token as String?;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }
  
  static Future<bool> subscribeToTopic(String topic) async {
    try {
      await _channel.invokeMethod('subscribeToTopic', topic);
      return true;
    } catch (e) {
      print('❌ Error subscribing to topic $topic: $e');
      return false;
    }
  }
  
  static Future<bool> unsubscribeFromTopic(String topic) async {
    try {
      await _channel.invokeMethod('unsubscribeFromTopic', topic);
      return true;
    } catch (e) {
      print('❌ Error unsubscribing from topic $topic: $e');
      return false;
    }
  }
  
  static Future<bool> subscribeToSubscriptionTopics(bool isSubscribed) async {
    try {
      await _channel.invokeMethod('subscribeToSubscriptionTopics', isSubscribed);
      return true;
    } catch (e) {
      print('❌ Error subscribing to subscription topics: $e');
      return false;
    }
  }
}


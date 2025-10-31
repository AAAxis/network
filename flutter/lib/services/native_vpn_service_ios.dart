import 'package:flutter/services.dart';

class NativeVPNServiceIOS {
  static const MethodChannel _channel = MethodChannel('com.theholylabs.network/vpn');
  
  static Function(Map<dynamic, dynamic>)? onVPNStatusChanged;
  
  static Future<void> initialize() async {
    try {
      // Set up method call handler for callbacks from native
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Initialize native VPN manager
      await _channel.invokeMethod('initialize');
      print('✅ iOS VPN Service initialized');
    } catch (e) {
      print('❌ Error initializing iOS VPN Service: $e');
      rethrow;
    }
  }
  
  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onVPNStatusChanged':
        if (onVPNStatusChanged != null) {
          onVPNStatusChanged!(call.arguments as Map<dynamic, dynamic>);
        }
        break;
      default:
        print('⚠️ Unhandled method call: ${call.method}');
    }
  }
  
  static Future<Map<String, dynamic>> getCurrentStatus() async {
    try {
      final result = await _channel.invokeMethod('getCurrentStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('❌ Error getting VPN status: $e');
      return {'status': 'error', 'isConnected': false};
    }
  }
  
  static Future<bool> connect({
    required String serverAddress,
    required String username,
    required String password,
    required String sharedSecret,
    required String countryCode,
    required String countryName,
  }) async {
    try {
      await _channel.invokeMethod('connect', {
        'serverAddress': serverAddress,
        'username': username,
        'password': password,
        'sharedSecret': sharedSecret,
        'countryCode': countryCode,
        'countryName': countryName,
      });
      return true;
    } catch (e) {
      print('❌ Error connecting VPN: $e');
      return false;
    }
  }
  
  static Future<bool> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
      return true;
    } catch (e) {
      print('❌ Error disconnecting VPN: $e');
      return false;
    }
  }
}


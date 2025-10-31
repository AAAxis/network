import 'dart:io';
import 'package:flutter/services.dart';

class FlutterV2RayService {
  static const MethodChannel _channel = MethodChannel('native_xray');
  static Function(Map<String, dynamic>)? _onStatusChanged;
  static String _currentStatus = 'disconnected';
  static bool _isConnected = false;
  
  // Initialize native XRay service (uses platform channels)
  static Future<void> initialize() async {
    try {
      print('🔧 Initializing Native XRay/VLESS service...');
      
      if (!Platform.isIOS) {
        print('⚠️ VLESS/XRay is currently only supported on iOS');
        return;
      }
      
      // Set up method call handler for native -> Flutter communication
      _channel.setMethodCallHandler(_handleMethodCall);
      
      print('✅ Native XRay/VLESS service initialized');
    } catch (e) {
      print('❌ Error initializing Native XRay service: $e');
      rethrow;
    }
  }
  
  // Handle method calls from native iOS code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('📱 Native XRay method call received: ${call.method}');
    switch (call.method) {
      case 'onVPNStatusChanged':
        final data = call.arguments as Map<dynamic, dynamic>;
        final status = data['status'] as String? ?? 'unknown';
        final isConnected = data['isConnected'] as bool? ?? false;
        
        print('📊 VLESS/XRay Status changed from native: $status (connected: $isConnected)');
        
        // Update internal status tracking
        _currentStatus = status;
        _isConnected = isConnected;
        
        // Notify callback
        if (_onStatusChanged != null) {
          final Map<String, dynamic> statusData = {
            'status': _currentStatus,
            'isConnected': _isConnected,
          };
          _onStatusChanged!(statusData);
        }
        break;
      default:
        print('⚠️ Unknown XRay method call: ${call.method}');
    }
  }
  
  
  // Set status change callback
  static void setOnStatusChanged(Function(Map<String, dynamic>) callback) {
    _onStatusChanged = callback;
  }
  
  // Connect using VLESS URI via native iOS implementation
  static Future<Map<String, dynamic>> connect({
    required String vlessUri,
    required String countryCode,
    required String countryName,
  }) async {
    try {
      if (!Platform.isIOS) {
        return {
          'success': false,
          'error': 'VLESS/XRay is currently only supported on iOS',
        };
      }
      
      print('🔗 Calling native iOS XRay service...');
      print('📍 Server: $countryName ($countryCode)');
      print('🔗 VLESS URI: $vlessUri');
      
      // Call native iOS via method channel
      final result = await _channel.invokeMethod('connectVless', {
        'vlessUri': vlessUri,
        'countryCode': countryCode,
        'countryName': countryName,
      });
      
      print('📱 Native iOS result: $result');
      
      // If result is a bool and true, connection succeeded
      if (result is bool && result == true) {
        print('✅ VLESS/XRay connection started successfully');
        return {'success': true};
      }
      
      return {'success': false, 'error': 'Connection failed from native side'};
    } on PlatformException catch (e) {
      print('❌ PlatformException in native XRay service: ${e.code} - ${e.message}');
      return {
        'success': false,
        'error': e.message ?? 'Connection failed',
        'code': e.code,
      };
    } catch (e) {
      print('❌ General exception in native XRay service: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Disconnect VLESS/XRay
  static Future<bool> disconnect() async {
    try {
      if (!Platform.isIOS) {
        print('⚠️ VLESS/XRay is currently only supported on iOS');
        return false;
      }
      
      print('🛑 Stopping VLESS/XRay connection...');
      final bool? success = await _channel.invokeMethod('disconnectVless');
      print('✅ VLESS/XRay connection stopped');
      return success == true;
    } catch (e) {
      print('❌ Error disconnecting VLESS/XRay: $e');
      return false;
    }
  }
  
  // Get current status (tracked via callback since package doesn't expose getter)
  static Future<Map<String, dynamic>> getCurrentStatus() async {
    // Return internally tracked status (updated via onStatusChanged callback)
    return {
      'status': _currentStatus,
      'isConnected': _isConnected,
    };
  }
}

import 'dart:io';
import 'package:flutter/services.dart';

class NativeXRayService {
  static const MethodChannel _channel = MethodChannel('native_xray');

  static Future<void> initialize() async {
    // No-op for now; reserved for future use
  }

  static Future<Map<String, dynamic>> connect({
    required String vlessUri,
    required String countryCode,
    required String countryName,
  }) async {
    try {
      if (!Platform.isIOS) {
        // Currently only iOS client is supported for XRay framework
        return {'success': false, 'error': 'VLESS is currently only supported on iOS'};
      }

      print('🔗 Calling native iOS XRay service...');
      
      final result = await _channel.invokeMethod('connectVless', {
        'vlessUri': vlessUri,
        'countryCode': countryCode,
        'countryName': countryName,
      });
      
      print('📱 Native iOS result: $result');
      
      // If result is a bool and true, connection succeeded
      if (result is bool && result == true) {
        return {'success': true};
      }
      
      return {'success': false, 'error': 'Connection failed from native side'};
    } on PlatformException catch (e) {
      print('❌ PlatformException in native XRay service: ${e.code} - ${e.message}');
      // Handle platform-specific errors
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

  static Future<bool> disconnect() async {
    try {
      if (!Platform.isIOS) return false;
      final bool? success = await _channel.invokeMethod('disconnectVless');
      return success == true;
    } catch (e) {
      print('❌ Error disconnecting VLESS: $e');
      return false;
    }
  }
}
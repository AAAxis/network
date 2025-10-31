import 'dart:io';
import 'package:flutter/services.dart';

// Platform-specific imports
import 'native_vpn_service_ios.dart';

class NativeVPNService {
  static const MethodChannel _channel = MethodChannel('com.theholylabs.network/vpn');
  
  // Callback for VPN status changes
  static Function(Map<dynamic, dynamic>)? onVPNStatusChanged;
  
  // Initialize native VPN service
  static Future<void> initialize() async {
    if (Platform.isIOS) {
      // Use native iOS implementation
      NativeVPNServiceIOS.onVPNStatusChanged = onVPNStatusChanged;
      await NativeVPNServiceIOS.initialize();
    } else {
      // Use Android implementation
      try {
        // Set up method call handler for native -> Flutter communication
        _channel.setMethodCallHandler(_handleMethodCall);
        
        print('✅ Native VPN Service initialized');
      } catch (e) {
        print('❌ Error initializing Native VPN Service: $e');
      }
    }
  }
  
  // Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('📱 Native method call received: ${call.method}');
    switch (call.method) {
      case 'onVPNStatusChanged':
        final data = call.arguments as Map<dynamic, dynamic>;
        print('📊 VPN Status changed from native: ${data['status']} (data: $data)');
        if (onVPNStatusChanged != null) {
          onVPNStatusChanged?.call(data);
          print('📊 VPN Status callback called');
        } else {
          print('⚠️ VPN Status callback is null!');
        }
        break;
      case 'onVPNPermissionResult':
        final granted = call.arguments as bool;
        print('📱 VPN Permission result: $granted');
        // Permission result is handled automatically by the system
        break;
      default:
        print('⚠️ Unknown method call: ${call.method}');
    }
  }
  
  // Check if VPN permission is granted
  static Future<bool> checkVPNPermission() async {
    try {
      final bool? granted = await _channel.invokeMethod('checkVPNPermission');
      return granted ?? false;
    } catch (e) {
      print('❌ Error checking VPN permission: $e');
      return false;
    }
  }
  
  // Request VPN permission
  static Future<bool> requestVPNPermission() async {
    try {
      final bool? success = await _channel.invokeMethod('requestVPNPermission');
      return success ?? false;
    } catch (e) {
      print('❌ Error requesting VPN permission: $e');
      return false;
    }
  }
  
  // Connect to VPN server
  static Future<bool> connect({
    required String serverAddress,
    required String username,
    required String password,
    required String sharedSecret,
    required String countryCode,
    required String countryName,
  }) async {
    if (Platform.isIOS) {
      // Use native iOS implementation (pass credentials from Remote Config)
      return await NativeVPNServiceIOS.connect(
        serverAddress: serverAddress,
        username: username,
        password: password,
        sharedSecret: sharedSecret,
        countryCode: countryCode,
        countryName: countryName,
      );
    } else {
      // Use Android implementation
      try {
        print('🔄 Connecting to VPN: $serverAddress ($countryName)');
        
        final bool? success = await _channel.invokeMethod('connect', {
          'serverAddress': serverAddress,
          'username': username,
          'password': password,
          'sharedSecret': sharedSecret,
          'countryCode': countryCode,
          'countryName': countryName,
        });
        
        if (success == true) {
          print('✅ VPN connection initiated');
          return true;
        } else {
          print('❌ VPN connection failed');
          return false;
        }
      } catch (e) {
        print('❌ Error connecting to VPN: $e');
        return false;
      }
    }
  }
  
  // Disconnect from VPN
  static Future<bool> disconnect() async {
    if (Platform.isIOS) {
      // Use native iOS implementation
      return await NativeVPNServiceIOS.disconnect();
    } else {
      // Use Android implementation
      try {
        print('🔄 Disconnecting from VPN...');
        
        final bool? success = await _channel.invokeMethod('disconnect');
        
        if (success == true) {
          print('✅ VPN disconnected');
          return true;
        } else {
          print('❌ VPN disconnection failed');
          return false;
        }
      } catch (e) {
        print('❌ Error disconnecting from VPN: $e');
        return false;
      }
    }
  }
  
  // Check if VPN is connected
  static Future<bool> isConnected() async {
    try {
      final bool? connected = await _channel.invokeMethod('isConnected');
      return connected ?? false;
    } catch (e) {
      print('❌ Error checking VPN connection status: $e');
      return false;
    }
  }
  
  // Get connection duration in seconds
  static Future<int> getConnectionDuration() async {
    try {
      final int? duration = await _channel.invokeMethod('getConnectionDuration');
      return duration ?? 0;
    } catch (e) {
      print('❌ Error getting connection duration: $e');
      return 0;
    }
  }
  
  // Test server connectivity
  static Future<bool> testServerConnectivity(String serverAddress, {int port = 500}) async {
    try {
      final bool? reachable = await _channel.invokeMethod('testServerConnectivity', {
        'serverAddress': serverAddress,
        'port': port,
      });
      
      if (reachable == true) {
        print('✅ Server $serverAddress is reachable');
        return true;
      } else {
        print('❌ Server $serverAddress is not reachable');
        return false;
      }
    } catch (e) {
      print('❌ Error testing server connectivity: $e');
      return false;
    }
  }
  
  // Get VPN status as string
  static Future<String> getVPNStatus() async {
    final connected = await isConnected();
    if (connected) {
      final duration = await getConnectionDuration();
      return 'Connected (${_formatDuration(duration)})';
    } else {
      return 'Disconnected';
    }
  }
  
  // Format duration
  static String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }
}


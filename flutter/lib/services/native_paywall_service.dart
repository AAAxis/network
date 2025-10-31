import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class NativePaywallService {
  static const MethodChannel _channel = MethodChannel('com.theholylabs.network/paywall');

  /// Present RevenueCat native paywall (uses templates configured in RevenueCat dashboard)
  static Future<bool> presentPaywall({
    required BuildContext context,
    required String source,
    String? serverCountry,
    VoidCallback? onPurchaseCompleted,
    VoidCallback? onRestoreCompleted,
    VoidCallback? onDismiss,
  }) async {
    try {
      print('📱 Presenting RevenueCat native paywall from: $source');
      
      if (Platform.isIOS) {
        // Use native iOS paywall with templates
        final result = await _channel.invokeMethod<bool>('presentPaywall');
        
        // Check if purchase completed
        if (result == true) {
          // Wait a bit for purchase to complete, then check entitlements
          await Future.delayed(const Duration(seconds: 2));
          
          final customerInfo = await Purchases.getCustomerInfo();
          if (customerInfo.entitlements.active.isNotEmpty) {
            print('✅ Purchase completed!');
            if (onPurchaseCompleted != null) {
              onPurchaseCompleted();
            }
            return true;
          }
        }
        
        if (onDismiss != null) {
          onDismiss();
        }
        
        return result ?? false;
      } else {
        // Android fallback - use RevenueCat UI plugin if available
        // For now, show a simple message
        print('⚠️ Android native paywall not yet implemented');
        if (onDismiss != null) onDismiss();
        return false;
      }
    } catch (e) {
      print('❌ Error presenting native paywall: $e');
      if (onDismiss != null) onDismiss();
      return false;
    }
  }
  
  /// Check subscription status
  static Future<bool> isSubscribed() async {
    try {
      final purchaserInfo = await Purchases.getCustomerInfo();
      return purchaserInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      print('❌ Error checking subscription status: $e');
      return false;
    }
  }
  
  /// Restore purchases
  static Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      print('❌ Error restoring purchases: $e');
      return false;
    }
  }
}


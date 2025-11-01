import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
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
        // Android: Use RevenueCat UI
        try {
          // Get offerings from RevenueCat
          final offerings = await Purchases.getOfferings();
          
          if (offerings.current != null) {
            // Show paywall using RevenueCat UI
            final result = await RevenueCatUI.presentPaywall(
              offering: offerings.current!,
              displayCloseButton: false,
            );
            
            print('📱 Paywall result: $result');
            
            // Handle result
            if (result == PaywallResult.purchased) {
              print('✅ Purchase completed');
              if (onPurchaseCompleted != null) {
                onPurchaseCompleted();
              }
              return true;
            } else if (result == PaywallResult.restored) {
              print('✅ Restore completed');
              if (onRestoreCompleted != null) {
                onRestoreCompleted();
              }
              return true;
            } else if (result == PaywallResult.cancelled || result == PaywallResult.notPresented) {
              print('🚪 Paywall cancelled or not presented');
              if (onDismiss != null) {
                onDismiss();
              }
              return false;
            } else if (result == PaywallResult.error) {
              print('❌ Paywall error occurred');
              if (onDismiss != null) {
                onDismiss();
              }
              return false;
            }
            
            if (onDismiss != null) {
              onDismiss();
            }
            return false;
          } else {
            print('⚠️ No current offering available');
            if (onDismiss != null) onDismiss();
            return false;
          }
        } catch (e) {
          print('❌ Error showing Android paywall: $e');
        if (onDismiss != null) onDismiss();
        return false;
        }
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


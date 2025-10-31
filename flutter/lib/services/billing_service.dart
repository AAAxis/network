import 'package:purchases_flutter/purchases_flutter.dart';

class BillingService {
  /// Initialize billing service
  Future<void> initialize() async {
    try {
      print('💰 Initializing billing service...');
      
      // RevenueCat is already configured in main(), so we just verify it's ready
      final customerInfo = await Purchases.getCustomerInfo();
      print('✅ Billing service initialized - Customer ID: ${customerInfo.originalAppUserId}');
    } catch (e) {
      print('❌ Error initializing billing service: $e');
      // Don't throw - app should still work without billing
    }
  }
}


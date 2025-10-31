import 'package:flutter/foundation.dart';

class SubscriptionProvider with ChangeNotifier {
  bool _isSubscribed = false;
  String _errorMessage = '';

  bool get isSubscribed => _isSubscribed;
  String get errorMessage => _errorMessage;

  // Simple status text for UI
  String getSubscriptionStatusText() {
    return _isSubscribed ? 'Premium active' : 'Free plan';
  }

  // Expiry date if subscribed; null when not available
  DateTime? getSubscriptionExpiryDate() {
    return null;
  }

  // Return empty list to avoid UI rendering package tiles when not initialized
  List<dynamic> getAvailablePackages() {
    return const [];
  }

  // Stub purchase flow; integrate real billing later
  Future<bool> purchaseSubscription(dynamic package) async {
    try {
      _errorMessage = '';
      // Simulate success path toggle
      _isSubscribed = true;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    try {
      _errorMessage = '';
      // Keep as no-op for now
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Check if user has access to a server
  bool isServerAccessible(bool isPremium) {
    // Free servers are always accessible
    if (!isPremium) return true;
    
    // Premium servers require subscription
    return _isSubscribed;
  }
}



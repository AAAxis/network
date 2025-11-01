import 'dart:io';

class AppConstants {
  // App Information
  static const String appName = 'Rock - VPN & Proxy';
  static const String appVersion = '1.3.0';
  static const String buildNumber = '13';
  
  // Package Information
  static const String androidPackageName = 'com.theholylabs.rock';
  
  // RevenueCat Configuration
  static const String revenueCatApiKeyAndroid = 'goog_DMztEaCVhFMXcFodoKSmigHyUXu'; // Google Play key (corrected)
  static const String revenueCatApiKeyIOS = 'appl_mtyqcTcHlcOcNptWUraNaZCiJci'; // Apple App Store key
  
  // Platform-specific API key getter
  static String get revenueCatApiKey {
    return Platform.isIOS ? revenueCatApiKeyIOS : revenueCatApiKeyAndroid;
  }
  
  // AdMob Configuration
  static const String admobAppId = 'ca-app-pub-9876848164575099~9384550593';
  static const String admobBannerAdId = 'ca-app-pub-9876848164575099/9211599709'; // Production banner ad
  static const String admobInterstitialAdId = 'ca-app-pub-9876848164575099/8393342054'; // Production interstitial ad
  static const String admobRewardedAdId = 'ca-app-pub-9876848164575099/8393342054'; // Production rewarded ad (same as interstitial for now)
  
  // Firebase Configuration
  static const String firebaseProjectId = 'voice-85bc0';
  
  // VPN Configuration (from docker-compose.yml)
  static const String vpnUsername = 'dima';
  static const String vpnPassword = 'rabbit';
  static const String vpnSharedSecret = 'ipsec-vpn-key'; // PSK
  static const int vpnPort = 500; // IPsec port

  // VLESS (Xray) Configuration
  // UUID must match xray/config.json clients[0].id
  static const String vlessUuid = 'f6a7c0e2-5d0b-4df4-9b77-7f2f8a3f7c2d';
  static const int vlessPort = 10000; // exposed in docker-compose.yml
  static const String vlessPath = '/xray';
  static const bool vlessTls = false; // set true when proxied via nginx (wss)
  
  // API Configuration
  static const String apiBaseUrl = 'https://vpn.theholylabs.com/api';
  static const String proxyRegisterEndpoint = '$apiBaseUrl/proxy/register';
  static const String proxyPingEndpoint = '$apiBaseUrl/proxy/ping-ip';
  static const String clientsWithPingEndpoint = '$apiBaseUrl/proxy/clients-with-ping';
  
  // Support Configuration
  static const String telegramSupportUrl = 'https://t.me/theholylabs';
  static const String supportEmail = 'support@theholylabs.com';
  
  // App Store Configuration
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=$androidPackageName';
  static const String appStoreUrl = 'https://apps.apple.com/us/app/rock-vpn-proxy/id6743567773';
  
  // Subscription Configuration
  static const List<String> subscriptionProducts = [
    'monthly_subscription',
    'yearly_subscription',
  ];
  
  // Platform-specific subscription product IDs
  static const List<String> subscriptionProductsIOS = [
    'monthly_subscription',
    'yearly_subscription',
    'com.theholylabs.network.monthly',
    'com.theholylabs.network.yearly',
  ];
  
  static const List<String> subscriptionProductsAndroid = [
    'rock_short',
    'rock_long',
  ];
  
  static List<String> get platformSubscriptionProducts {
    return Platform.isIOS ? subscriptionProductsIOS : subscriptionProductsAndroid;
  }
  
  // Server Configuration
  static const int maxFreeServers = 2;
  static const int serverPingTimeout = 5000; // 5 seconds
  static const int serverRefreshInterval = 30000; // 30 seconds
  
  // UI Configuration
  static const int bannerAdHeight = 50;
  static const int animationDuration = 300;
  static const int connectionTimeout = 30000; // 30 seconds
  
  // Notification Configuration
  static const String notificationChannelId = 'vpn_notifications';
  static const String notificationChannelName = 'VPN Notifications';
  static const String notificationChannelDescription = 'Notifications for VPN connection status and updates';
  
  // Storage Keys
  static const String keySelectedServer = 'selected_server';
  static const String keyFavoriteServers = 'favorite_servers';
  static const String keyServerChangeCount = 'server_change_count';
  static const String keyIsSubscribed = 'is_subscribed';
  static const String keyFCMToken = 'fcm_token';
  static const String keyLastCountryCode = 'last_country_code';
  static const String keyLastCountryName = 'last_country_name';
  
  // Error Messages
  static const String errorVPNPermissionDenied = 'VPN permission is required to use this app';
  static const String errorServerUnavailable = 'Selected server is currently unavailable';
  static const String errorPremiumServerAccess = 'This server requires a premium subscription';
  static const String errorConnectionFailed = 'Failed to connect to VPN server';
  static const String errorNetworkUnavailable = 'Network connection is not available';
  
  // Success Messages
  static const String successVPNConnected = 'VPN connected successfully';
  static const String successVPNDisconnected = 'VPN disconnected successfully';
  static const String successServerSelected = 'Server selected successfully';
  
  // URLs
  static const String privacyPolicyUrl = 'https://theholylabs.com/privacy';
  static const String termsOfServiceUrl = 'https://theholylabs.com/terms';
  static const String supportUrl = 'https://theholylabs.com/support';
}

import 'dart:async';
import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_core/firebase_core.dart';

class AdConfigService {
  static FirebaseRemoteConfig? _remoteConfig;
  
  // Static variables shared across all instances
  static bool _isInterstitialAdsEnabled = true;
  static bool _isRewardEnabled = true;
  static bool _isInitialized = false;
  static final List<Function(bool)> _onAdsEnabledChangedCallbacks = [];
  static StreamSubscription? _configUpdateSubscription;

  // VPN credentials from Remote Config (NO FALLBACKS - Remote Config required)
  static String _vpnUsername = '';
  static String _vpnPassword = '';
  static String _vpnSharedSecret = '';
  
  // RevenueCat API keys from Remote Config (NO FALLBACKS - Remote Config required)
  static String _revenueCatApiKeyAndroid = '';
  static String _revenueCatApiKeyIOS = '';
  
  // AdMob IDs from Remote Config (NO FALLBACKS - Remote Config required)
  static String _admobAppId = '';
  static String _admobBannerAdId = '';
  static String _admobInterstitialAdId = '';
  static String _admobRewardedAdId = '';

  /// Initialize ad configuration from Firebase Remote Config (call this once at app startup)
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ Ad config service already initialized, skipping...');
      return;
    }

    try {
      print('🔥 Initializing ad configuration from Firebase Remote Config...');
      
      // Check if Firebase is initialized
      try {
        final app = Firebase.app();
        print('✅ Firebase app instance found: ${app.name}');
      } catch (e) {
        print('❌ CRITICAL: Firebase app not initialized! Error: $e');
        print('⚠️ Make sure Firebase.initializeApp() was called in main()');
        _isInitialized = true; // Mark as initialized to prevent retry loops
        return;
      }
      
      // Get Remote Config instance
      _remoteConfig = FirebaseRemoteConfig.instance;
      
      // Set default values (used if Remote Config hasn't been fetched yet or on error)
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 1), // Fetch at most once per minute
      ));
      
      // Set defaults (NO REAL CREDENTIALS/KEYS - use empty strings, Remote Config is required)
      await _remoteConfig!.setDefaults({
        'interstitial_ads_enabled': true,
        'reward_ads_enabled': true,
        'vpn_username': '', // Empty - Remote Config must provide this
        'vpn_password': '', // Empty - Remote Config must provide this
        'vpn_shared_secret': '', // Empty - Remote Config must provide this
        'revenuecat_api_key_android': '', // Empty - Remote Config must provide this
        'revenuecat_api_key_ios': '', // Empty - Remote Config must provide this
        'admob_app_id': '', // Empty - Remote Config must provide this
        'admob_banner_ad_id': '', // Empty - Remote Config must provide this
        'admob_interstitial_ad_id': '', // Empty - Remote Config must provide this
        'admob_rewarded_ad_id': '', // Empty - Remote Config must provide this
      });
      
      // Fetch and activate Remote Config values
      try {
        print('📥 Fetching Remote Config values...');
        bool updated = await _remoteConfig!.fetchAndActivate();
        
        if (updated) {
          print('✅ Remote Config values fetched and activated');
        } else {
          print('ℹ️ Using cached Remote Config values');
        }
      } catch (e) {
        print('⚠️ Error fetching Remote Config, using defaults: $e');
      }
      
      // Load initial values
      _isInterstitialAdsEnabled = _remoteConfig!.getBool('interstitial_ads_enabled');
      _isRewardEnabled = _remoteConfig!.getBool('reward_ads_enabled');
      
      // Load VPN credentials from Remote Config (NO FALLBACKS - Remote Config is required)
      _vpnUsername = _remoteConfig!.getString('vpn_username');
      _vpnPassword = _remoteConfig!.getString('vpn_password');
      _vpnSharedSecret = _remoteConfig!.getString('vpn_shared_secret');
      
      // Validate that Remote Config provided credentials (fail if empty)
      if (_vpnUsername.isEmpty) {
        print('❌ CRITICAL: VPN username not found in Remote Config');
        print('💡 Set "vpn_username" parameter in Firebase Remote Config');
        throw Exception('VPN credentials not configured: vpn_username missing from Remote Config');
      }
      if (_vpnPassword.isEmpty) {
        print('❌ CRITICAL: VPN password not found in Remote Config');
        print('💡 Set "vpn_password" parameter in Firebase Remote Config');
        throw Exception('VPN credentials not configured: vpn_password missing from Remote Config');
      }
      if (_vpnSharedSecret.isEmpty) {
        print('❌ CRITICAL: VPN shared secret not found in Remote Config');
        print('💡 Set "vpn_shared_secret" parameter in Firebase Remote Config');
        throw Exception('VPN credentials not configured: vpn_shared_secret missing from Remote Config');
      }
      
      // Load RevenueCat API keys from Remote Config (NO FALLBACKS - Remote Config is required)
      _revenueCatApiKeyAndroid = _remoteConfig!.getString('revenuecat_api_key_android');
      _revenueCatApiKeyIOS = _remoteConfig!.getString('revenuecat_api_key_ios');
      
      // Validate that Remote Config provided RevenueCat keys (fail if empty)
      if (_revenueCatApiKeyAndroid.isEmpty) {
        print('❌ CRITICAL: RevenueCat Android API key not found in Remote Config');
        print('💡 Set "revenuecat_api_key_android" parameter in Firebase Remote Config');
        throw Exception('RevenueCat not configured: revenuecat_api_key_android missing from Remote Config');
      }
      if (_revenueCatApiKeyIOS.isEmpty) {
        print('❌ CRITICAL: RevenueCat iOS API key not found in Remote Config');
        print('💡 Set "revenuecat_api_key_ios" parameter in Firebase Remote Config');
        throw Exception('RevenueCat not configured: revenuecat_api_key_ios missing from Remote Config');
      }
      
      // Load AdMob IDs from Remote Config (NO FALLBACKS - Remote Config is required)
      _admobAppId = _remoteConfig!.getString('admob_app_id');
      _admobBannerAdId = _remoteConfig!.getString('admob_banner_ad_id');
      _admobInterstitialAdId = _remoteConfig!.getString('admob_interstitial_ad_id');
      _admobRewardedAdId = _remoteConfig!.getString('admob_rewarded_ad_id');
      
      // Validate that Remote Config provided AdMob IDs (fail if empty)
      if (_admobAppId.isEmpty) {
        print('❌ CRITICAL: AdMob App ID not found in Remote Config');
        print('💡 Set "admob_app_id" parameter in Firebase Remote Config');
        throw Exception('AdMob not configured: admob_app_id missing from Remote Config');
      }
      if (_admobBannerAdId.isEmpty) {
        print('❌ CRITICAL: AdMob Banner Ad ID not found in Remote Config');
        print('💡 Set "admob_banner_ad_id" parameter in Firebase Remote Config');
        throw Exception('AdMob not configured: admob_banner_ad_id missing from Remote Config');
      }
      if (_admobInterstitialAdId.isEmpty) {
        print('❌ CRITICAL: AdMob Interstitial Ad ID not found in Remote Config');
        print('💡 Set "admob_interstitial_ad_id" parameter in Firebase Remote Config');
        throw Exception('AdMob not configured: admob_interstitial_ad_id missing from Remote Config');
      }
      if (_admobRewardedAdId.isEmpty) {
        print('❌ CRITICAL: AdMob Rewarded Ad ID not found in Remote Config');
        print('💡 Set "admob_rewarded_ad_id" parameter in Firebase Remote Config');
        throw Exception('AdMob not configured: admob_rewarded_ad_id missing from Remote Config');
      }
      
      print('✅ Initial ad config loaded from Remote Config:');
            print('   - Interstitial ads enabled: $_isInterstitialAdsEnabled');
            print('   - Reward ads enabled: $_isRewardEnabled');
      print('✅ VPN credentials loaded from Remote Config:');
      print('   - Username: ${_vpnUsername.isNotEmpty ? "✓" : "✗"}');
      print('   - Password: ${_vpnPassword.isNotEmpty ? "✓" : "✗"}');
      print('   - Shared Secret: ${_vpnSharedSecret.isNotEmpty ? "✓" : "✗"}');
      print('✅ RevenueCat API keys loaded from Remote Config:');
      print('   - Android: ${_revenueCatApiKeyAndroid.isNotEmpty ? "✓" : "✗"}');
      print('   - iOS: ${_revenueCatApiKeyIOS.isNotEmpty ? "✓" : "✗"}');
      print('✅ AdMob IDs loaded from Remote Config:');
      print('   - App ID: ${_admobAppId.isNotEmpty ? "✓" : "✗"}');
      print('   - Banner: ${_admobBannerAdId.isNotEmpty ? "✓" : "✗"}');
      print('   - Interstitial: ${_admobInterstitialAdId.isNotEmpty ? "✓" : "✗"}');
      print('   - Rewarded: ${_admobRewardedAdId.isNotEmpty ? "✓" : "✗"}');
      
      // Listen to Remote Config updates
      _configUpdateSubscription = _remoteConfig!.onConfigUpdated.listen((event) async {
        print('🔄 Remote Config updated, fetching new values...');
        await _remoteConfig!.activate();
        
        // Update values
        _isInterstitialAdsEnabled = _remoteConfig!.getBool('interstitial_ads_enabled');
        _isRewardEnabled = _remoteConfig!.getBool('reward_ads_enabled');
        
        // Update VPN credentials from Remote Config (only if not empty)
        final newUsername = _remoteConfig!.getString('vpn_username');
        final newPassword = _remoteConfig!.getString('vpn_password');
        final newSharedSecret = _remoteConfig!.getString('vpn_shared_secret');
        
        // Only update if Remote Config provided values (don't overwrite with empty)
        if (newUsername.isNotEmpty) {
          _vpnUsername = newUsername;
          print('✅ VPN username updated from Remote Config');
        }
        if (newPassword.isNotEmpty) {
          _vpnPassword = newPassword;
          print('✅ VPN password updated from Remote Config');
        }
        if (newSharedSecret.isNotEmpty) {
          _vpnSharedSecret = newSharedSecret;
          print('✅ VPN shared secret updated from Remote Config');
        }
        
        // Update RevenueCat API keys from Remote Config (only if not empty)
        final newRevenueCatAndroid = _remoteConfig!.getString('revenuecat_api_key_android');
        final newRevenueCatIOS = _remoteConfig!.getString('revenuecat_api_key_ios');
        
        if (newRevenueCatAndroid.isNotEmpty) {
          _revenueCatApiKeyAndroid = newRevenueCatAndroid;
          print('✅ RevenueCat Android API key updated from Remote Config');
        }
        if (newRevenueCatIOS.isNotEmpty) {
          _revenueCatApiKeyIOS = newRevenueCatIOS;
          print('✅ RevenueCat iOS API key updated from Remote Config');
        }
        
        // Update AdMob IDs from Remote Config (only if not empty)
        final newAdMobAppId = _remoteConfig!.getString('admob_app_id');
        final newAdMobBanner = _remoteConfig!.getString('admob_banner_ad_id');
        final newAdMobInterstitial = _remoteConfig!.getString('admob_interstitial_ad_id');
        final newAdMobRewarded = _remoteConfig!.getString('admob_rewarded_ad_id');
        
        if (newAdMobAppId.isNotEmpty) {
          _admobAppId = newAdMobAppId;
          print('✅ AdMob App ID updated from Remote Config');
        }
        if (newAdMobBanner.isNotEmpty) {
          _admobBannerAdId = newAdMobBanner;
          print('✅ AdMob Banner Ad ID updated from Remote Config');
        }
        if (newAdMobInterstitial.isNotEmpty) {
          _admobInterstitialAdId = newAdMobInterstitial;
          print('✅ AdMob Interstitial Ad ID updated from Remote Config');
        }
        if (newAdMobRewarded.isNotEmpty) {
          _admobRewardedAdId = newAdMobRewarded;
          print('✅ AdMob Rewarded Ad ID updated from Remote Config');
          }
        
        print('✅ Ad config updated from Remote Config:');
        print('   - Interstitial ads enabled: $_isInterstitialAdsEnabled');
        print('   - Reward ads enabled: $_isRewardEnabled');
        print('✅ VPN credentials updated from Remote Config');
        print('✅ RevenueCat API keys updated from Remote Config');
        print('✅ AdMob IDs updated from Remote Config');
        
        // Notify all registered callbacks
        for (var callback in _onAdsEnabledChangedCallbacks) {
          callback(_isInterstitialAdsEnabled || _isRewardEnabled);
        }
      });
      
      // Set up periodic fetch (fetch every hour in background)
      _setupPeriodicFetch();
      
      _isInitialized = true;
      print('✅ Ad config service initialized with Remote Config');
    } catch (e, stackTrace) {
      print('❌ Error initializing ad config service: $e');
      print('Stack trace: $stackTrace');
          // Use default values on error
          _isInterstitialAdsEnabled = true;
          _isRewardEnabled = true;
      _isInitialized = true; // Mark as initialized even on error
    }
  }

  /// Set up periodic fetch for Remote Config updates
  static void _setupPeriodicFetch() {
    Timer.periodic(const Duration(hours: 1), (timer) async {
      if (!_isInitialized || _remoteConfig == null) {
        timer.cancel();
        return;
      }
      
      try {
        print('🔄 Periodically fetching Remote Config updates...');
        bool updated = await _remoteConfig!.fetchAndActivate();
        
        if (updated) {
          _isInterstitialAdsEnabled = _remoteConfig!.getBool('interstitial_ads_enabled');
          _isRewardEnabled = _remoteConfig!.getBool('reward_ads_enabled');
          
          // Update VPN credentials from Remote Config (only if not empty)
          final newUsername = _remoteConfig!.getString('vpn_username');
          final newPassword = _remoteConfig!.getString('vpn_password');
          final newSharedSecret = _remoteConfig!.getString('vpn_shared_secret');
          
          // Only update if Remote Config provided values (don't overwrite with empty)
          if (newUsername.isNotEmpty) {
            _vpnUsername = newUsername;
            print('✅ VPN username updated from Remote Config');
          }
          if (newPassword.isNotEmpty) {
            _vpnPassword = newPassword;
            print('✅ VPN password updated from Remote Config');
          }
          if (newSharedSecret.isNotEmpty) {
            _vpnSharedSecret = newSharedSecret;
            print('✅ VPN shared secret updated from Remote Config');
          }
          
          // Update RevenueCat API keys from Remote Config (only if not empty)
          final newRevenueCatAndroid = _remoteConfig!.getString('revenuecat_api_key_android');
          final newRevenueCatIOS = _remoteConfig!.getString('revenuecat_api_key_ios');
          
          if (newRevenueCatAndroid.isNotEmpty) {
            _revenueCatApiKeyAndroid = newRevenueCatAndroid;
            print('✅ RevenueCat Android API key updated from Remote Config');
          }
          if (newRevenueCatIOS.isNotEmpty) {
            _revenueCatApiKeyIOS = newRevenueCatIOS;
            print('✅ RevenueCat iOS API key updated from Remote Config');
          }
          
          // Update AdMob IDs from Remote Config (only if not empty)
          final newAdMobAppId = _remoteConfig!.getString('admob_app_id');
          final newAdMobBanner = _remoteConfig!.getString('admob_banner_ad_id');
          final newAdMobInterstitial = _remoteConfig!.getString('admob_interstitial_ad_id');
          final newAdMobRewarded = _remoteConfig!.getString('admob_rewarded_ad_id');
          
          if (newAdMobAppId.isNotEmpty) {
            _admobAppId = newAdMobAppId;
            print('✅ AdMob App ID updated from Remote Config');
          }
          if (newAdMobBanner.isNotEmpty) {
            _admobBannerAdId = newAdMobBanner;
            print('✅ AdMob Banner Ad ID updated from Remote Config');
          }
          if (newAdMobInterstitial.isNotEmpty) {
            _admobInterstitialAdId = newAdMobInterstitial;
            print('✅ AdMob Interstitial Ad ID updated from Remote Config');
          }
          if (newAdMobRewarded.isNotEmpty) {
            _admobRewardedAdId = newAdMobRewarded;
            print('✅ AdMob Rewarded Ad ID updated from Remote Config');
          }
          
          print('✅ Remote Config updated:');
          print('   - Interstitial ads enabled: $_isInterstitialAdsEnabled');
          print('   - Reward ads enabled: $_isRewardEnabled');
          print('✅ VPN credentials updated from Remote Config');
          print('✅ RevenueCat API keys updated from Remote Config');
          print('✅ AdMob IDs updated from Remote Config');
          
          // Notify all registered callbacks
          for (var callback in _onAdsEnabledChangedCallbacks) {
            callback(_isInterstitialAdsEnabled || _isRewardEnabled);
          }
        }
      } catch (e) {
        print('⚠️ Error during periodic Remote Config fetch: $e');
      }
    });
  }

  /// Manually fetch Remote Config updates
  static Future<void> fetchAndActivate() async {
    if (_remoteConfig == null) {
      print('⚠️ Remote Config not initialized');
      return;
    }
    
    try {
      bool updated = await _remoteConfig!.fetchAndActivate();
      
      if (updated) {
        _isInterstitialAdsEnabled = _remoteConfig!.getBool('interstitial_ads_enabled');
        _isRewardEnabled = _remoteConfig!.getBool('reward_ads_enabled');
        
        // Update VPN credentials from Remote Config (only if not empty)
        final newUsername = _remoteConfig!.getString('vpn_username');
        final newPassword = _remoteConfig!.getString('vpn_password');
        final newSharedSecret = _remoteConfig!.getString('vpn_shared_secret');
        
        // Only update if Remote Config provided values (don't overwrite with empty)
        if (newUsername.isNotEmpty) {
          _vpnUsername = newUsername;
          print('✅ VPN username updated from Remote Config');
      }
        if (newPassword.isNotEmpty) {
          _vpnPassword = newPassword;
          print('✅ VPN password updated from Remote Config');
        }
        if (newSharedSecret.isNotEmpty) {
          _vpnSharedSecret = newSharedSecret;
          print('✅ VPN shared secret updated from Remote Config');
        }
        
        // Update RevenueCat API keys from Remote Config (only if not empty)
        final newRevenueCatAndroid = _remoteConfig!.getString('revenuecat_api_key_android');
        final newRevenueCatIOS = _remoteConfig!.getString('revenuecat_api_key_ios');
        
        if (newRevenueCatAndroid.isNotEmpty) {
          _revenueCatApiKeyAndroid = newRevenueCatAndroid;
          print('✅ RevenueCat Android API key updated from Remote Config');
        }
        if (newRevenueCatIOS.isNotEmpty) {
          _revenueCatApiKeyIOS = newRevenueCatIOS;
          print('✅ RevenueCat iOS API key updated from Remote Config');
        }
        
        // Update AdMob IDs from Remote Config (only if not empty)
        final newAdMobAppId = _remoteConfig!.getString('admob_app_id');
        final newAdMobBanner = _remoteConfig!.getString('admob_banner_ad_id');
        final newAdMobInterstitial = _remoteConfig!.getString('admob_interstitial_ad_id');
        final newAdMobRewarded = _remoteConfig!.getString('admob_rewarded_ad_id');
        
        if (newAdMobAppId.isNotEmpty) {
          _admobAppId = newAdMobAppId;
          print('✅ AdMob App ID updated from Remote Config');
        }
        if (newAdMobBanner.isNotEmpty) {
          _admobBannerAdId = newAdMobBanner;
          print('✅ AdMob Banner Ad ID updated from Remote Config');
        }
        if (newAdMobInterstitial.isNotEmpty) {
          _admobInterstitialAdId = newAdMobInterstitial;
          print('✅ AdMob Interstitial Ad ID updated from Remote Config');
        }
        if (newAdMobRewarded.isNotEmpty) {
          _admobRewardedAdId = newAdMobRewarded;
          print('✅ AdMob Rewarded Ad ID updated from Remote Config');
        }
        
        print('✅ Remote Config manually updated');
        
        // Notify all registered callbacks
        for (var callback in _onAdsEnabledChangedCallbacks) {
          callback(_isInterstitialAdsEnabled || _isRewardEnabled);
        }
      }
    } catch (e) {
      print('❌ Error manually fetching Remote Config: $e');
    }
  }

  /// Register a callback for ad config changes
  void set onAdsEnabledChanged(Function(bool)? callback) {
    // Note: Setting to null doesn't remove callbacks, use removeCallback() instead
    if (callback != null && !_onAdsEnabledChangedCallbacks.contains(callback)) {
      _onAdsEnabledChangedCallbacks.add(callback);
    }
  }

  /// Remove a callback (call this when disposing)
  void removeCallback(Function(bool) callback) {
    _onAdsEnabledChangedCallbacks.remove(callback);
  }

  /// Check if interstitial ads should be shown
  bool shouldShowInterstitialAds({required bool isSubscribed}) {
    // Premium users don't see ads
    if (isSubscribed) {
      return false;
    }
    
    // Check Remote Config value (uses static variable, so all instances see same value)
    return _isInterstitialAdsEnabled;
  }

  /// Check if banner ads should be shown
  bool shouldShowBannerAds({required bool isSubscribed}) {
    // Premium users don't see ads
    if (isSubscribed) {
      return false;
    }
    
    // Check Remote Config (banner ads use same config as interstitial for now)
    return _isInterstitialAdsEnabled;
  }

  /// Check if reward ads are enabled
  bool get isRewardEnabled => _isRewardEnabled;

  /// Get current configuration
  Map<String, dynamic> getCurrentConfig() {
    return {
      'interstitial_ads_enabled': _isInterstitialAdsEnabled,
      'reward_ads_enabled': _isRewardEnabled,
      'vpn_username': _vpnUsername,
      'vpn_password': _vpnPassword.isNotEmpty ? '***' : '', // Don't expose password in logs
      'vpn_shared_secret': _vpnSharedSecret.isNotEmpty ? '***' : '', // Don't expose secret in logs
    };
  }

  /// Get VPN username from Remote Config (with fallback to AppConstants)
  static String get vpnUsername => _vpnUsername;

  /// Get VPN password from Remote Config (with fallback to AppConstants)
  static String get vpnPassword => _vpnPassword;

  /// Get VPN shared secret from Remote Config (with fallback to AppConstants)
  static String get vpnSharedSecret => _vpnSharedSecret;

  /// Get RevenueCat API key for current platform from Remote Config
  static String get revenueCatApiKey {
    return Platform.isIOS ? _revenueCatApiKeyIOS : _revenueCatApiKeyAndroid;
  }

  /// Get AdMob App ID from Remote Config
  static String get admobAppId => _admobAppId;

  /// Get AdMob Banner Ad ID from Remote Config
  static String get admobBannerAdId => _admobBannerAdId;

  /// Get AdMob Interstitial Ad ID from Remote Config
  static String get admobInterstitialAdId => _admobInterstitialAdId;

  /// Get AdMob Rewarded Ad ID from Remote Config
  static String get admobRewardedAdId => _admobRewardedAdId;

  /// Dispose the service (call this when app shuts down)
  static void dispose() {
    _configUpdateSubscription?.cancel();
    _configUpdateSubscription = null;
    _onAdsEnabledChangedCallbacks.clear();
    _isInitialized = false;
  }
}

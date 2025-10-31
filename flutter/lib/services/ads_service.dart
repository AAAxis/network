import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config_service.dart';

class AdsService {
  static InterstitialAd? _interstitialAd;
  static RewardedAd? _rewardedAd;
  static bool _isInterstitialAdLoaded = false;
  static bool _isRewardedAdLoaded = false;
  static bool _isAdMobInitialized = false;

  /// Initialize ads service (without initializing AdMob - that's done separately)
  static Future<void> initialize() async {
    if (!_isAdMobInitialized) {
      print('⚠️ AdMob not initialized yet - ads will be loaded after onboarding');
      return;
    }
    
    print('✅ AdMob already initialized, loading ads');
    
    // Firebase ad configuration is already initialized in main()
    print('✅ Firebase ad config already initialized');
    
    // Load initial ads
    loadInterstitialAd();
    loadRewardedAd();
  }

  /// Initialize AdMob (called from onboarding)
  static Future<void> initializeAdMob() async {
    if (_isAdMobInitialized) {
      print('⚠️ AdMob already initialized');
      return;
    }
    
    await MobileAds.instance.initialize();
    _isAdMobInitialized = true;
    print('✅ AdMob initialized');
    
    // Firebase ad configuration is already initialized in main()
    print('✅ Firebase ad config already initialized');
    
    // Load initial ads
    loadInterstitialAd();
    loadRewardedAd();
  }

  /// Load interstitial ad (like iOS app shows on VPN connect)
  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdConfigService.admobInterstitialAdId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          print('✅ Interstitial ad loaded successfully');
          
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('❌ Failed to load interstitial ad: $error');
          _interstitialAd = null;
          _isInterstitialAdLoaded = false;
          
          // Retry loading after delay
          Future.delayed(const Duration(seconds: 30), () {
            loadInterstitialAd();
          });
        },
      ),
    );
  }

  /// Load rewarded ad
  static void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdConfigService.admobRewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          print('✅ Rewarded ad loaded successfully');
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('❌ Failed to load rewarded ad: $error');
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
          
          // Retry loading after delay
          Future.delayed(const Duration(seconds: 30), () {
            loadRewardedAd();
          });
        },
      ),
    );
  }

  /// Show interstitial ad on VPN connection (matching iOS behavior)
  static void showInterstitialAdOnVPNConnect({
    required bool isSubscribed,
    bool? isAdsEnabled, // Optional - will use Firebase if not provided
  }) {
    final adConfig = AdConfigService();
    
    print('🎯 showInterstitialAdOnVPNConnect called - isSubscribed: $isSubscribed');
    print('🎯 Ad status - loaded: $_isInterstitialAdLoaded, ad: ${_interstitialAd != null}');
    print('🎯 Firebase config: ${adConfig.getCurrentConfig()}');
    
    // Use Firebase ad configuration (like iOS)
    if (!adConfig.shouldShowInterstitialAds(isSubscribed: isSubscribed)) {
      return; // Firebase config or subscription status prevents ads
    }

    // Show ad if loaded
    if (_isInterstitialAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (InterstitialAd ad) {
          print('📺 ✅ Interstitial ad is now showing on screen!');
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          print('📺 Interstitial ad dismissed by user');
          ad.dispose();
          _isInterstitialAdLoaded = false;
          
          // Load next ad
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          print('❌ Failed to show interstitial ad: $error');
          ad.dispose();
          _isInterstitialAdLoaded = false;
          loadInterstitialAd();
        },
      );

      print('🎯 Attempting to show interstitial ad now...');
      try {
        _interstitialAd!.show();
        print('📺 ✅ Ad.show() called successfully');
      } catch (e) {
        print('❌ Exception calling ad.show(): $e');
      }
    } else {
      print('⚠️ Interstitial ad not ready, loading...');
      loadInterstitialAd();
    }
  }

  /// Show rewarded ad
  static void showRewardedAd({
    required Function() onUserEarnedReward,
    required Function() onAdDismissed,
  }) {
    print('🎯 showRewardedAd called - ad loaded: $_isRewardedAdLoaded, ad exists: ${_rewardedAd != null}');
    
    if (_isRewardedAdLoaded && _rewardedAd != null) {
      print('📺 Using pre-loaded rewarded ad');
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (RewardedAd ad) {
          print('📺 Showing rewarded ad');
        },
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          print('📺 Rewarded ad dismissed');
          ad.dispose();
          _isRewardedAdLoaded = false;
          onAdDismissed();
          
          // Load next ad
          loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          print('❌ Failed to show rewarded ad: $error');
          ad.dispose();
          _isRewardedAdLoaded = false;
          onAdDismissed();
          loadRewardedAd();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          print('🎁 User earned reward (pre-loaded ad): ${reward.amount} ${reward.type}');
          onUserEarnedReward();
        },
      );
    } else {
      print('⚠️ Rewarded ad not ready, loading and waiting...');
      
      // Load ad and wait for it to be ready
      _loadRewardedAdAndShow(
        onUserEarnedReward: onUserEarnedReward,
        onAdDismissed: onAdDismissed,
      );
    }
  }

  /// Load rewarded ad and show it when ready
  static void _loadRewardedAdAndShow({
    required Function() onUserEarnedReward,
    required Function() onAdDismissed,
  }) {
    RewardedAd.load(
      adUnitId: AdConfigService.admobRewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('✅ Rewarded ad loaded, showing immediately...');
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (RewardedAd ad) {
              print('📺 Showing rewarded ad');
            },
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              print('📺 Rewarded ad dismissed');
              ad.dispose();
              onAdDismissed();
              
              // Update the main rewarded ad state
              _rewardedAd?.dispose();
              _rewardedAd = null;
              _isRewardedAdLoaded = false;
              loadRewardedAd(); // Load next ad for future use
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              print('❌ Failed to show rewarded ad: $error');
              ad.dispose();
              onAdDismissed();
              
              // Update the main rewarded ad state
              _rewardedAd?.dispose();
              _rewardedAd = null;
              _isRewardedAdLoaded = false;
              loadRewardedAd(); // Load next ad for future use
            },
          );

          ad.show(
            onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
              print('🎁 User earned reward (on-demand ad): ${reward.amount} ${reward.type}');
              onUserEarnedReward();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('❌ Failed to load rewarded ad for immediate show: $error');
          onAdDismissed(); // Only call dismissed if we truly can't load the ad
        },
      ),
    );
  }

  /// Check if interstitial ad is ready
  static bool get isInterstitialAdReady => _isInterstitialAdLoaded;

  /// Check if rewarded ad is ready
  static bool get isRewardedAdReady => _isRewardedAdLoaded;
}


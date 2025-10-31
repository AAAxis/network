import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_config_service.dart';

class BannerAdWidget extends StatefulWidget {
  final bool isSubscribed;
  
  const BannerAdWidget({
    super.key,
    this.isSubscribed = false, // Default to free user
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  late AdConfigService _adConfig;
  late Function(bool) _configChangeCallback;

  @override
  void initState() {
    super.initState();
    _adConfig = AdConfigService();
    
    // Set up listener for ad config changes
    _configChangeCallback = (bool enabled) {
      print('🔄 Banner ad config changed: enabled=$enabled');
      if (mounted) {
        _handleAdConfigChange();
      }
    };
    _adConfig.onAdsEnabledChanged = _configChangeCallback;
    
    // Don't load ad immediately - check Firebase config first
    _checkAndLoadAd();
  }

  void _checkAndLoadAd() {
    // Only load ad if it should be shown (matching iOS logic)
    if (_adConfig.shouldShowBannerAds(isSubscribed: widget.isSubscribed)) {
      _loadBannerAd();
    } else {
      print('ℹ️ Banner ad not loaded - disabled by Firebase config or user is subscribed');
    }
  }

  void _handleAdConfigChange() {
    if (_adConfig.shouldShowBannerAds(isSubscribed: widget.isSubscribed)) {
      // Config changed to enabled - load ad if not already loaded
      if (_bannerAd == null && !_isAdLoaded) {
        _loadBannerAd();
      }
    } else {
      // Config changed to disabled - dispose ad if loaded
      if (_bannerAd != null) {
        _bannerAd!.dispose();
        _bannerAd = null;
        _isAdLoaded = false;
        setState(() {});
        print('🚫 Banner ad disposed due to config change');
      }
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdConfigService.admobBannerAdId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
          print('✅ Banner ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Banner ad failed to load: $error');
          ad.dispose();
        },
        onAdOpened: (ad) => print('📱 Banner ad opened'),
        onAdClosed: (ad) => print('📱 Banner ad closed'),
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    // Clean up ad config listener
    _adConfig.removeCallback(_configChangeCallback);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if banner ads should be shown (matching iOS logic)
    if (!_adConfig.shouldShowBannerAds(isSubscribed: widget.isSubscribed)) {
      return const SizedBox.shrink(); // Hide banner if disabled or user is subscribed
    }
    
    return Container(
      height: 50,
      width: double.infinity,
      color: Colors.black,
      child: _isAdLoaded && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : Container(
              color: Colors.grey[800],
              child: const Center(
                child: Text(
                  'Ad Loading...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
    );
  }
}


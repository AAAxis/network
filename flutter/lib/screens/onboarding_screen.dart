import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:ui';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import '../services/ads_service.dart';
import '../services/fcm_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isLoading = false;

  Future<void> _onContinue() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request notification permissions first
      print('🔔 Requesting notification permissions...');
      await _requestNotificationPermissions();
      
      // Initialize Google Mobile Ads when user clicks Continue
      // This will trigger the "Discover networks" prompt
      print('📱 Initializing AdMob on user continue...');
      await AdsService.initializeAdMob();
      
      // Configure AdMob settings for iOS
      if (Platform.isIOS) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: [], // Add your test device IDs here if needed
            tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
            tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
          ),
        );
        print('📱 AdMob configured for iOS');
      }
      
      print('✅ AdMob and AdsService initialized successfully');

      // Mark onboarding as completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);

      if (!mounted) return;

      // Navigate to home screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      print('❌ Error during onboarding completion: $e');
      
      // Even if AdMob fails, continue to home screen
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Request notification permissions using FCM service
  Future<void> _requestNotificationPermissions() async {
    try {
      print('🔔 Requesting notification permissions via FCM...');
      final granted = await FCMService.requestPermissionsAndGetToken();
      print('🔔 Notification permissions granted: $granted');
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                
                // Your actual app logo
                Container(
                  width: 120,
                  height: 120,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/appstore.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('❌ Error loading app icon: $error');
                        return Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.vpn_lock,
                            size: 60,
                            color: Colors.green,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Title with green accent
                const Text(
                  'Rock VPN',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // Features list with your app's style
                _buildModernFeatureRow(
                  icon: Icons.security_outlined,
                  title: 'Bank-Level Security',
                  subtitle: 'AES-256 encryption',
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                _buildModernFeatureRow(
                  icon: Icons.flash_on_outlined,
                  title: 'Ultra-Fast Speed',
                  subtitle: 'Optimized protocols',
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                _buildModernFeatureRow(
                  icon: Icons.public_outlined,
                  title: 'Global Network',
                  subtitle: 'Servers worldwide',
                  color: Colors.green,
                ),
                
                const SizedBox(height: 50),
                
                // Green continue button matching your app style
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Privacy note
                Text(
                  'By continuing, you agree to our privacy policy',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


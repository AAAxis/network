import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/vpn_provider.dart';
import 'providers/server_provider.dart';
import 'providers/subscription_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/fcm_service.dart';
import 'services/ads_service.dart';
import 'services/ad_config_service.dart';
import 'services/billing_service.dart';
import 'utils/app_constants.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// Firebase Messaging Background Handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  print('🚀 Starting app - main() called');
  WidgetsFlutterBinding.ensureInitialized();
  print('✅ WidgetsFlutterBinding initialized');
  
  // Initialize Firebase with error handling
  print('🔥 Attempting to initialize Firebase...');
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
    
    // Verify Firebase is ready
    if (Firebase.apps.isEmpty) {
      print('❌ ERROR: Firebase apps list is empty after initialization!');
    } else {
      final app = Firebase.app();
      print('✅ Firebase app initialized: ${app.name}');
      print('✅ Firebase options available: ${app.options.projectId}');
    }
  } catch (e, stackTrace) {
    print('❌ CRITICAL ERROR: Failed to initialize Firebase: $e');
    print('Stack trace: $stackTrace');
    // Continue anyway - app might work without Firebase for some features
  }
  
  // Initialize Firebase ad configuration FIRST (before any ads are created)
  print('📊 Initializing Firebase ad config...');
  try {
    await AdConfigService.initialize();
    print('✅ Firebase ad config initialized early');
  } catch (e) {
    print('❌ ERROR: Failed to initialize Firebase ad config: $e');
  }
  
  // Initialize Firebase Cloud Messaging (notifications work immediately)
  print('📱 Setting up FCM...');
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FCMService.initialize();
  print('✅ FCM initialized');
  
  // DON'T initialize Google Mobile Ads here - will be done in onboarding
  // This prevents the "Discover networks" prompt on app start
  
  // Initialize Ads Service (won't initialize AdMob until onboarding)
  print('📢 Initializing Ads Service...');
  await AdsService.initialize();
  print('✅ Ads Service initialized');
  
  // Initialize RevenueCat FIRST (required before BillingService)
  print('💳 Initializing RevenueCat...');
  await Purchases.setLogLevel(LogLevel.debug);
  PurchasesConfiguration configuration = PurchasesConfiguration(AppConstants.revenueCatApiKey);
  await Purchases.configure(configuration);
  print('✅ RevenueCat initialized with API key: ${AppConstants.revenueCatApiKey}');
  
  // Initialize Google Play Billing (required for subscriptions)
  // Must be called AFTER RevenueCat is configured
  print('🛒 Initializing Billing Service...');
  await BillingService().initialize();
  print('✅ Billing Service initialized');
  
  // Request permissions (but not VPN as it doesn't exist in permission_handler)
  // VPN permission will be handled natively
  
  print('🎬 Running app...');
  runApp(const VPNApp());
  print('✅ App running');
}

class VPNApp extends StatelessWidget {
  const VPNApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VPNProvider()),
        ChangeNotifierProvider(create: (_) => ServerProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: MaterialApp(
        title: 'VPN',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: false, // Use Material 2 for compatibility
          primarySwatch: Colors.blue,
          primaryColor: Colors.black,
          scaffoldBackgroundColor: Colors.black,
          iconTheme: const IconThemeData(
            color: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white),
          ),
          colorScheme: const ColorScheme.dark(
            primary: Colors.green,
            secondary: Colors.red,
            surface: Colors.black,
            background: Colors.black,
          ),
        ),
        home: FutureBuilder<bool>(
          future: _checkIfOnboardingCompleted(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            final hasSeenOnboarding = snapshot.data ?? false;
            return hasSeenOnboarding ? const HomeScreen() : const OnboardingScreen();
          },
        ),
      ),
    );
  }

  Future<bool> _checkIfOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }
}




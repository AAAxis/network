import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/vpn_provider.dart';
import '../providers/server_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/vpn_server.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/vpn_connect_button.dart';
import '../widgets/server_selector.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/paywall_widget.dart';
import '../services/native_paywall_service.dart';
import '../utils/app_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _serverChangeCount = 0;

  @override
  void initState() {
    super.initState();
    // Use post frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Check if widget is still mounted before proceeding
    if (!mounted) return;
    
    // Initialize providers
    // Subscription provider initializes itself in constructor
    
    // Initialize server provider - load favorites first, then fetch servers
    final serverProvider = context.read<ServerProvider>();
    await serverProvider.loadFavorites();
    await serverProvider.fetchServersFromFirebase();
    
    if (!mounted) return;
    await context.read<VPNProvider>().initialize();
    
    // Sync selected server between providers
    if (!mounted) return;
    final vpnProvider = context.read<VPNProvider>();
    if (serverProvider.selectedServer != null) {
      vpnProvider.setSelectedServer(serverProvider.selectedServer!);
    }
    
    // Load server change count for review prompt
    await _loadServerChangeCount();
  }

  Future<void> _loadServerChangeCount() async {
    // TODO: Load from SharedPreferences
    _serverChangeCount = 0;
  }

  Future<void> _saveServerChangeCount() async {
    // TODO: Save to SharedPreferences
  }

  Future<void> _requestReviewIfAppropriate() async {
    _serverChangeCount++;
    await _saveServerChangeCount();
    
    if (_serverChangeCount == 1) {
      try {
        // TODO: Implement review prompt when in_app_review is available
        print('⭐ Review would be requested after $_serverChangeCount server changes');
      } catch (e) {
        print('❌ Error requesting review: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Rock VPN',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: const SettingsDrawer(),
      body: Consumer3<VPNProvider, ServerProvider, SubscriptionProvider>(
        builder: (context, vpnProvider, serverProvider, subscriptionProvider, child) {
          return Column(
            children: [
              // Banner Ad (only for non-premium users)
              if (!subscriptionProvider.isSubscribed)
                BannerAdWidget(isSubscribed: subscriptionProvider.isSubscribed),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      
                      const SizedBox(height: 12),
                      
                      const SizedBox(height: 24),

                      // Large Connect/Disconnect Button
                      VPNConnectButton(
                        isConnected: vpnProvider.isConnected,
                        isConnecting: vpnProvider.isConnecting,
                        onPressed: () => vpnProvider.toggleConnection(context),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Unified Server Selection Card
                      GestureDetector(
                        onTap: () {
                          // Prevent opening server selector when VPN is connected
                          if (vpnProvider.isConnected) {
                            print('⚠️ Cannot change server while VPN is connected');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please disconnect VPN before changing server'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          _showServerSelector(context, vpnProvider, serverProvider);
                        },
                        child: Opacity(
                          opacity: vpnProvider.isConnected ? 0.6 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: vpnProvider.isConnected ? Colors.green : Colors.grey[700]!,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Server info row
                              Row(
                                children: [
                                  // Color flag
                                  Text(
                                    serverProvider.selectedServer?.flag ?? '🏳️',
                                    style: const TextStyle(fontSize: 40),
                                  ),
                                  const SizedBox(width: 15),
                                  // Server details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          serverProvider.selectedServer?.name ?? 'Select Server',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          serverProvider.selectedServer?.city ?? 'Tap to choose location',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Premium badge
                                  if (serverProvider.selectedServer?.isPremium == true && !subscriptionProvider.isSubscribed)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[700],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'PREMIUM',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 10),
                                  // Arrow icon
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.grey[400],
                                    size: 16,
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 15),
                              
                              // Server status row
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: serverProvider.selectedServer?.statusColor ?? Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    serverProvider.selectedServer?.status == ServerStatus.available ? 'Available' : 
                                    serverProvider.selectedServer?.status == ServerStatus.highPing ? 'High Ping' : 'Offline',
                                    style: TextStyle(
                                      color: serverProvider.selectedServer?.statusColor ?? Colors.grey,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Load indicator
                                  if (serverProvider.selectedServer?.loadStatusText != null)
                                    Text(
                                      serverProvider.selectedServer!.loadStatusText!,
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              
                            ],
                          ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Status Message
                      if (vpnProvider.statusMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            vpnProvider.statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      
                      const SizedBox(height: 40),
                      
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showServerSelector(BuildContext context, VPNProvider vpnProvider, ServerProvider serverProvider) {
    // Only allow opening if VPN is not connected
    if (vpnProvider.isConnected) {
      return; // Already handled in onTap with snackbar message
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => ServerSelector(
        onServerSelected: (server) async {
          await serverProvider.setSelectedServer(server, context);
          await _requestReviewIfAppropriate();
          Navigator.pop(context);
        },
      ),
    );
  }


  void _showUpgradeDialog(BuildContext context) async {
    // Show RevenueCat native paywall (like iOS and meal_tracker)
    final result = await NativePaywallService.presentPaywall(
      context: context,
      source: 'premium_button',
      onPurchaseCompleted: () {
        print('🎉 Purchase completed from premium button');
      },
      onRestoreCompleted: () {
        print('✅ Purchases restored from premium button');
      },
      onDismiss: () {
        print('❌ Premium button paywall dismissed');
      },
    );
    
    if (result) {
      print('✅ Premium paywall completed successfully');
    } else {
      print('❌ Premium paywall was dismissed or failed');
    }
  }
  
}

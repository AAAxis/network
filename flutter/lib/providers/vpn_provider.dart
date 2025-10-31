import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vpn_server.dart';
import '../services/native_vpn_service.dart';
import '../services/flutter_v2ray_service.dart';
import '../services/ip_service.dart';
import '../services/ads_service.dart';
import '../services/ad_config_service.dart';
import '../services/reward_cooldown_service.dart';
import '../providers/subscription_provider.dart';
import '../utils/app_constants.dart';

class VPNProvider with ChangeNotifier {
  bool _isConnected = false;
  bool _isConnecting = false;
  String _statusMessage = 'VPN Disconnected';
  VPNServer? _selectedServer;
  String? _currentIP;
  String? _originalIP;
  Map<String, dynamic>? _currentLocation;
  DateTime? _connectionStartTime;

  // Protocol mode
  ProtocolMode _protocolMode = ProtocolMode.ipsec;

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get statusMessage => _statusMessage;
  VPNServer? get selectedServer => _selectedServer;
  String? get currentIP => _currentIP;
  String? get originalIP => _originalIP;
  Map<String, dynamic>? get currentLocation => _currentLocation;
  ProtocolMode get protocolMode => _protocolMode;

  void setProtocolMode(ProtocolMode mode) {
    _protocolMode = mode;
    notifyListeners();
  }

  // Initialize VPN
  Future<void> initialize() async {
    try {
      await NativeVPNService.initialize();
      await FlutterV2RayService.initialize();
      
      // Set up status change listener for IPSec VPN
      NativeVPNService.onVPNStatusChanged = (data) {
        // Only handle IPSec VPN status changes here
        if (_protocolMode == ProtocolMode.ipsec) {
          _handleVPNStatusChange(data);
        }
      };
      
      // Set up status change listener for V2Ray
      FlutterV2RayService.setOnStatusChanged((data) {
        // Only handle V2Ray status changes when in VLESS mode
        if (_protocolMode == ProtocolMode.vless) {
          _handleVPNStatusChange(data);
        }
      });
      
      // Get initial IP and location
      await _updateCurrentIPInfo();
      
      print('✅ VPN initialized successfully');
    } catch (e) {
      print('❌ VPN initialization failed: $e');
      _statusMessage = 'VPN initialization failed: $e';
      notifyListeners();
    }
  }
  
  // Handle VPN status changes from native
  void _handleVPNStatusChange(Map<dynamic, dynamic> data) {
    final status = data['status'] as String?;
    final countryName = data['countryName'] as String? ?? data['country_name'] as String?;
    
    print('📊 VPN Status update from native: $status (country: $countryName)');
    
    switch (status) {
      case 'connected':
        print('🎉 VPN Connected! Updating UI state...');
        _isConnected = true;
        _isConnecting = false;
        _statusMessage = 'Connected to ${countryName ?? "VPN"}';
        _connectionStartTime = DateTime.now();
        
        // Wait a bit for VPN to route traffic before checking IP
        Future.delayed(const Duration(seconds: 2), () {
          print('🔄 Waiting 2 seconds for VPN to route traffic, then checking IP...');
          _verifyVPNConnection();
        });
        
        // Show ad for non-subscribed users on successful connection (matching iOS behavior)
        _showAdOnVPNConnect();
        
        notifyListeners();
        print('✅ UI state updated: connected=$_isConnected, connecting=$_isConnecting');
        break;
      case 'connecting':
        if (!_isConnecting) { // Only update if not already connecting
          _isConnected = false;
          _isConnecting = true;
          _statusMessage = 'Connecting...';
          notifyListeners();
        }
        break;
      case 'disconnected':
        if (_isConnected || _isConnecting) { // Only update if currently connected/connecting
          _isConnected = false;
          _isConnecting = false;
          _statusMessage = 'VPN Disconnected';
          _connectionStartTime = null;
          // Update IP info after disconnection
          _updateCurrentIPInfo();
          notifyListeners();
        }
        break;
      case 'failed':
      case 'error':
        _isConnected = false;
        _isConnecting = false;
        _statusMessage = 'Connection failed';
        notifyListeners();
        break;
    }
  }

  // Set selected server
  void setSelectedServer(VPNServer server) {
    _selectedServer = server;
    notifyListeners();
  }

  // Connect to VPN
  Future<void> connect([BuildContext? context]) async {
    if (_selectedServer == null) {
      _statusMessage = 'Please select a server first';
      notifyListeners();
      return;
    }

    if (_isConnecting || _isConnected) return;

    // Get real subscription status from SubscriptionProvider
    bool isSubscribed = false;
    if (context != null) {
      try {
        final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
        isSubscribed = subscriptionProvider.isSubscribed;
        print('🔍 Real subscription status: $isSubscribed');
      } catch (e) {
        print('⚠️ Could not get subscription status: $e, defaulting to free user');
        isSubscribed = false;
      }
    } else {
      print('⚠️ No context provided, defaulting to free user');
      isSubscribed = false;
    }
    
    // For free users, check reward cooldown and show rewarded ad if needed
    if (!isSubscribed) {
      final adConfig = AdConfigService();
      
      // Check if rewarded ads are enabled in Firebase config
      if (adConfig.isRewardEnabled) {
        // Check if user is in reward cooldown period (has free VPN access)
        print('🔍 Checking reward cooldown status...');
        final isInCooldown = await RewardCooldownService.isInCooldownPeriod();
        print('🔍 Cooldown status: $isInCooldown');
        
        if (isInCooldown) {
          // User has free VPN access - connect directly
          print('✅ User in reward cooldown - connecting directly without ad');
          await _performVPNConnection();
          return;
        } else {
          // User needs to watch rewarded ad
          print('🎯 Free user - showing rewarded ad before VPN connection');
          _showRewardedAdBeforeVPN();
          return; // Exit here - VPN connection will continue after ad reward
        }
      }
    } else {
      print('✅ Premium user - connecting directly without ads');
    }
    
    // Premium users or when ads are disabled - connect directly
    if (_protocolMode == ProtocolMode.vless) {
      await _performVlessConnection();
    } else {
      await _performVPNConnection();
    }
  }

  // Show rewarded ad before VPN connection (for free users)
  void _showRewardedAdBeforeVPN() {
    // Show loading state while ad loads
    _statusMessage = 'Loading ad...';
    notifyListeners();
    
    bool rewardAlreadyEarned = false; // Prevent double reward calls
    
    AdsService.showRewardedAd(
      onUserEarnedReward: () async {
        if (rewardAlreadyEarned) {
          print('⚠️ Reward already earned, ignoring duplicate call');
          return;
        }
        rewardAlreadyEarned = true;
        
        print('✅ User earned reward - allowing VPN connection');
        
        // Save reward timestamp for 1-hour cooldown
        await RewardCooldownService.saveRewardTimestamp();
        
        // User watched the ad and earned reward - now allow VPN connection
        _performVPNConnection();
      },
      onAdDismissed: () async {
        if (rewardAlreadyEarned) {
          print('⚠️ Ad dismissed but reward already earned, ignoring');
          return;
        }
        
        print('❌ User dismissed rewarded ad - VPN connection cancelled');
        
        // Show how long until next free access
        final remainingTime = await RewardCooldownService.getRemainingCooldownText();
        if (remainingTime.isNotEmpty) {
          _statusMessage = 'Free access in $remainingTime';
        } else {
          _statusMessage = 'Watch ad to connect to VPN';
        }
        notifyListeners();
      },
    );
  }

  // Perform the actual VPN connection (called after rewarded ad or for premium users)
  Future<void> _performVPNConnection() async {
    try {
      _isConnecting = true;
      _statusMessage = 'Connecting to ${_selectedServer!.name}...';
      notifyListeners();

      // Start VPN connection - permission will be handled natively
      // If permission is needed, Android will handle it and retry automatically
      bool success = false;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (!success && retryCount < maxRetries) {
        try {
          print('🔄 VPN connection attempt ${retryCount + 1}/$maxRetries');
          
          // Validate server address from Remote Config before connecting
          final serverAddress = _selectedServer!.serverAddress;
          if (serverAddress.contains('example.com') || 
              serverAddress.contains('example.org') ||
              serverAddress.isEmpty ||
              serverAddress == 'vpn.example.com') {
            print('❌ ERROR: Server address is a placeholder: $serverAddress');
            print('❌ VPN cannot connect to placeholder addresses!');
            print('💡 Update the "vpn_servers" parameter in Firebase Remote Config');
            print('💡 Replace placeholder addresses like "us.example.com" with REAL VPN server addresses');
            print('💡 VPN credentials (username/password) come from Remote Config');
            throw Exception('Invalid server address from Remote Config: $serverAddress (must be a real VPN server IP/domain)');
          }
          
          print('🌐 Connecting to VPN server from Remote Config: $serverAddress');
          
          // Get VPN credentials from Remote Config (NO FALLBACKS - Remote Config required)
          final username = AdConfigService.vpnUsername;
          final password = AdConfigService.vpnPassword;
          final sharedSecret = AdConfigService.vpnSharedSecret;
          
          // Validate credentials are loaded from Remote Config
          if (username.isEmpty || password.isEmpty || sharedSecret.isEmpty) {
            print('❌ CRITICAL: VPN credentials not loaded from Remote Config');
            print('💡 VPN connection cannot proceed without Remote Config credentials');
            throw Exception('VPN credentials not configured: Please set vpn_username, vpn_password, and vpn_shared_secret in Firebase Remote Config');
          }
          
          success = await NativeVPNService.connect(
            serverAddress: serverAddress,
            username: username,
            password: password,
            sharedSecret: sharedSecret,
            countryCode: _selectedServer!.countryCode,
            countryName: _selectedServer!.name,
          );
          
          if (success) {
            print('✅ VPN connection successful on attempt ${retryCount + 1}');
            break;
          } else {
            retryCount++;
            // On first failure, it might be due to permission request
            // Give more time for user to grant permission
            if (retryCount == 1) {
              print('⚠️ VPN connection failed - might be requesting permission, waiting longer...');
              await Future.delayed(const Duration(seconds: 5));
            } else if (retryCount < maxRetries) {
              print('⚠️ VPN connection failed, retrying in 2 seconds... (${retryCount}/$maxRetries)');
              await Future.delayed(const Duration(seconds: 2));
            }
          }
        } catch (e) {
          retryCount++;
          if (retryCount < maxRetries) {
            print('❌ VPN connection error: $e, retrying in 2 seconds... (${retryCount}/$maxRetries)');
            await Future.delayed(const Duration(seconds: 2));
          } else {
            rethrow; // Re-throw on final attempt
          }
        }
      }
      
      if (success) {
        _connectionStartTime = DateTime.now();
        
        // Add timeout to stop spinning animation if no status update comes
        Timer(Duration(seconds: 8), () {
          if (_isConnecting && !_isConnected) {
            print('⏰ Connection timeout - assuming connected based on navbar VPN');
            _isConnected = true;
            _isConnecting = false;
            _statusMessage = 'Connected to ${_selectedServer!.name}';
            _connectionStartTime = DateTime.now();
            
            // Show interstitial ad after connection (for premium users or when rewarded ads are disabled)
            print('🎯 Timeout triggered - showing interstitial ad after connection');
            _showAdOnVPNConnect();
            
            _updateCurrentIPInfo();
            notifyListeners();
          }
        });
      } else {
        throw Exception('Failed to start VPN connection after $maxRetries attempts');
      }

    } catch (e) {
      _isConnecting = false;
      _statusMessage = 'Connection failed: $e';
      notifyListeners();
      print('❌ VPN connection failed: $e');
    }
  }

  // Perform VLESS connection via Flutter V2Ray (cross-platform)
  Future<void> _performVlessConnection() async {
    try {
      _isConnecting = true;
      _statusMessage = 'Connecting to ${_selectedServer!.name} (VLESS)...';
      notifyListeners();

      // Build VLESS URI from constants and selected server
      final host = _selectedServer!.serverAddress;
      final uuid = AppConstants.vlessUuid;
      final port = AppConstants.vlessPort;
      final path = Uri.encodeComponent(AppConstants.vlessPath);
      final params = AppConstants.vlessTls
          ? 'security=tls&encryption=none&type=ws&path=$path'
          : 'encryption=none&type=ws&path=$path';
      final vlessUri = 'vless://$uuid@$host:$port?$params#${Uri.encodeComponent(_selectedServer!.name)}';

      print('🔗 VLESS connection requested: $vlessUri (${_selectedServer!.name})');

      // Add retry mechanism similar to regular VPN connection
      bool success = false;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (!success && retryCount < maxRetries) {
        try {
          print('🔄 VLESS connection attempt ${retryCount + 1}/$maxRetries');
          
          final result = await FlutterV2RayService.connect(
            vlessUri: vlessUri,
            countryCode: _selectedServer!.countryCode,
            countryName: _selectedServer!.name,
          );

          print('🔍 VLESS Flutter V2Ray result: $result');
          
          if (result['success'] as bool) {
            success = true;
            print('✅ VLESS connection successful on attempt ${retryCount + 1}');
            break;
          } else {
            final error = result['error'] as String? ?? 'Failed to start VLESS connection';
            final code = result['code'] as String?;
            
            print('❌ VLESS connection failed with error: $error (code: $code)');
            
            // Check if it's a NOT_IMPLEMENTED error (shouldn't happen now, but handle gracefully)
            if (code == 'NOT_IMPLEMENTED') {
              _statusMessage = 'VLESS not yet available. Please use Classic mode.';
              _isConnecting = false;
              notifyListeners();
              return;
            }
            
            retryCount++;
            if (retryCount < maxRetries) {
              print('⚠️ VLESS connection failed: $error, retrying in 2 seconds... (${retryCount}/$maxRetries)');
              await Future.delayed(const Duration(seconds: 2));
            } else {
              throw Exception(error);
            }
          }
        } catch (e) {
          retryCount++;
          if (retryCount < maxRetries) {
            print('❌ VLESS connection error: $e, retrying in 2 seconds... (${retryCount}/$maxRetries)');
            await Future.delayed(const Duration(seconds: 2));
          } else {
            rethrow; // Re-throw on final attempt
          }
        }
      }
      
      if (success) {
        _connectionStartTime = DateTime.now();
        
        // Add timeout to stop spinning animation if no status update comes
        Timer(Duration(seconds: 8), () {
          if (_isConnecting && !_isConnected) {
            print('⏰ VLESS connection timeout - assuming connected');
            _isConnected = true;
            _isConnecting = false;
            _statusMessage = 'Connected to ${_selectedServer!.name} (VLESS)';
            _connectionStartTime = DateTime.now();
            
            // Show interstitial ad after connection (for premium users or when rewarded ads are disabled)
            print('🎯 VLESS timeout triggered - showing interstitial ad after connection');
            _showAdOnVPNConnect();
            
            _updateCurrentIPInfo();
            notifyListeners();
          }
        });
        
      } else {
        throw Exception('Failed to start VLESS connection after $maxRetries attempts');
      }

    } catch (e) {
      _isConnecting = false;
      _statusMessage = 'Connection failed: $e';
      
      notifyListeners();
      print('❌ VLESS connection failed: $e');
    }
  }

  // Disconnect VPN
  Future<void> disconnect() async {
    if (!_isConnected && !_isConnecting) return;

    try {
      // Set disconnecting state
      _isConnecting = true; // Use connecting state for disconnecting animation
      _statusMessage = 'Disconnecting...';
      notifyListeners();

      // Call native disconnect based on protocol
      if (_protocolMode == ProtocolMode.vless) {
        await FlutterV2RayService.disconnect();
      } else {
        await NativeVPNService.disconnect();
      }
      
      // Force update state immediately (don't wait for native callback)
      _isConnected = false;
      _isConnecting = false;
      _statusMessage = 'VPN Disconnected';
      _connectionStartTime = null;
      
      // Update IP info after disconnection
      await _updateCurrentIPInfo();
      
      notifyListeners();
      print('✅ VPN disconnected successfully');
      
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      _statusMessage = 'Disconnection failed: $e';
      notifyListeners();
      print('❌ VPN disconnection failed: $e');
    }
  }

  // Toggle connection
  Future<void> toggleConnection([BuildContext? context]) async {
    if (_isConnected) {
      await disconnect();
    } else {
      await connect(context);
    }
  }


  // Get connection duration
  Duration? get connectionDuration {
    if (_connectionStartTime == null) return null;
    return DateTime.now().difference(_connectionStartTime!);
  }

  // Check if server is accessible
  bool isServerAccessible(VPNServer server) {
    // Free servers are always accessible
    if (!server.isPremium) return true;
    
    // Premium servers require subscription
    // TODO: Check subscription status
    return false; // For now, assume no subscription
  }

  // Update current IP and location information
  Future<void> _updateCurrentIPInfo() async {
    try {
      final ipInfo = await IPService.getCurrentIPInfo();
      if (ipInfo != null) {
        // Store original IP if not set
        if (_originalIP == null && !_isConnected) {
          _originalIP = ipInfo['ip'];
        }
        
        _currentIP = ipInfo['ip'];
        _currentLocation = ipInfo;
        
        print('📍 Current location: ${ipInfo['country']}, ${ipInfo['city']} (${ipInfo['ip']})');
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error updating IP info: $e');
    }
  }

  // Get current location info as a formatted string
  String get currentLocationString {
    if (_currentLocation == null) return 'Unknown Location';
    
    final country = _currentLocation!['country'] ?? 'Unknown';
    final city = _currentLocation!['city'] ?? 'Unknown';
    return '$country, $city';
  }

  // Check if IP has changed (useful for detecting VPN status)
  Future<bool> hasIPChanged() async {
    if (_originalIP == null) return false;
    return await IPService.hasIPChanged(_originalIP!);
  }

  // Get reward cooldown status for UI
  Future<String> getRewardCooldownStatus() async {
    final remainingTime = await RewardCooldownService.getRemainingCooldownText();
    if (remainingTime.isNotEmpty) {
      return 'Free VPN access: $remainingTime remaining';
    }
    return '';
  }

  // Check if user has free VPN access (in cooldown period)
  Future<bool> hasFreeVPNAccess() async {
    return await RewardCooldownService.isInCooldownPeriod();
  }

  // Show ad on VPN connect (matching iOS behavior with Firebase config)
  void _showAdOnVPNConnect() {
    // No ads after connection - user already watched rewarded ad before connecting
    print('ℹ️ Skipping post-connection ad - user already watched rewarded ad');
  }

  // Verify VPN connection by checking if IP actually changed
  Future<void> _verifyVPNConnection() async {
    if (!_isConnected) return;
    
    // Check if server address from Remote Config is a placeholder/example
    final serverAddress = _selectedServer?.serverAddress ?? '';
    if (serverAddress.contains('example.com') || 
        serverAddress.contains('example.org') ||
        serverAddress.isEmpty ||
        serverAddress == 'vpn.example.com') {
      print('❌ WARNING: Server address from Remote Config is a placeholder: $serverAddress');
      print('❌ VPN will NOT work with placeholder addresses!');
      print('💡 Update the "vpn_servers" parameter in Firebase Remote Config');
      print('💡 Replace placeholder addresses (like "us.example.com") with REAL VPN server addresses');
      print('💡 VPN credentials are hardcoded and will work with any valid server address');
      _statusMessage = '⚠️ Invalid server address from Remote Config';
      notifyListeners();
      return;
    }
    
    print('🔍 Verifying VPN connection - checking if IP changed...');
    print('🌐 Connected to server: $serverAddress');
    
    // Check IP multiple times with delays (VPN might take time to route traffic)
    for (int attempt = 1; attempt <= 5; attempt++) {
      await Future.delayed(Duration(seconds: attempt * 2)); // 2, 4, 6, 8, 10 seconds
      
      print('🔍 IP verification attempt $attempt/5...');
      
      final previousIP = _currentIP;
      await _updateCurrentIPInfo();
      
      if (previousIP != null && _currentIP != null && previousIP != _currentIP) {
        print('✅ VPN is working! IP changed from $previousIP to $_currentIP');
        print('📍 Current location after VPN: ${_currentLocation?['country']}, ${_currentLocation?['city']}');
        _statusMessage = 'Connected to ${_selectedServer?.name}';
        notifyListeners();
        return;
      }
      
      // Also check if location changed (even if IP check is slow)
      if (_originalIP != null && _currentIP != null && _originalIP != _currentIP) {
        print('✅ VPN is working! IP changed from original $_originalIP to $_currentIP');
        print('📍 Current location after VPN: ${_currentLocation?['country']}, ${_currentLocation?['city']}');
        _statusMessage = 'Connected to ${_selectedServer?.name}';
        notifyListeners();
        return;
      }
    }
    
    // If IP hasn't changed after multiple checks, VPN might not be routing traffic
    print('⚠️ VPN connected but IP hasn\'t changed - VPN might not be routing traffic');
    print('⚠️ Original IP: $_originalIP, Current IP: $_currentIP');
    print('⚠️ Server address: $serverAddress');
    print('💡 This could mean:');
    print('   - VPN server address is invalid or placeholder');
    print('   - VPN server is not working or not accessible');
    print('   - VPN is connected but not routing all traffic');
    print('   - IP check service is using cached results');
      print('💡 Check:');
      print('   - Server addresses in Firebase Remote Config "vpn_servers" must be REAL VPN servers');
      print('   - Server addresses cannot be placeholders like "example.com"');
      print('   - VPN credentials come from Remote Config parameters: vpn_username, vpn_password, vpn_shared_secret');
    
    // Update status to warn user
    _statusMessage = '⚠️ Connected but IP not changed - check server config';
    notifyListeners();
  }
}

enum ProtocolMode { ipsec, vless }

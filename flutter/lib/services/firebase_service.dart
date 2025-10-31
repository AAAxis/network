import 'dart:async';
import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/vpn_server.dart';

class FirebaseService {
  static FirebaseRemoteConfig? _remoteConfig;

  /// Fetch VPN servers from Firebase Remote Config
  static Future<List<VPNServer>> getServers() async {
    try {
      print('🔥 Fetching servers from Firebase Remote Config...');
      
      // Check if Firebase is initialized
      try {
        final app = Firebase.app();
        print('✅ Firebase app instance found: ${app.name}');
      } catch (e) {
        print('❌ CRITICAL: Firebase app not initialized! Error: $e');
        print('⚠️ Make sure Firebase.initializeApp() was called in main()');
        return [];
      }
      
      // Get Remote Config instance
      _remoteConfig ??= FirebaseRemoteConfig.instance;
      
      // Configure Remote Config settings to allow fresh fetches
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, // Allow immediate fetch (no cache delay)
      ));
      
      // Force fetch fresh values from Remote Config
      try {
        print('📥 Fetching fresh Remote Config values...');
        bool updated = await _remoteConfig!.fetchAndActivate();
        
        if (updated) {
          print('✅ Remote Config values fetched and activated (fresh)');
        } else {
          print('ℹ️ Remote Config fetch returned cached values (but will use them)');
        }
      } catch (e) {
        print('⚠️ Error fetching Remote Config, trying to use cached: $e');
      }
      
      // Get servers JSON from Remote Config
      final serversJsonString = _remoteConfig!.getString('vpn_servers');
      
      // Log what we got for debugging
      print('📋 Remote Config "vpn_servers" value length: ${serversJsonString.length} characters');
      if (serversJsonString.length > 0 && serversJsonString.length < 500) {
        print('📋 Remote Config "vpn_servers" preview: ${serversJsonString.substring(0, serversJsonString.length > 200 ? 200 : serversJsonString.length)}...');
      }
      
      if (serversJsonString.isEmpty) {
        print('⚠️ No servers found in Remote Config parameter "vpn_servers"');
        print('💡 Make sure you have set the "vpn_servers" parameter in Firebase Remote Config');
        print('💡 Make sure you clicked "Publish changes" in Firebase Console');
        return [];
      }
      
      print('📄 Parsing servers JSON from Remote Config...');
      final serversList = jsonDecode(serversJsonString) as List<dynamic>;
      
      final servers = <VPNServer>[];
      
      for (final serverData in serversList) {
        try {
          final data = serverData as Map<String, dynamic>;
          final serverName = data['name'] ?? 'unknown';
          final serverAddress = data['server_address'] ?? data['serverAddress'] ?? '';
          
          print('📄 Parsing server: $serverName');
          
          // Warn if server address is a placeholder
          if (serverAddress.contains('example.com') || 
              serverAddress.contains('example.org') ||
              serverAddress.isEmpty ||
              serverAddress == 'vpn.example.com') {
            print('⚠️ WARNING: Server "$serverName" has placeholder address: $serverAddress');
            print('⚠️ This server will NOT be connectable!');
            print('💡 Update Remote Config "vpn_servers" with REAL VPN server addresses');
          }
          
          final server = VPNServer.fromJson(data);
          servers.add(server);
          print('✅ Successfully parsed server: ${server.name}');
          print('   - ID: ${server.id}');
          print('   - Country: ${server.countryName} (${server.countryCode})');
          print('   - Server Address: ${server.serverAddress}');
          print('   - Is Premium: ${server.isPremium}');
        } catch (e, stackTrace) {
          print('❌ Error parsing server: $e');
          print('Stack trace: $stackTrace');
          // Continue with other servers even if one fails
        }
      }
      
      print('✅ Successfully parsed ${servers.length} servers from Remote Config');
      return servers;
    } on TimeoutException catch (e) {
      print('❌ Remote Config fetch timeout: $e');
      return [];
    } catch (e, stackTrace) {
      print('❌ Unexpected error fetching servers from Remote Config: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fetch a single server by ID (not used with Remote Config, kept for compatibility)
  static Future<VPNServer?> getServer(String serverId) async {
    final servers = await getServers();
    try {
      return servers.firstWhere((server) => server.id == serverId);
    } catch (e) {
      return null;
    }
  }

  /// Listen to server updates in real-time (using Remote Config updates)
  static Stream<List<VPNServer>> getServersStream() {
    _remoteConfig ??= FirebaseRemoteConfig.instance;
    
    return _remoteConfig!.onConfigUpdated.asyncMap((event) async {
      await _remoteConfig!.activate();
      return await getServers();
    });
  }
}

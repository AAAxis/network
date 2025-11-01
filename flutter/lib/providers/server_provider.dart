import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vpn_server.dart';
import '../services/firebase_service.dart';
import 'vpn_provider.dart';

class ServerProvider with ChangeNotifier {
  List<VPNServer> _availableServers = [];
  VPNServer? _selectedServer;
  bool _isLoading = false;
  String _searchText = '';
  Set<String> _favoriteServers = {};
  int _serverChangeCount = 0;

  // Getters
  List<VPNServer> get availableServers => _availableServers;
  VPNServer? get selectedServer => _selectedServer;
  bool get isLoading => _isLoading;
  String get searchText => _searchText;
  Set<String> get favoriteServers => _favoriteServers;
  int get serverChangeCount => _serverChangeCount;

  // Filtered servers based on search
  List<VPNServer> get filteredServers {
    List<VPNServer> servers = _availableServers;
    
    if (_searchText.isNotEmpty) {
      servers = servers.where((server) {
        return server.name.toLowerCase().contains(_searchText.toLowerCase()) ||
               server.location.toLowerCase().contains(_searchText.toLowerCase());
      }).toList();
    }
    
    // Sort servers: active servers first, then inactive servers last
    servers.sort((server1, server2) {
      if (server1.active && !server2.active) {
        return -1; // server1 (active) comes before server2 (inactive)
      } else if (!server1.active && server2.active) {
        return 1; // server2 (active) comes before server1 (inactive)
      } else {
        // Both have same active status, sort by name
        return server1.name.compareTo(server2.name);
      }
    });
    
    return servers;
  }

  // Favorite servers list
  List<VPNServer> get favoriteServersList {
    final servers = _availableServers.where((server) => 
        _favoriteServers.contains(server.id)).toList();
    
    // Sort favorites: active servers first, then inactive servers last
    servers.sort((server1, server2) {
      if (server1.active && !server2.active) {
        return -1;
      } else if (!server1.active && server2.active) {
        return 1;
      } else {
        return server1.name.compareTo(server2.name);
      }
    });
    
    return servers;
  }

  // Fetch servers from Firebase
  Future<void> fetchServersFromFirebase() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('🔥 Fetching servers from Firebase...');
      // Fetch servers directly from Firebase (no initialization needed)
      final servers = await FirebaseService.getServers();
      
      if (servers.isNotEmpty) {
        _availableServers = servers;
        print('✅ Loaded ${servers.length} real servers from Firebase');
        
        // Debug: Print each server's premium status
        for (final server in servers) {
          print('🔍 Server: ${server.name} (${server.countryCode}) - isPremium: ${server.isPremium}');
        }
        
        // Auto-select first server if no server selected yet
        if (_selectedServer == null && _availableServers.isNotEmpty) {
          _selectedServer = _availableServers.first;
          print('✅ Auto-selected first server: ${_selectedServer!.name}');
        }
      } else {
        print('⚠️ No servers found in Firebase Remote Config');
        print('💡 Check that "vpn_servers" parameter is set in Firebase Remote Config');
        print('💡 Make sure you clicked "Publish changes" in Firebase Console');
      }
    } catch (e) {
      print('❌ Error fetching servers from Firebase: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set selected server
  Future<void> setSelectedServer(VPNServer server, [BuildContext? context]) async {
    _selectedServer = server;
    _serverChangeCount++;
    
    // Also update VPNProvider with the selected server
    if (context != null) {
      try {
        final vpnProvider = Provider.of<VPNProvider>(context, listen: false);
        vpnProvider.setSelectedServer(server);
        print('✅ Updated VPNProvider with selected server: ${server.name}');
      } catch (e) {
        print('⚠️ Could not update VPNProvider: $e');
      }
    }
    
    // Request review after 3 server changes
    if (_serverChangeCount == 3) {
      // TODO: Request app store review
      print('⭐ Requesting review after $_serverChangeCount server changes');
    }
    
    notifyListeners();
  }

  // Update search text
  void updateSearchText(String text) {
    _searchText = text;
    notifyListeners();
  }

  // Toggle favorite server
  void toggleFavorite(VPNServer server) {
    if (_favoriteServers.contains(server.id)) {
      _favoriteServers.remove(server.id);
    } else {
      _favoriteServers.add(server.id);
    }
    saveFavorites(); // Save to SharedPreferences
    notifyListeners();
  }

  // Check if server is favorite
  bool isFavorite(VPNServer server) {
    return _favoriteServers.contains(server.id);
  }

  // Check if server is accessible (free vs premium)
  bool isServerAccessible(VPNServer server) {
    // Free servers are always accessible
    if (!server.isPremium) return true;
    
    // Premium servers require subscription - this is handled by SubscriptionProvider
    // The actual subscription check is done in the UI layer
    return true; // Let the UI handle subscription checks
  }

  // Handle server selection
  Future<void> handleServerSelection(VPNServer server) async {
    // Check if user has access (subscription)
    if (!isServerAccessible(server)) {
      // TODO: Show paywall
      print('🔒 Server is premium only, showing paywall');
      return;
    }
    
    // User has access, now check if server is active
    if (!server.active) {
      // TODO: Show unavailable message
      print('⚠️ Server is currently inactive');
      return;
    }
    
    // Server is accessible and active - select it
    await setSelectedServer(server);
  }

  // Load favorites from local storage
  Future<void> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList('favorite_servers') ?? [];
      _favoriteServers = favoritesJson.toSet();
      print('✅ Loaded ${_favoriteServers.length} favorite servers');
      notifyListeners();
    } catch (e) {
      print('❌ Error loading favorites: $e');
      _favoriteServers = {};
    }
  }

  // Save favorites to local storage
  Future<void> saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_servers', _favoriteServers.toList());
      print('✅ Saved ${_favoriteServers.length} favorite servers');
    } catch (e) {
      print('❌ Error saving favorites: $e');
    }
  }

  // Load server change count from local storage
  Future<void> loadServerChangeCount() async {
    // TODO: Load from SharedPreferences
    _serverChangeCount = 0;
    notifyListeners();
  }

  // Save server change count to local storage
  Future<void> saveServerChangeCount() async {
    // TODO: Save to SharedPreferences
  }
}




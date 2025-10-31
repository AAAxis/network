import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vpn_server.dart';
import '../providers/server_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/native_paywall_service.dart';

class ServerSelector extends StatefulWidget {
  final Function(VPNServer) onServerSelected;

  const ServerSelector({
    super.key,
    required this.onServerSelected,
  });

  @override
  State<ServerSelector> createState() => _ServerSelectorState();
}

class _ServerSelectorState extends State<ServerSelector> {
  String _selectedTab = 'all';
  late TextEditingController _searchController;
  
  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Select Server',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Search bar
          Consumer<ServerProvider>(
            builder: (context, serverProvider, child) {
              // Sync controller text with provider
              if (_searchController.text != serverProvider.searchText) {
                _searchController.text = serverProvider.searchText;
              }
              
              return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
                  controller: _searchController,
              onChanged: (value) {
                    // Update provider search text
                    serverProvider.updateSearchText(value);
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search servers...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
              );
            },
          ),
          
          const SizedBox(height: 20),
          
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildTab('All', 'all'),
                const SizedBox(width: 10),
                _buildTab('Favorites', 'favorites'),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Server list
          Expanded(
            child: Consumer2<ServerProvider, SubscriptionProvider>(
              builder: (context, serverProvider, subscriptionProvider, child) {
                // Show loading indicator while fetching servers
                if (serverProvider.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.green,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Fetching servers...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Use provider's filtered servers (they already handle search filtering)
                List<VPNServer> servers = _selectedTab == 'favorites' 
                    ? serverProvider.favoriteServersList
                    : serverProvider.filteredServers;
                
                // Only show "No servers found" when not loading and servers list is empty
                if (servers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          serverProvider.searchText.isNotEmpty 
                              ? 'No servers match your search'
                              : 'No servers found',
                      style: TextStyle(
                            color: Colors.grey[400],
                        fontSize: 16,
                      ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: servers.length,
                  itemBuilder: (context, index) {
                    final server = servers[index];
                    final isSelected = server.id == serverProvider.selectedServer.id;
                    final isAccessible = !server.isPremium || subscriptionProvider.isSubscribed;
                    
                    return _buildServerItem(
                      server: server,
                      isSelected: isSelected,
                      isAccessible: isAccessible,
                      isFavorite: serverProvider.isFavorite(server),
                      onTap: () => _handleServerSelection(server, serverProvider, subscriptionProvider),
                      onFavoriteToggle: () => serverProvider.toggleFavorite(server),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String tabId) {
    final isSelected = _selectedTab == tabId;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tabId;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildServerItem({
    required VPNServer server,
    required bool isSelected,
    required bool isAccessible,
    required bool isFavorite,
    required VoidCallback onTap,
    required VoidCallback onFavoriteToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.withOpacity(0.1) : Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.green : Colors.grey[700]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Text(
          server.flag,
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(
          server.name,
          style: TextStyle(
            color: isSelected ? Colors.green : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              server.location,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            if (!isAccessible)
              const Text(
                'Premium Server',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Favorite star icon - toggles on double tap
            GestureDetector(
              onDoubleTap: onFavoriteToggle,
              child: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : Colors.grey[400],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Hide dot when server is selected
            if (!isSelected)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: server.statusColor,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Future<void> _handleServerSelection(
    VPNServer server,
    ServerProvider serverProvider,
    SubscriptionProvider subscriptionProvider,
  ) async {
    // For premium servers - require subscription
    if (server.isPremium && !subscriptionProvider.isSubscribed) {
      _showPaywall(server, isRequired: true);
      return;
    }
    
    // For free servers - no paywall, direct connection
    // Check if server is active
    if (!server.active) {
      _showServerUnavailableDialog();
      return;
    }
    
    // Server is accessible and active - select it
    widget.onServerSelected(server);
  }

  Future<bool> _showPaywall(VPNServer server, {bool isRequired = true}) async {
    // Show RevenueCat native paywall
    final serverType = server.isPremium ? 'premium' : 'free';
    final paywallReason = isRequired ? 'required_for_access' : 'upgrade_encouragement';
    
    print('📱 Showing paywall for $serverType server (${server.countryCode}) - Reason: $paywallReason');
    
    final result = await NativePaywallService.presentPaywall(
      context: context,
      source: 'server_selection_${serverType}',
      serverCountry: server.countryCode,
      onPurchaseCompleted: () {
        print('🎉 Purchase completed from $serverType server selection paywall');
      },
      onRestoreCompleted: () {
        print('✅ Purchases restored from $serverType server selection paywall');
      },
      onDismiss: () {
        print('❌ $serverType server selection paywall dismissed');
      },
    );
    
    if (result) {
      print('✅ Paywall completed successfully for $serverType server');
    } else {
      print('❌ Paywall was dismissed or failed for $serverType server');
    }
    
    return result;
  }

  void _showServerUnavailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Server Unavailable',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This server is currently unavailable. Please select another server.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}


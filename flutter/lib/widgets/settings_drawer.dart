import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import '../providers/subscription_provider.dart';
import '../utils/app_constants.dart';

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const Divider(color: Colors.grey),
            
            // Settings sections
            Expanded(
              child: ListView(
                children: [
                  // Subscription Section (only show if user has premium subscription)
                  Consumer<SubscriptionProvider>(
                    builder: (context, subscriptionProvider, child) {
                      // Only show subscription section if user is subscribed
                      if (!subscriptionProvider.isSubscribed) {
                        return const SizedBox.shrink(); // Hide the entire section for free users
                      }
                      
                      return _buildSection(
                        'Subscription',
                        [
                          ListTile(
                            leading: const Icon(Icons.diamond, color: Colors.amber),
                            title: Text(
                              subscriptionProvider.getSubscriptionStatusText(),
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Expires: ${_formatExpiryDate(subscriptionProvider.getSubscriptionExpiryDate())}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  // Support Section
                  _buildSection(
                    'Support',
                    [
                      ListTile(
                        leading: const Icon(Icons.support_agent, color: Colors.blue),
                        title: const Text(
                          'Contact Support',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'All concerns, questions handled by @theholylabs',
                          style: TextStyle(color: Colors.grey),
                        ),
                        onTap: () => _launchTelegramSupport(),
                      ),
                      ListTile(
                        leading: const Icon(Icons.star, color: Colors.amber),
                        title: const Text(
                          'Rate App',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () => _rateApp(),
                      ),
                    ],
                  ),
                  
                  // About Section
                  _buildSection(
                    'About',
                    [
                      ListTile(
                        leading: const Icon(Icons.privacy_tip, color: Colors.green),
                        title: const Text(
                          'Privacy Policy',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () => _launchUrl(AppConstants.privacyPolicyUrl),
                      ),
                      ListTile(
                        leading: const Icon(Icons.description, color: Colors.orange),
                        title: const Text(
                          'Terms of Service',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () => _launchUrl(AppConstants.termsOfServiceUrl),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildInfoTile(String title, String value, {VoidCallback? onTap}) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(color: Colors.grey),
      ),
      onTap: onTap,
      trailing: onTap != null 
          ? const Icon(Icons.copy, color: Colors.grey, size: 16)
          : null,
    );
  }

  String _formatExpiryDate(DateTime? date) {
    if (date == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference < 0) {
      return 'Expired';
    } else if (difference == 0) {
      return 'Expires today';
    } else if (difference == 1) {
      return 'Expires tomorrow';
    } else {
      return '${difference} days remaining';
    }
  }

  Future<void> _launchTelegramSupport() async {
    try {
      final url = Uri.parse(AppConstants.telegramSupportUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('❌ Could not launch Telegram support URL');
      }
    } catch (e) {
      print('❌ Error launching Telegram support: $e');
    }
  }

  Future<void> _rateApp() async {
    try {
      String storeUrl;
      
      // Choose the correct app store URL based on platform
      if (Platform.isIOS) {
        storeUrl = AppConstants.appStoreUrl;
      } else {
        storeUrl = AppConstants.playStoreUrl;
      }
      
      final url = Uri.parse(storeUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        print('✅ Opened app store for rating');
      } else {
        print('❌ Could not launch app store URL: $storeUrl');
      }
    } catch (e) {
      print('❌ Error launching app store: $e');
    }
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('❌ Could not launch URL: $urlString');
      }
    } catch (e) {
      print('❌ Error launching URL: $e');
    }
  }
}


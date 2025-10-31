import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage rewarded ad cooldown (1 hour free VPN after watching ad)
class RewardCooldownService {
  static const String _rewardTimestampKey = 'last_reward_timestamp';
  static const int _cooldownHours = 1; // 1 hour cooldown
  
  /// Check if user is currently in reward cooldown period (has free VPN access)
  static Future<bool> isInCooldownPeriod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRewardTimestamp = prefs.getInt(_rewardTimestampKey);
      
      print('🔍 Checking cooldown - timestamp: $lastRewardTimestamp');
      
      if (lastRewardTimestamp == null) {
        print('🕐 No previous reward found - user needs to watch ad');
        return false;
      }
      
      final lastRewardTime = DateTime.fromMillisecondsSinceEpoch(lastRewardTimestamp);
      final now = DateTime.now();
      final timeDifference = now.difference(lastRewardTime);
      
      print('🔍 Last reward time: $lastRewardTime');
      print('🔍 Current time: $now');
      print('🔍 Time difference: ${timeDifference.inMinutes} minutes');
      
      final isInCooldown = timeDifference.inHours < _cooldownHours;
      
      if (isInCooldown) {
        final remainingMinutes = (_cooldownHours * 60) - timeDifference.inMinutes;
        print('✅ User in reward cooldown: ${remainingMinutes} minutes remaining');
      } else {
        print('⏰ Reward cooldown expired - user needs to watch new ad');
      }
      
      return isInCooldown;
    } catch (e) {
      print('❌ Error checking reward cooldown: $e');
      return false; // Default to requiring ad if error
    }
  }
  
  /// Get remaining cooldown time in minutes
  static Future<int> getRemainingCooldownMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRewardTimestamp = prefs.getInt(_rewardTimestampKey);
      
      if (lastRewardTimestamp == null) {
        return 0;
      }
      
      final lastRewardTime = DateTime.fromMillisecondsSinceEpoch(lastRewardTimestamp);
      final now = DateTime.now();
      final timeDifference = now.difference(lastRewardTime);
      
      final remainingMinutes = (_cooldownHours * 60) - timeDifference.inMinutes;
      return remainingMinutes > 0 ? remainingMinutes : 0;
    } catch (e) {
      print('❌ Error getting remaining cooldown time: $e');
      return 0;
    }
  }
  
  /// Get remaining cooldown time as formatted string (e.g., "45 minutes", "5 minutes")
  static Future<String> getRemainingCooldownText() async {
    final remainingMinutes = await getRemainingCooldownMinutes();
    
    if (remainingMinutes <= 0) {
      return '';
    }
    
    if (remainingMinutes >= 60) {
      final hours = (remainingMinutes / 60).floor();
      final minutes = remainingMinutes % 60;
      if (minutes == 0) {
        return '$hours hour${hours > 1 ? 's' : ''}';
      } else {
        return '$hours hour${hours > 1 ? 's' : ''} $minutes minute${minutes > 1 ? 's' : ''}';
      }
    } else {
      return '$remainingMinutes minute${remainingMinutes > 1 ? 's' : ''}';
    }
  }
  
  /// Save reward timestamp when user watches ad and earns reward
  static Future<void> saveRewardTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_rewardTimestampKey, now);
      
      print('💾 Reward timestamp saved: $now');
      print('💾 Reward time saved: ${DateTime.fromMillisecondsSinceEpoch(now)}');
      print('💾 User gets 1 hour free VPN access');
    } catch (e) {
      print('❌ Error saving reward timestamp: $e');
    }
  }
  
  /// Clear reward timestamp (for testing or manual reset)
  static Future<void> clearRewardTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rewardTimestampKey);
      print('🗑️ Reward timestamp cleared');
    } catch (e) {
      print('❌ Error clearing reward timestamp: $e');
    }
  }
  
  /// Get last reward time for debugging
  static Future<DateTime?> getLastRewardTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRewardTimestamp = prefs.getInt(_rewardTimestampKey);
      
      if (lastRewardTimestamp == null) {
        return null;
      }
      
      return DateTime.fromMillisecondsSinceEpoch(lastRewardTimestamp);
    } catch (e) {
      print('❌ Error getting last reward time: $e');
      return null;
    }
  }
}


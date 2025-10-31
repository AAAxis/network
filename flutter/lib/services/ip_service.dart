import 'dart:convert';
import 'package:http/http.dart' as http;

class IPService {
  // Get current IP information including location
  static Future<Map<String, dynamic>?> getCurrentIPInfo() async {
    try {
      // Use ip-api.com (free, no API key required)
      final response = await http.get(
        Uri.parse('http://ip-api.com/json/'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        return {
          'ip': data['query'] ?? 'Unknown',
          'country': data['country'] ?? 'Unknown',
          'countryCode': data['countryCode'] ?? '',
          'city': data['city'] ?? 'Unknown',
          'region': data['region'] ?? '',
          'regionName': data['regionName'] ?? '',
          'zip': data['zip'] ?? '',
          'lat': data['lat'] ?? 0.0,
          'lon': data['lon'] ?? 0.0,
          'timezone': data['timezone'] ?? '',
          'isp': data['isp'] ?? '',
          'org': data['org'] ?? '',
          'as': data['as'] ?? '',
        };
      } else {
        print('❌ IP API returned status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting IP info: $e');
      
      // Fallback: try alternative service
      try {
        return await _getIPInfoFallback();
      } catch (e2) {
        print('❌ Fallback IP service also failed: $e2');
        return null;
      }
    }
  }

  // Fallback IP service using ipify.org + ipapi.co
  static Future<Map<String, dynamic>?> _getIPInfoFallback() async {
    try {
      // Get IP address first
      final ipResponse = await http.get(
        Uri.parse('https://api.ipify.org?format=json'),
      ).timeout(const Duration(seconds: 5));

      if (ipResponse.statusCode != 200) {
        return null;
      }

      final ipData = json.decode(ipResponse.body) as Map<String, dynamic>;
      final ip = ipData['ip'] as String?;

      if (ip == null) {
        return null;
      }

      // Get location info
      final locationResponse = await http.get(
        Uri.parse('https://ipapi.co/$ip/json/'),
      ).timeout(const Duration(seconds: 5));

      if (locationResponse.statusCode == 200) {
        final locationData = json.decode(locationResponse.body) as Map<String, dynamic>;
        
        return {
          'ip': ip,
          'country': locationData['country_name'] ?? 'Unknown',
          'countryCode': locationData['country_code'] ?? '',
          'city': locationData['city'] ?? 'Unknown',
          'region': locationData['region'] ?? '',
          'regionName': locationData['region'] ?? '',
          'zip': locationData['postal'] ?? '',
          'lat': (locationData['latitude'] as num?)?.toDouble() ?? 0.0,
          'lon': (locationData['longitude'] as num?)?.toDouble() ?? 0.0,
          'timezone': locationData['timezone'] ?? '',
          'isp': locationData['org'] ?? '',
          'org': locationData['org'] ?? '',
          'as': '',
        };
      }

      // If location fails, at least return IP
      return {
        'ip': ip,
        'country': 'Unknown',
        'countryCode': '',
        'city': 'Unknown',
        'region': '',
        'regionName': '',
        'zip': '',
        'lat': 0.0,
        'lon': 0.0,
        'timezone': '',
        'isp': '',
        'org': '',
        'as': '',
      };
    } catch (e) {
      print('❌ Error in fallback IP service: $e');
      return null;
    }
  }

  // Check if IP has changed
  static Future<bool> hasIPChanged(String originalIP) async {
    try {
      final currentInfo = await getCurrentIPInfo();
      if (currentInfo == null) {
        return false;
      }
      
      final currentIP = currentInfo['ip'] as String?;
      return currentIP != null && currentIP != originalIP;
    } catch (e) {
      print('❌ Error checking IP change: $e');
      return false;
    }
  }

  // Get just the IP address (lightweight)
  static Future<String?> getCurrentIP() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.ipify.org?format=json'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['ip'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Error getting current IP: $e');
      return null;
    }
  }
}


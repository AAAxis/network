import 'package:flutter/material.dart';

enum ServerStatus {
  available,
  highPing,
  offline,
}

class VPNServer {
  final String id;
  final String name;
  final String countryCode;
  final String countryName;
  final String city;
  final String serverAddress;
  final bool isPremium;
  final bool active;
  final ServerStatus status;
  final String flag;
  final String? _location;
  final String? loadStatusText;

  VPNServer({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.countryName,
    required this.city,
    required this.serverAddress,
    required this.isPremium,
    required this.active,
    required this.status,
    required this.flag,
    String? location,
    this.loadStatusText,
  }) : _location = location;

  // Get status color
  Color get statusColor {
    switch (status) {
      case ServerStatus.available:
        return Colors.green;
      case ServerStatus.highPing:
        return Colors.orange;
      case ServerStatus.offline:
        return Colors.red;
    }
  }

  // Get location string for search
  String get location {
    return _location ?? '$countryName, $city';
  }

  // Create from JSON (for Remote Config)
  factory VPNServer.fromJson(Map<String, dynamic> data, {String? id}) {
    return VPNServer(
      id: id ?? data['id'] ?? '',
      name: data['name'] ?? '',
      countryCode: data['country_code'] ?? data['countryCode'] ?? '',
      countryName: data['country_name'] ?? data['countryName'] ?? '',
      city: data['city'] ?? '',
      serverAddress: data['server_address'] ?? data['serverAddress'] ?? '',
      isPremium: data['is_premium'] ?? data['isPremium'] ?? false,
      active: data['active'] ?? true,
      status: _parseStatus(data['status']),
      flag: data['flag'] ?? '🏳️',
      location: data['location'] as String?,
      loadStatusText: data['load_status_text'] ?? data['loadStatusText'] as String?,
    );
  }

  // Create from Firestore document (for backward compatibility)
  factory VPNServer.fromFirestore(Map<String, dynamic> data, String docId) {
    return VPNServer.fromJson(data, id: docId);
  }

  // Parse status from string
  static ServerStatus _parseStatus(dynamic status) {
    if (status == null) return ServerStatus.available;
    
    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'available':
      case 'online':
        return ServerStatus.available;
      case 'high_ping':
      case 'highping':
        return ServerStatus.highPing;
      case 'offline':
      case 'unavailable':
        return ServerStatus.offline;
      default:
        return ServerStatus.available;
    }
  }

  // Convert to JSON (for Remote Config)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country_code': countryCode,
      'country_name': countryName,
      'city': city,
      'server_address': serverAddress,
      'is_premium': isPremium,
      'active': active,
      'status': status.toString().split('.').last,
      'flag': flag,
      if (_location != null) 'location': _location,
      if (loadStatusText != null) 'load_status_text': loadStatusText,
    };
  }

  // Copy with method
  VPNServer copyWith({
    String? id,
    String? name,
    String? countryCode,
    String? countryName,
    String? city,
    String? serverAddress,
    bool? isPremium,
    bool? active,
    ServerStatus? status,
    String? flag,
    String? location,
    String? loadStatusText,
  }) {
    return VPNServer(
      id: id ?? this.id,
      name: name ?? this.name,
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      city: city ?? this.city,
      serverAddress: serverAddress ?? this.serverAddress,
      isPremium: isPremium ?? this.isPremium,
      active: active ?? this.active,
      status: status ?? this.status,
      flag: flag ?? this.flag,
      location: location ?? this._location,
      loadStatusText: loadStatusText ?? this.loadStatusText,
    );
  }

  // No fallback servers - Remote Config is required

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is VPNServer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'VPNServer(id: $id, name: $name, countryCode: $countryCode, isPremium: $isPremium)';
  }
}


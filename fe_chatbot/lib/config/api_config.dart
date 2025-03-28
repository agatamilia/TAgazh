import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConfig {
  // Environment Configuration
  static const bool useNgrok = true;
  static const bool isProduction = false;
  
  // Ngrok Configuration
  static const String ngrokSubdomain = '626b-2404-c0-2570-00-17ba-82e9';
  static const String ngrokRegion = 'in'; 
  
  // Server URLs
  static const String productionBaseUrl = 'https://your-production-api.com';
  static const String localBaseUrl = 'http://localhost:5000';
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:5000';
  static const String physicalDeviceBaseUrl = 'http://192.168.125.92:5000';

  // Timeout Settings
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  // Base URL getter with platform detection
  static String get baseUrl {
    if (isProduction) return productionBaseUrl;
    
    if (useNgrok) return 'https://$ngrokSubdomain.ngrok-free.app';
    
    if (kIsWeb) return localBaseUrl;
    
    if (Platform.isAndroid) return androidEmulatorBaseUrl;
    
    if (Platform.isIOS) return localBaseUrl;
    
    return physicalDeviceBaseUrl;
  }

  // API Endpoints
  static String get sessionEndpoint => _buildUrl('/api/sessions');
  static String sessionById(String sessionId) => _buildUrl('/api/sessions/$sessionId');
  static String messages(String sessionId) => _buildUrl('/api/sessions/$sessionId/messages');
  static String messageById(String sessionId, String messageId) => _buildUrl('/api/sessions/$sessionId/messages/$messageId');
  static String get weatherEndpoint => _buildUrl('/api/weather');
  static String get chatEndpoint => _buildUrl('/api/chat');
  static String get transcribeEndpoint => _buildUrl('/api/transcribe');
  static String get uploadEndpoint => _buildUrl('/api/upload');
  static String get healthEndpoint => _buildUrl('/api/health');

  // Request Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (!isProduction && useNgrok) 'ngrok-skip-browser-warning': 'true',
  };

  // Helper Methods
  static String _buildUrl(String endpoint) {
    return '${baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl}'
           '${endpoint.startsWith('/') ? endpoint : '/$endpoint'}';
  }

  static void printConfig() {
    debugPrint('''
API Configuration:
• Production Mode: $isProduction
• Using Ngrok: $useNgrok
• Base URL: $baseUrl
• Timeouts: 
  - Connect: $connectTimeout
  - Receive: $receiveTimeout
  - Send: $sendTimeout
''');
  }
}
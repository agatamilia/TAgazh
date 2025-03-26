// import 'package:flutter/foundation.dart'; // Untuk kIsWeb
// import 'dart:io'; // Untuk Platform

// class ApiConfig {
//   static String get baseUrl {
//     if (kIsWeb) {
//       return 'http://localhost:8080';
//     } else {
//       // Untuk Android emulator
//       if (Platform.isAndroid) {
//         return 'http://10.0.2.2:8080';
//       } 
//       // Untuk iOS emulator
//       else if (Platform.isIOS) {
//         return 'http://localhost:8080';
//       }
//       // Untuk perangkat fisik (ganti dengan IP komputer Anda)
//       else {
//         return 'http://192.168.125.92:8080'; // Ganti dengan IP lokal komputer Anda
//       }
//     }
//   }
  
//   // Session management endpoints
//   static const String sessionEndpoint = '/api/sessions';
//   static const String sessionByIdEndpoint = '/api/sessions/'; // + {sessionId}

//   // Message management endpoints
//   static const String messagesEndpoint = '/api/sessions/{sessionId}/messages';
//   static const String messageByIdEndpoint = '/api/sessions/{sessionId}/messages/'; // + {messageId}

//   // Weather service endpoint
//   static const String weatherEndpoint = '/api/weather';

//   // Chat service endpoint
//   static const String chatEndpoint = '/api/chat';

//   // Audio transcription endpoint
//   static const String transcribeEndpoint = '/api/transcribe';

//   // File upload endpoint
//   static const String uploadEndpoint = '/api/upload';

//   // Health check endpoint
//   static const String healthEndpoint = '/api/health';

//   // Timeout configurations
//   static const Duration connectTimeout = Duration(seconds: 20);
//   static const Duration receiveTimeout = Duration(seconds: 20);

//   // Helper method to build complete URLs with path parameters
//   static String buildUrl(String endpoint, {Map<String, String>? pathParams}) {
//     String url = endpoint;
    
//     if (pathParams != null) {
//       pathParams.forEach((key, value) {
//         url = url.replaceAll('{$key}', value);
//       });
//     }
    
//     return baseUrl + url;
//   }
// }

import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConfig {
  // Configuration flags (set these according to your environment)
  static const bool useNgrok = true; // Set to false for direct local connection
  static const bool isProduction = false; // Set to true in production
  
  // Ngrok configuration (only used when useNgrok is true)
  static const String ngrokSubdomain = '70a7-2404-c0-2130-00-2295-a67c'; // Replace with your ngrok subdomain
  static const String ngrokRegion = 'in'; // Region code (us, eu, ap, au, sa, jp, in)
  
  // Production configuration (only used when isProduction is true)
  static const String productionBaseUrl = 'https://your-production-api.com';
  
  // Local development configuration
  static const String localBaseUrl = 'http://localhost:5000';
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:5000';
  static const String physicalDeviceBaseUrl = 'http://192.168.125.92:5000'; // Replace with your local IP

  static String get baseUrl {
    if (isProduction) {
      return productionBaseUrl;
    }
    
    if (useNgrok) {
      return 'https://$ngrokSubdomain.ngrok-free.app';
    }
    
    if (kIsWeb) {
      return localBaseUrl;
    }
    
    if (Platform.isAndroid) {
      return androidEmulatorBaseUrl;
    }
    
    if (Platform.isIOS) {
      return localBaseUrl;
    }
    
    return physicalDeviceBaseUrl;
  }
  
  // Session management endpoints
  static String get sessionEndpoint => _buildUrl('/api/sessions');
  static String sessionById(String sessionId) => _buildUrl('/api/sessions/$sessionId');

  // Message management endpoints
  static String messages(String sessionId) => _buildUrl('/api/sessions/$sessionId/messages');
  static String messageById(String sessionId, String messageId) => 
      _buildUrl('/api/sessions/$sessionId/messages/$messageId');

  // Service endpoints
  static String get weatherEndpoint => _buildUrl('/api/weather');
  static String get chatEndpoint => _buildUrl('/api/chat');
  static String get transcribeEndpoint => _buildUrl('/api/transcribe');
  static String get uploadEndpoint => _buildUrl('/api/upload');
  static String get healthEndpoint => _buildUrl('/api/health');

  // Timeout configurations
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  // Headers configuration
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (!isProduction && useNgrok) 'ngrok-skip-browser-warning': 'true',
  };

  // Private helper method to build complete URLs
  static String _buildUrl(String endpoint) {
    // Ensure baseUrl doesn't end with slash and endpoint starts with slash
    final normalizedBase = baseUrl.endsWith('/') 
        ? baseUrl.substring(0, baseUrl.length - 1) 
        : baseUrl;
    final normalizedEndpoint = endpoint.startsWith('/') 
        ? endpoint 
        : '/$endpoint';
    
    return normalizedBase + normalizedEndpoint;
  }

  // Debug information
  static void printConfig() {
    debugPrint('API Configuration:');
    debugPrint('• Production Mode: $isProduction');
    debugPrint('• Using Ngrok: $useNgrok');
    debugPrint('• Base URL: $baseUrl');
    debugPrint('• Timeouts: connect=$connectTimeout, receive=$receiveTimeout');
  }
}
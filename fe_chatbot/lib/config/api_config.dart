class ApiConfig {
  // Base URL for the Flask backend
  // Try different options based on your setup
  
  // Option 1: For Android emulator (standard)
  static const String baseUrl = 'http://10.0.2.2:5000';
  
  // Option 2: For physical device - use your computer's actual IP address
  // static const String baseUrl = 'http://192.168.1.100:5000';
  // Replace 192.168.1.100 with your actual computer's IP address on your network
  
  // Option 3: For local testing
  // static const String baseUrl = 'http://localhost:5000';
  
  // API endpoints
  static const String weatherEndpoint = '/api/weather';
  static const String chatEndpoint = '/api/chat';
  static const String transcribeEndpoint = '/api/transcribe';
  static const String ttsEndpoint = '/api/tts';
  static const String uploadEndpoint = '/api/upload';
  
  // Timeout settings (in seconds)
  static const int connectTimeout = 120;
  static const int receiveTimeout = 120;
}


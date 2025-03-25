import 'package:dio/dio.dart';
import '../config/api_config.dart';

class BackendChecker {
  static Future<bool> isBackendRunning() async {
    final Dio dio = Dio();
    dio.options.connectTimeout = Duration(seconds: 5);
    
    try {
      print('Checking if backend is running at ${ApiConfig.baseUrl}');
      final response = await dio.get(ApiConfig.baseUrl);
      print('Backend response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Backend check failed: $e');
      return false;
    }
  }
  
  static Future<String> getBackendStatus() async {
    final bool isRunning = await isBackendRunning();
    return isRunning 
        ? 'Backend is running at ${ApiConfig.baseUrl}'
        : 'Backend is NOT running at ${ApiConfig.baseUrl}';
  }
}


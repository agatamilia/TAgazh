import 'dart:io';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/weather_data.dart';
import '../models/message.dart';
import '../models/chat_session.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl, // Use from config
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      responseType: ResponseType.json,
    ),
  );

  // Add interceptors for logging
  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('API Request: ${options.method} ${options.uri}');
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        print('API Error: ${e.requestOptions.uri} - ${e.message}');
        return handler.next(e);
      },
    ));
  }

  // Session management
  Future<List<ChatSession>> getSessions() async {
    try {
      final response = await _dio.get(ApiConfig.sessionEndpoint);
      return (response.data as List)
          .map((json) => ChatSession.fromMap(json))
          .toList();
    } catch (e) {
      _logError('getSessions', e);
      return [];
    }
  }

  Future<ChatSession> createSession(String name) async {
    try {
      final response = await _dio.post(
        ApiConfig.sessionEndpoint,
        data: {'name': name},
      );
      return ChatSession.fromMap(response.data);
    } catch (e) {
      _logError('createSession', e);
      return ChatSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<void> updateSession(ChatSession session) async {
    try {
      await _dio.put(
        '${ApiConfig.sessionEndpoint}/${session.id}',
        data: {'name': session.name},
      );
    } catch (e) {
      _logError('updateSession', e);
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _dio.delete('${ApiConfig.sessionEndpoint}/$sessionId');
    } catch (e) {
      _logError('deleteSession', e);
    }
  }

  // Message management
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.sessionEndpoint}/$sessionId/messages',
      );
      return (response.data as List)
          .map((json) => ChatMessage.fromMap(json))
          .toList();
    } catch (e) {
      _logError('getMessages', e);
      return [];
    }
  }

  Future<void> saveMessage(ChatMessage message, String sessionId) async {
    try {
      await _dio.post(
        '${ApiConfig.sessionEndpoint}/$sessionId/messages',
        data: message.toApiMap(sessionId),
      );
    } catch (e) {
      _logError('saveMessage', e);
    }
  }

  Future<void> deleteMessage(String sessionId, String messageId) async {
    try {
      await _dio.delete(
        '${ApiConfig.sessionEndpoint}/$sessionId/messages/$messageId',
      );
    } catch (e) {
      _logError('deleteMessage', e);
    }
  }

  Future<void> clearMessages(String sessionId) async {
    try {
      await _dio.delete(
        '${ApiConfig.sessionEndpoint}/$sessionId/messages',
      );
    } catch (e) {
      _logError('clearMessages', e);
    }
  }

  // Weather service
  Future<WeatherData> getWeather(double latitude, double longitude) async {
    try {
      final response = await _dio.get(
        ApiConfig.weatherEndpoint,
        queryParameters: {'lat': latitude, 'lon': longitude},
      );
      return WeatherData.fromJson(response.data);
    } catch (e) {
      _logError('getWeather', e);
      return _getMockWeatherData();
    }
  }

  // Chat service
  Future<Map<String, dynamic>> sendMessage(String message, String sessionId) async {
    try {
      final response = await _dio.post(
        ApiConfig.chatEndpoint,
        data: {
          'message': message,
          'session_id': sessionId,
        },
      );
      return response.data;
    } catch (e) {
      _logError('sendMessage', e);
      return _getMockChatResponse();
    }
  }

  // Audio transcription
  Future<String> transcribeAudio(File audioFile) async {
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'audio_${DateTime.now().millisecondsSinceEpoch}.wav',
        ),
        'model': 'whisper-1',
      });
      
      final response = await _dio.post(
        ApiConfig.transcribeEndpoint,
        data: formData,
      );
      return response.data['transcription'] ?? '';
    } catch (e) {
      _logError('transcribeAudio', e);
      return 'Maaf, saya tidak dapat mengenali suara Anda. Silakan coba lagi atau ketik pertanyaan Anda.';
    }
  }

  // File upload
  Future<Map<String, dynamic>> uploadFile(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });
      
      final response = await _dio.post(
        ApiConfig.uploadEndpoint,
        data: formData,
      );
      return response.data;
    } catch (e) {
      _logError('uploadFile', e);
      return _getMockFileResponse(file);
    }
  }

  // Helper methods
  void _logError(String method, dynamic error) {
    if (error is DioException) {
      print('API Error in $method: ${error.type}');
      print('Path: ${error.requestOptions.path}');
      print('Status: ${error.response?.statusCode}');
      print('Response: ${error.response?.data}');
    } else {
      print('Error in $method: $error');
    }
  }

  WeatherData _getMockWeatherData() {
    return WeatherData(
      temperature: 30.0,
      condition: 'sunny',
      description: 'Cerah',
      location: 'Lokasi Anda',
      advice: 'Cocok untuk panen atau pengeringan hasil panen',
    );
  }

  Map<String, dynamic> _getMockChatResponse() {
    return {
      'response': 'Maaf, saya tidak dapat terhubung ke server saat ini. Silakan coba lagi nanti.',
      'is_farming_related': true
    };
  }

  Map<String, dynamic> _getMockFileResponse(File file) {
    return {
      'message': 'File uploaded successfully',
      'filename': file.path.split('/').last,
      'response': 'Maaf, saya tidak dapat menganalisis gambar ini saat ini. Silakan tambahkan deskripsi tentang gambar ini.'
    };
  }
}
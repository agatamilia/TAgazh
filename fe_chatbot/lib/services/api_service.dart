import 'dart:io';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/weather_data.dart';
import '../models/message.dart';
import '../models/chat_session.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      responseType: ResponseType.json,
    ),
  );

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('API Request: ${options.method} ${options.uri}');
        print('Headers: ${options.headers}');
        print('Data: ${options.data}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('API Response: ${response.statusCode} ${response.requestOptions.uri}');
        print('Response Data: ${response.data}');
        return handler.next(response);
      },
      onError: (DioError e, handler) {
        _logError('DioInterceptor', e);
        return handler.next(e);
      },
    ));
  }

  Future<Response> _requestWithRetry(RequestOptions options, {int retries = 2}) async {
    DioError? lastError;
    
    for (int i = 0; i < retries; i++) {
      try {
        final response = await _dio.fetch(options);
        return response;
      } on DioError catch (e) {
        lastError = e;
        if (i < retries - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    
    throw lastError!;
  }

  // Session management
  Future<List<ChatSession>> getSessions() async {
    try {
      final response = await _requestWithRetry(
        RequestOptions(
          method: 'GET',
          path: ApiConfig.sessionEndpoint,
        ),
      );
      return (response.data as List)
          .map((json) => ChatSession.fromMap(json))
          .toList();
    } catch (e) {
      _logError('getSessions', e);
      rethrow;
    }
  }

  Future<ChatSession> createSession(String name) async {
    try {
      final response = await _requestWithRetry(
        RequestOptions(
          method: 'POST',
          path: ApiConfig.sessionEndpoint,
          data: {'name': name},
        ),
      );
      return ChatSession.fromMap(response.data);
    } catch (e) {
      _logError('createSession', e);
      rethrow;
    }
  }

  Future<void> updateSession(ChatSession session) async {
    try {
      await _requestWithRetry(
        RequestOptions(
          method: 'PUT',
          path: '${ApiConfig.sessionEndpoint}/${session.id}',
          data: {'name': session.name},
        ),
      );
    } catch (e) {
      _logError('updateSession', e);
      rethrow;
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _requestWithRetry(
        RequestOptions(
          method: 'DELETE',
          path: '${ApiConfig.sessionEndpoint}/$sessionId',
        ),
      );
    } catch (e) {
      _logError('deleteSession', e);
      rethrow;
    }
  }

  // Message management
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    try {
      final response = await _requestWithRetry(
        RequestOptions(
          method: 'GET',
          path: '${ApiConfig.sessionEndpoint}/$sessionId/messages',
        ),
      );
      return (response.data as List)
          .map((json) => ChatMessage.fromMap(json))
          .toList();
    } catch (e) {
      _logError('getMessages', e);
      rethrow;
    }
  }

  Future<void> saveMessage(ChatMessage message, String sessionId) async {
    try {
      await _requestWithRetry(
        RequestOptions(
          method: 'POST',
          path: '${ApiConfig.sessionEndpoint}/$sessionId/messages',
          data: message.toApiMap(sessionId),
        ),
      );
    } catch (e) {
      _logError('saveMessage', e);
      rethrow;
    }
  }

  Future<void> deleteMessage(String sessionId, String messageId) async {
    try {
      await _requestWithRetry(
        RequestOptions(
          method: 'DELETE',
          path: '${ApiConfig.sessionEndpoint}/$sessionId/messages/$messageId',
        ),
      );
    } catch (e) {
      _logError('deleteMessage', e);
      rethrow;
    }
  }

  Future<void> clearMessages(String sessionId) async {
    try {
      await _requestWithRetry(
        RequestOptions(
          method: 'DELETE',
          path: '${ApiConfig.sessionEndpoint}/$sessionId/messages',
        ),
      );
    } catch (e) {
      _logError('clearMessages', e);
      rethrow;
    }
  }

  // Weather service
  Future<WeatherData> getWeather(double latitude, double longitude) async {
    try {
      final response = await _requestWithRetry(
        RequestOptions(
          method: 'GET',
          path: ApiConfig.weatherEndpoint,
          queryParameters: {'lat': latitude, 'lon': longitude},
        ),
      );
      return WeatherData.fromJson(response.data);
    } catch (e) {
      _logError('getWeather', e);
      rethrow;
    }
  }

  // Chat service
  Future<Map<String, dynamic>> sendMessage(String message, String sessionId) async {
    try {
      final response = await _requestWithRetry(
        RequestOptions(
          method: 'POST',
          path: ApiConfig.chatEndpoint,
          data: {
            'message': message,
            'session_id': sessionId,
          },
        ),
      );
      return response.data;
    } catch (e) {
      _logError('sendMessage', e);
      rethrow;
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
      
      final response = await _requestWithRetry(
        RequestOptions(
          method: 'POST',
          path: ApiConfig.transcribeEndpoint,
          data: formData,
        ),
      );
      return response.data['transcription'] ?? '';
    } catch (e) {
      _logError('transcribeAudio', e);
      rethrow;
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
      
      final response = await _requestWithRetry(
        RequestOptions(
          method: 'POST',
          path: ApiConfig.uploadEndpoint,
          data: formData,
        ),
      );
      return response.data;
    } catch (e) {
      _logError('uploadFile', e);
      rethrow;
    }
  }

  void _logError(String method, dynamic error) {
    if (error is DioError) {
      print('''
API Error in $method:
- Type: ${error.type}
- Path: ${error.requestOptions.path}
- Status: ${error.response?.statusCode}
- Message: ${error.message}
- Response: ${error.response?.data}
- StackTrace: ${error.stackTrace}
''');
    } else {
      print('''
Error in $method:
- Error: $error
- StackTrace: ${error is Error ? error.stackTrace : ''}
''');
    }
  }
}
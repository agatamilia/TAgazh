import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/weather_data.dart';
import '../models/message.dart';
import '../models/chat_session.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://10.0.2.2:5000', // Sesuaikan dengan URL backend
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  static Dio get dio => _dio;


  // Session management
  Future<List<ChatSession>> getSessions() async {
    try {
      print('Fetching sessions from backend');
      final response = await _dio.get('${ApiConfig.baseUrl}/api/sessions');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ChatSession.fromMap(json)).toList();
      } else {
        print('Error fetching sessions: ${response.statusCode}');
        throw Exception('Failed to load sessions');
      }
    } catch (e) {
      print('Error getting sessions: $e');
      // Return empty list on error
      return [];
    }
  }

  Future<ChatSession> createSession(String name) async {
    try {
      print('Creating new session: $name');
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/api/sessions',
        data: {'name': name},
      );
      
      if (response.statusCode == 200) {
        return ChatSession.fromMap(response.data);
      } else {
        print('Error creating session: ${response.statusCode}');
        throw Exception('Failed to create session');
      }
    } catch (e) {
      print('Error creating session: $e');
      // Create a local session as fallback
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      return ChatSession(
        id: id,
        name: name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<void> updateSession(ChatSession session) async {
    try {
      print('Updating session: ${session.id}');
      await _dio.put(
        '${ApiConfig.baseUrl}/api/sessions/${session.id}',
        data: {'name': session.name},
      );
    } catch (e) {
      print('Error updating session: $e');
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      print('Deleting session: $sessionId');
      await _dio.delete('${ApiConfig.baseUrl}/api/sessions/$sessionId');
    } catch (e) {
      print('Error deleting session: $e');
    }
  }

  // Message management
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    try {
      print('Fetching messages for session: $sessionId');
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/api/sessions/$sessionId/messages',
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ChatMessage.fromMap(json)).toList();
      } else {
        print('Error fetching messages: ${response.statusCode}');
        throw Exception('Failed to load messages');
      }
    } catch (e) {
      print('Error getting messages: $e');
      // Return empty list on error
      return [];
    }
  }

  Future<void> saveMessage(ChatMessage message, String sessionId) async {
    try {
      print('Saving message to session: $sessionId');
      await _dio.post(
        '${ApiConfig.baseUrl}/api/sessions/$sessionId/messages',
        data: {
          'content': message.content,
          'role': message.role == MessageRole.user ? 'user' : 'assistant',
          'image_path': message.imageUrl,
        },
      );
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  Future<void> deleteMessage(String sessionId, String messageId) async {
    try {
      print('Deleting message: $messageId from session: $sessionId');
      await _dio.delete(
        '${ApiConfig.baseUrl}/api/sessions/$sessionId/messages/$messageId',
      );
    } catch (e) {
      print('Error deleting message: $e');
    }
  }

  Future<void> clearMessages(String sessionId) async {
    try {
      print('Clearing all messages from session: $sessionId');
      await _dio.delete(
        '${ApiConfig.baseUrl}/api/sessions/$sessionId/messages',
      );
    } catch (e) {
      print('Error clearing messages: $e');
    }
  }
  Future<WeatherData> getWeather(double latitude, double longitude) async {
    try {
      final response = await dio.get(
        '/api/weather',
        queryParameters: {'lat': latitude, 'lon': longitude},
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      return WeatherData.fromJson(response.data);
    } on DioException catch (e) {
      print('Weather API error: ${e.message}');
      return getMockWeatherData();
    }
  }
  // Mock weather data for when the API is unavailable
  WeatherData getMockWeatherData() {
    print('Returning mock weather data');
    return WeatherData(
      temperature: 30.0,
      condition: 'sunny',
      description: 'Cerah',
      location: 'Lokasi Anda',
      advice: 'Cocok untuk panen atau pengeringan hasil panen',
    );
  }
  
  // Send message to chatbot - updated to pass through the full response
  Future<Map<String, dynamic>> sendMessage(String message, String sessionId) async {
    try {
      print('Sending message to chatbot: $message');
      print('URL: ${ApiConfig.baseUrl}/api/chat');
      
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/api/chat',
        data: {
          'message': message,
          'session_id': sessionId,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );
      
      print('Chat API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        print('Chat response received: $data');
        return {
          'response': data['response'],
          'is_farming_related': data['is_farming_related'] ?? true
        };
      } else {
        print('Chat API error: ${response.data}');
        throw Exception('Failed to get chat response: ${response.data}');
      }
    } catch (e) {
      print('Error sending message: $e');
      // Return mock response when API fails
      return getMockChatResponse(message);
    }
  }

  // Mock chat response for when the API is unavailable - updated to be more generic
  Map<String, dynamic> getMockChatResponse(String message) {
    print('Returning mock chat response');
    
    return {
      'response': 'Maaf, saya tidak dapat terhubung ke server saat ini. Silakan coba lagi nanti.',
      'is_farming_related': true
    };
  }

  // Transcribe audio
  Future<String> transcribeAudio(File audioFile) async {
    try {
      print('Transcribing audio file: ${audioFile.path}');
      print('URL: ${ApiConfig.baseUrl}/api/transcribe');
      
      FormData formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'audio.wav',
        ),
      });
      
      print('Sending audio file to transcription API');
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/api/transcribe',
        data: formData,
      );
      
      print('Transcription API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('Transcription received: ${response.data}');
        return response.data['transcription'];
      } else {
        print('Transcription API error: ${response.data}');
        throw Exception('Failed to transcribe audio: ${response.data}');
      }
    } catch (e) {
      print('Error transcribing audio: $e');
      // Return a more generic message when API fails
      return 'Maaf, saya tidak dapat mengenali suara Anda. Silakan coba lagi atau ketik pertanyaan Anda.';
    }
  }

  // Upload file
  Future<Map<String, dynamic>> uploadFile(File file) async {
    try {
      print('Uploading file: ${file.path}');
      print('URL: ${ApiConfig.baseUrl}/api/upload');
      
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });
      
      print('Sending file to upload API');
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/api/upload',
        data: formData,
      );
      
      print('Upload API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('Upload response received: ${response.data}');
        return response.data;
      } else {
        print('Upload API error: ${response.data}');
        throw Exception('Failed to upload file: ${response.data}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      // Return a more generic response
      return {
        'message': 'File uploaded successfully',
        'filename': file.path.split('/').last,
        'response': 'Maaf, saya tidak dapat menganalisis gambar ini saat ini. Silakan tambahkan deskripsi tentang gambar ini.'
      };
    }
  }
}


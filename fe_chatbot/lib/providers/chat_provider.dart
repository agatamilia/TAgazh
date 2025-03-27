import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/permission_service.dart';
import 'session_provider.dart';
import '../services/tts_service.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final ApiService _apiService = ApiService();
  final AudioService _audioService = AudioService();
  final TTSService _ttsService = TTSService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isListening = false;
  bool _useVoiceOutput = true;
  bool _isInitialized = false;
  File? _pendingImage;
  String _currentSessionId = '';

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  bool get useVoiceOutput => _useVoiceOutput;
  bool get hasImagePending => _pendingImage != null;

  ChatProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      await _ttsService.initialize();
      await _initAudio();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing ChatProvider: $e');
    }
  }

  Future<void> _initAudio() async {
    await _audioService.initRecorder();
    await _audioService.initPlayer();
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> loadMessages(String sessionId) async {
    if (_currentSessionId == sessionId && _messages.isNotEmpty) return;
    
    _messages.clear();
    _currentSessionId = sessionId;
    _isLoading = true;
    notifyListeners();
    
    try {
      final savedMessages = await _apiService.getMessages(sessionId);
      
      if (savedMessages.isNotEmpty) {
        _messages.addAll(savedMessages);
      } else {
        _addWelcomeMessage(sessionId);
      }
    } catch (e) {
      print('Error loading messages: $e');
      _addWelcomeMessage(sessionId);
      
      if (_messages.isEmpty) {
        _addConnectionErrorMessage();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _addWelcomeMessage(String sessionId) {
    _messages.add(ChatMessage(
      content: "Selamat datang di PeTaniku! Saya siap membantu dengan pertanyaan seputar pertanian.",
      role: MessageRole.assistant,
    ));
  }

  void _addConnectionErrorMessage() {
    _messages.add(ChatMessage(
      content: "Saya tidak dapat terhubung ke server saat ini. Beberapa fitur mungkin terbatas. "
               "Pesan Anda akan disimpan secara lokal dan akan disinkronkan ketika koneksi pulih.",
      role: MessageRole.assistant, // Changed from system to assistant
    ));
  }


  void toggleVoiceOutput() {
    _useVoiceOutput = !_useVoiceOutput;
    notifyListeners();
  }

  Future<void> sendMessage(String text, String sessionId, SessionProvider sessionProvider) async {
    if (text.isEmpty && !hasImagePending) return;
    
    final userMessage = ChatMessage(
      content: text,
      role: MessageRole.user,
      imageUrl: _pendingImage?.path,
    );
    _messages.add(userMessage);
    notifyListeners();
    
    try {
      await _apiService.saveMessage(userMessage, sessionId);
    } catch (e) {
      print('Failed to save message: $e');
    }
    
    if (_messages.length == 1) {
      final sessionName = text.length > 30 ? '${text.substring(0, 30)}...' : text;
      try {
        await sessionProvider.updateSessionName(sessionId, sessionName);
      } catch (e) {
        print('Failed to update session name: $e');
      }
    }
    
    _pendingImage = null;
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _apiService.sendMessage(text, sessionId);
      await _addBotMessage(response['response'], sessionId);
    } catch (e) {
      print('Error sending message: $e');
      await _addBotMessage(_getErrorMessage(e), sessionId);
    }
  }

  String _getErrorMessage(dynamic error) {
    return "Terjadi kesalahan tak terduga. Silakan coba lagi.";
  }

Future<void> _addBotMessage(String content, String sessionId) async {
    final cleanContent = content.replaceAll('*', ''); // Bersihkan asterisk
    final botMessage = ChatMessage(
      content: content,
      cleanContent: cleanContent, // Simpan versi bersih
      role: MessageRole.assistant,
    );
    
    _messages.add(botMessage);
    
    try {
      await _apiService.saveMessage(botMessage, sessionId);
    } catch (e) {
      print('Failed to save bot message: $e');
    }
    
    _isLoading = false;
    notifyListeners();
    
    if (_useVoiceOutput) {
      _speakText(botMessage.cleanContent); // Gunakan clean content untuk TTS
    }
  }
  Future<void> _speakText(String text) async {
    try {
      // Pastikan text sudah clean dari formatting
      final cleanText = text.replaceAll('*', '');
      await _ttsService.speak(cleanText);
    } catch (e) {
      print('Error speaking text: $e');
    }
  }

// In chat_provider.dart
  Future<void> startListening(BuildContext context) async {
    try {
      // Check permissions
      if (!await PermissionService.hasMicrophonePermission()) {
        final granted = await PermissionService.requestMicrophonePermission();
        if (!granted && context.mounted) {
          await PermissionService.showPermissionDialog(context, 'Mikrofon');
          return;
        }
      }

      // Initialize and start recording
      await _audioService.initRecorder();
      await _audioService.startRecording();
      
      _isListening = true;
      notifyListeners();
    } catch (e) {
      _isListening = false;
      notifyListeners();
      _showErrorSnackbar(context, 'Gagal memulai rekaman: ${e.toString()}');
    }
  }

  Future<void> stopListening(String sessionId, SessionProvider sessionProvider) async {
    if (!_isListening) return;
    
    _isListening = false;
    _isLoading = true;
    notifyListeners();

    try {
      // Stop recording and get file
      final recordingPath = await _audioService.stopRecording();
      if (recordingPath == null) {
        throw Exception('No recording path available');
      }

      final recordingFile = _audioService.getRecordingFile();
      if (recordingFile == null || !await recordingFile.exists()) {
        throw Exception('Recording file not found');
      }

      // Add temporary audio message
      final audioMessage = ChatMessage(
        id: 'audio_${DateTime.now().millisecondsSinceEpoch}',
        content: 'Mengolah pesan suara...',
        role: MessageRole.user,
        isAudio: true,
      );
      _addMessage(sessionId, audioMessage);

      // Send to Whisper
      final transcription = await _apiService.transcribeAudio(recordingFile);
      
      // Update the message with transcription
      final index = messages.indexWhere((m) => m.id == audioMessage.id);
      if (index != -1) {
        messages[index] = messages[index].copyWith(content: transcription);
      }

      // Send as normal message
      await sendMessage(transcription, sessionId, sessionProvider);
    } catch (e) {
      _addBotMessage("Gagal memproses rekaman suara: ${e.toString()}", sessionId);
      print('Error in stopListening: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void cancelListening() {
    _isListening = false;
    _audioService.stopRecording();
    notifyListeners();
  }

  void _addMessage(String sessionId, ChatMessage message) {
    messages.add(message);
    notifyListeners();
    // Optionally save to backend
    _apiService.saveMessage(message, sessionId);
  }
  Future<void> pickImage(BuildContext context) async {
    try {
      final hasPermission = await PermissionService.hasStoragePermission();
      if (!hasPermission && await PermissionService.requestStoragePermission() == false) {
        if (context.mounted) {
          await PermissionService.showPermissionDialog(context, 'Penyimpanan');
        }
        return;
      }
      
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      
      if (pickedFile == null) return;
      
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
      
      _pendingImage = savedImage;
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gambar telah dipilih. Silakan ketik pertanyaan Anda dan kirim.'),
            duration: Duration(seconds: 3),
          )
        );
      }
      
      notifyListeners();
    } catch (e) {
      print('Error picking image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memilih gambar. Silakan coba lagi.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> deleteMessage(String messageId, String sessionId) async {
    _messages.removeWhere((message) => message.id == messageId);
    notifyListeners();
    
    try {
      await _apiService.deleteMessage(sessionId, messageId);
    } catch (e) {
      print('Failed to delete message: $e');
      _messages.add(ChatMessage(
        content: 'Gagal menghapus pesan dari server. Pesan hanya dihapus secara lokal.',
        role: MessageRole.assistant, // Changed from system to assistant
      ));
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}
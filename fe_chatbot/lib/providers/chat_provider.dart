import 'dart:io';
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
      // Initialize TTS service
      await _ttsService.initialize();
      
      // Initialize audio service
      await _initAudio();
      
      _isInitialized = true;
    } catch (e) {
      print('Error initializing ChatProvider: $e');
    }
  }

  Future<void> loadMessages(String sessionId) async {
    if (_currentSessionId == sessionId && _messages.isNotEmpty) {
      // Already loaded this session
      return;
    }
    
    _messages.clear();
    _currentSessionId = sessionId;
    
    try {
      _isLoading = true;
      notifyListeners();
      
      final savedMessages = await _apiService.getMessages(sessionId);
      
      if (savedMessages.isNotEmpty) {
        _messages.addAll(savedMessages);
      } else {
        // Add welcome message if this is a new conversation
        _addBotMessage(
          "Selamat datang di PeTaniku! Saya siap membantu dengan pertanyaan seputar pertanian, perkebunan, dan peternakan. Apa yang ingin Anda tanyakan hari ini?",
          sessionId,
        );
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading messages: $e');
      // Add welcome message if there was an error
      _addBotMessage(
        "Selamat datang di PeTaniku! Saya siap membantu dengan pertanyaan seputar pertanian, perkebunan, dan peternakan. Apa yang ingin Anda tanyakan hari ini?",
        sessionId,
      );
      
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initAudio() async {
    try {
      print('Initializing audio service');
      await _audioService.initRecorder();
      print('Audio service initialized successfully');
    } catch (e) {
      print('Error initializing audio: $e');
    }
  }

  void toggleVoiceOutput() {
    _useVoiceOutput = !_useVoiceOutput;
    print('Voice output ${_useVoiceOutput ? 'enabled' : 'disabled'}');
    notifyListeners();
  }

  Future<void> sendMessage(String text, String sessionId, SessionProvider sessionProvider) async {
    if (text.isEmpty && !hasImagePending) return;
    
    print('Sending message: $text');
    
    // Check if this is the first message in the session
    bool isFirstMessage = _messages.length <= 1; // Only welcome message
    
    // Add user message
    final userMessage = ChatMessage(
      content: text,
      role: MessageRole.user,
      imageUrl: _pendingImage?.path,
    );
    _messages.add(userMessage);
    notifyListeners();
    
    await _apiService.saveMessage(userMessage, sessionId);
    
    // If this is the first user message, update the session name
    if (isFirstMessage) {
      // Extract a name from the first question (up to 30 chars)
      String sessionName = text.length > 30 ? text.substring(0, 30) + '...' : text;
      await sessionProvider.updateSessionName(sessionId, sessionName);
    }
    
    // Update session timestamp
    await sessionProvider.updateSessionTimestamp(sessionId);
    
    // Clear pending image after sending
    _pendingImage = null;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Get response from API
      print('Calling backend API for response');
      final response = await _apiService.sendMessage(text, sessionId);
      
      final String responseText = response['response'];
      final bool isFarmingRelated = response['is_farming_related'] ?? true;
      
      await _addBotMessage(responseText, sessionId);
      
      // If not farming related, offer to open DeepSeek AI
      if (!isFarmingRelated) {
        print('Question is not farming-related, offering to open DeepSeek AI');
      }
    } catch (e) {
      print('Error sending message: $e');
      await _addBotMessage("Maaf, terjadi kesalahan saat memproses pesan Anda. Silakan coba lagi.", sessionId);
    }
  }

  Future<void> _addBotMessage(String content, String sessionId) async {
    print('Adding bot message: $content');
    final botMessage = ChatMessage(
      content: content,
      role: MessageRole.assistant,
    );
    _messages.add(botMessage);
    
    // Save message to backend
    await _apiService.saveMessage(botMessage, sessionId);
    
    _isLoading = false;
    notifyListeners();
    
    // Speak the response if voice output is enabled
    if (_useVoiceOutput) {
      _speakText(content);
    }
  }

  Future<void> _speakText(String text) async {
    await _ttsService.speak(text);
  }

  Future<void> startListening(BuildContext context) async {
    try {
      // Check microphone permission
      bool hasPermission = await PermissionService.hasMicrophonePermission();
      if (!hasPermission) {
        print('Requesting microphone permission');
        hasPermission = await PermissionService.requestMicrophonePermission();
        if (!hasPermission) {
          print('Microphone permission denied');
          if (context.mounted) {
            await PermissionService.showPermissionDialog(context, 'Mikrofon');
          }
          return;
        }
      }
      
      _isListening = true;
      notifyListeners();
      
      print('Starting audio recording');
      await _audioService.startRecording();
    } catch (e) {
      print('Error starting recording: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  Future<void> stopListening(String sessionId, SessionProvider sessionProvider) async {
    try {
      _isListening = false;
      notifyListeners();
      
      print('Stopping recording');
      final recordingPath = await _audioService.stopRecording();
      
      if (recordingPath != null) {
        final recordingFile = _audioService.getRecordingFile();
        
        if (recordingFile != null) {
          _isLoading = true;
          notifyListeners();
          
          try {
            // Transcribe the audio
            print('Transcribing audio recording');
            final transcription = await _apiService.transcribeAudio(recordingFile);
            
            print('Transcription result: $transcription');
            
            if (transcription.isNotEmpty && transcription != 'Maaf, saya tidak dapat mengenali suara Anda. Silakan coba lagi atau ketik pertanyaan Anda.') {
              // Send the transcribed text directly to get a response
              await sendMessage(transcription, sessionId, sessionProvider);
            } else {
              _isLoading = false;
              notifyListeners();
              
              // Log error message instead of showing SnackBar
              print('Tidak dapat mengenali suara. Silakan coba lagi.');
            }
          } catch (e) {
            print('Error processing audio: $e');
            await _addBotMessage("Maaf, terjadi kesalahan saat memproses rekaman suara Anda. Silakan coba lagi.", sessionId);
            _isLoading = false;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      print('Error stopping recording: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void cancelListening() {
    print('Cancelling listening');
    _isListening = false;
    _audioService.stopRecording();
    notifyListeners();
  }

  Future<void> pickImage(BuildContext context) async {
    try {
      // Check storage permission
      bool hasPermission = await PermissionService.hasStoragePermission();
      if (!hasPermission) {
        print('Requesting storage permission');
        hasPermission = await PermissionService.requestStoragePermission();
        if (!hasPermission) {
          print('Storage permission denied');
          if (context.mounted) {
            await PermissionService.showPermissionDialog(context, 'Penyimpanan');
          }
          return;
        }
      }
      
      // Pick image from gallery
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      
      if (pickedFile == null) {
        print('No image selected');
        return;
      }
      
      // Copy the image to app's documents directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
      
      // Store the image as pending until the user sends a message
      _pendingImage = savedImage;
      
      // Show a snackbar to inform the user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gambar telah dipilih. Silakan ketik pertanyaan Anda dan kirim.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      notifyListeners();
    } catch (e) {
      print('Error picking image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> deleteMessage(String messageId, String sessionId) async {
    // Remove from local list
    _messages.removeWhere((message) => message.id == messageId);
    
    // Remove from backend
    await _apiService.deleteMessage(sessionId, messageId);
    
    notifyListeners();
  }

  Future<void> openDeepSeekAI() async {
    const url = 'https://deepseek.ai';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  Future<bool> isSpeaking() async {
    return await _ttsService.isSpeaking();
  }

  @override
  void dispose() {
    print('Disposing ChatProvider');
    _audioService.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}


import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  
  TTSService._internal();
  
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false; // Add flag to track if speaking
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('Initializing TTS service');
      
      await _flutterTts.setLanguage("id-ID");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      // Set event handlers
      _flutterTts.setStartHandler(() {
        print('TTS started speaking');
        _isSpeaking = true; // Set speaking flag to true
      });
      
      _flutterTts.setCompletionHandler(() {
        print('TTS completed speaking');
        _isSpeaking = false; // Set speaking flag to false
      });
      
      _flutterTts.setErrorHandler((error) {
        print('TTS error: $error');
      });
      
      _isInitialized = true;
      print('TTS service initialized successfully');
    } catch (e) {
      print('Error initializing TTS service: $e');
    }
  }
  
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      await stop();
      print('Speaking text: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
      
      await _flutterTts.speak(text);
    } catch (e) {
      print('Error speaking text: $e');
    }
  }
  
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }
  
  Future<void> dispose() async {
    try {
      await stop();
    } catch (e) {
      print('Error disposing TTS: $e');
    }
  }
  
  // Check if TTS is speaking using the custom flag
  Future<bool> isSpeaking() async {
    return _isSpeaking;
  }
}

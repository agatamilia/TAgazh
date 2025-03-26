import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'permission_service.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  String? _recordingPath;

  // Initialize the recorder
  Future<void> initRecorder() async {
    if (!_isRecorderInitialized) {
      print('Initializing audio recorder');
      bool hasPermission = await PermissionService.hasMicrophonePermission();
      
      if (!hasPermission) {
        print('Requesting microphone permission');
        hasPermission = await PermissionService.requestMicrophonePermission();
        if (!hasPermission) {
          print('Microphone permission denied');
          throw Exception('Microphone permission not granted');
        }
      }
      
      print('Opening recorder');
      await _recorder.openRecorder();
      _isRecorderInitialized = true;
      print('Recorder initialized successfully');
    }
  }

  // Initialize the player
  Future<void> initPlayer() async {
    if (!_isPlayerInitialized) {
      print('Initializing audio player');
      await _player.openPlayer();
      _isPlayerInitialized = true;
      print('Player initialized successfully');
    }
  }

  // Start recording
  // Future<void> startRecording() async {
  //   if (!_isRecorderInitialized) {
  //     print('Initializing recorder before starting recording');
  //     await initRecorder();
  //   }
    
  //   print('Getting temporary directory for recording');
  //   Directory tempDir = await getTemporaryDirectory();
  //   _recordingPath = '${tempDir.path}/recording.wav';
    
  //   print('Starting recording to: $_recordingPath');
  //   await _recorder.startRecorder(
  //     toFile: _recordingPath,
  //     codec: Codec.pcm16WAV,
  //   );
  //   print('Recording started');
  // }
Future<void> startRecording() async {
  if (!_isRecorderInitialized) {
    await initRecorder();
  }
  
  Directory tempDir = await getTemporaryDirectory();
  _recordingPath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
  
  await _recorder.startRecorder(
    toFile: _recordingPath,
    codec: Codec.pcm16WAV,
    sampleRate: 16000, // Whisper prefers 16kHz sample rate
    numChannels: 1, // Mono audio
    bitRate: 256000, // Higher quality
  );
}
  // Stop recording
  Future<String?> stopRecording() async {
    if (_recorder.isRecording) {
      print('Stopping recording');
      await _recorder.stopRecorder();
      print('Recording stopped, file saved at: $_recordingPath');
      return _recordingPath;
    }
    print('Not recording, nothing to stop');
    return null;
  }

  // Check if currently recording
  bool isRecording() {
    return _recorder.isRecording;
  }

  // Play recorded audio
  Future<void> playRecording() async {
    if (!_isPlayerInitialized) {
      print('Initializing player before playback');
      await initPlayer();
    }
    
    if (_recordingPath != null) {
      print('Playing recording from: $_recordingPath');
      await _player.startPlayer(
        fromURI: _recordingPath,
        codec: Codec.pcm16WAV,
      );
      print('Playback started');
    } else {
      print('No recording to play');
    }
  }

  // Stop playing
  Future<void> stopPlaying() async {
    if (_player.isPlaying) {
      print('Stopping playback');
      await _player.stopPlayer();
      print('Playback stopped');
    }
  }

  // Get recording file
  File? getRecordingFile() {
    if (_recordingPath != null) {
      print('Getting recording file: $_recordingPath');
      return File(_recordingPath!);
    }
    print('No recording file available');
    return null;
  }

  // Dispose resources
  Future<void> dispose() async {
    print('Disposing audio resources');
    if (_isRecorderInitialized) {
      await _recorder.closeRecorder();
      _isRecorderInitialized = false;
      print('Recorder disposed');
    }
    
    if (_isPlayerInitialized) {
      await _player.closePlayer();
      _isPlayerInitialized = false;
      print('Player disposed');
    }
    print('Audio resources disposed');
  }
}


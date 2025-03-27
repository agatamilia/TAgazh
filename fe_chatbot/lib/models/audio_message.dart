// // models/audio_message.dart
// class AudioMessage {
//   final String id;
//   final String filePath;
//   final String transcription;
//   final DateTime createdAt;

//   AudioMessage({
//     String? id,
    
//     required this.filePath,
//     this.transcription = '',
//     DateTime? createdAt,
//   }) : 
//     id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
//     createdAt = createdAt ?? DateTime.now();
// }
class AudioMessage {
  final String id;
  final String filePath;
  final String transcription;
  final DateTime createdAt;

  AudioMessage({
    required this.id,
    required this.filePath,
    required this.transcription,
    required this.createdAt,
  });
}
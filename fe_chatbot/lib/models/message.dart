enum MessageRole { user, assistant }

class ChatMessage {
  final String id;
  final String content;
  final MessageRole role;
  final String cleanContent;
  final DateTime timestamp;
  final String? imageUrl;
  final bool isAudio;
  final String? audioPath;  
  final bool isError; 

  ChatMessage({
    required this.content,
    required this.role,
    String? id,
    DateTime? timestamp,
    String? cleanContent,
    this.imageUrl,
    this.isAudio = false,
    this.audioPath,         // Add to constructor
    this.isError = false, // Default to false for text messages
  }) : 
    id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    cleanContent = cleanContent ?? _removeFormatting(content),
    timestamp = timestamp ?? DateTime.now();
    static String _removeFormatting(String text) {
      return text.replaceAll('*', '');
    }
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: map['content'],
      role: map['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      timestamp: DateTime.parse(map['timestamp']),
      imageUrl: map['image_url'],
      isAudio: map['is_audio'] ?? false, // Handle potential null value
    );
  }

  Map<String, dynamic> toApiMap(String sessionId) {
    return {
      'id': id,
      'session_id': sessionId,
      'content': content,
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'timestamp': timestamp.toIso8601String(),
      if (imageUrl != null) 'image_url': imageUrl,
      'is_audio': isAudio, // Include audio flag in API payload
    };
  }

  // Added copyWith method
  ChatMessage copyWith({
    String? id,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    String? imageUrl,
    bool? isAudio,
    String? audioPath,      
    bool? isError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      isAudio: isAudio ?? this.isAudio,
      audioPath: audioPath ?? this.audioPath, 
      isError: isError ?? this.isError,
    );
  }
}
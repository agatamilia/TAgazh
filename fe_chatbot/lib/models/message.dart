enum MessageRole { user, assistant }

class ChatMessage {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  String? imageUrl; // For storing image paths

  ChatMessage({
    required this.content,
    required this.role,
    String? id,
    DateTime? timestamp,
    this.imageUrl,
  }) : 
    id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    timestamp = timestamp ?? DateTime.now();
  
  Map<String, dynamic> toMap(String sessionId) {
    return {
      'id': id,
      'session_id': sessionId,
      'content': content,
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'timestamp': timestamp.millisecondsSinceEpoch,
      'image_url': imageUrl,
    };
  }

  static ChatMessage fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      content: map['content'],
      role: map['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      imageUrl: map['image_url'],
    );
  }
}


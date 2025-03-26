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
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: map['content'],
      role: map['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      timestamp: DateTime.parse(map['timestamp']),
      imageUrl: map['image_url'],
    );
  }
  Map<String, dynamic> toApiMap(String sessionId) {
    return {
      'id': id,
      'session_id': sessionId,
      'content': content,
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'timestamp': timestamp.millisecondsSinceEpoch,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

}


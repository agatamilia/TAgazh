import 'dart:io';
import 'package:flutter/material.dart';
import '../models/message.dart';

class ChatMessageItem extends StatelessWidget {
  final ChatMessage message;
  final bool isTyping;

  const ChatMessageItem({
    Key? key,
    required this.message,
    this.isTyping = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          color: isUser 
              ? Theme.of(context).colorScheme.primary 
              : Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isUser 
                            ? Theme.of(context).colorScheme.primaryContainer 
                            : Colors.green[100],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          isUser ? "👨‍🌾" : "🤖",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Message content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          isTyping
                              ? _buildTypingIndicator()
                              : _buildMessageContent(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildMessageContent(BuildContext context) {
  final isUser = message.role == MessageRole.user;
  
  // Check if this is an image message
  if (message.imageUrl != null) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image preview
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(message.imageUrl!),
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: 100,
                color: Colors.grey[300],
                child: const Center(
                  child: Text('Tidak dapat menampilkan gambar'),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Caption - hanya parse bold untuk assistant
        if (!isUser) 
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black),
              children: _parseBoldText(message.content),
            ),
          )
        else
          Text(
            message.content,
            style: const TextStyle(color: Colors.white),
          ),
      ],
    );
  }
  
  // Regular text message - hanya parse bold untuk assistant
  if (!isUser) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black),
        children: _parseBoldText(message.content),
      ),
    );
  }
  
  // Pesan user tetap plain text
  return Text(
    message.content,
    style: const TextStyle(color: Colors.white),
  );
}

List<TextSpan> _parseBoldText(String text) {
  final List<TextSpan> spans = [];
  final parts = text.split('*');

  for (int i = 0; i < parts.length; i++) {
    if (i % 2 == 1) { // Bagian dengan *...* (indeks ganjil)
      spans.add(
        TextSpan(
          text: parts[i],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    } else if (parts[i].isNotEmpty) { // Bagian normal
      spans.add(TextSpan(text: parts[i]));
    }
  }

  // Jika tidak ada tanda *, kembalikan teks biasa
  if (spans.isEmpty) {
    spans.add(TextSpan(text: text));
  }

  return spans;
}
  Widget _buildTypingIndicator() {
    return Row(
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green[300],
              shape: BoxShape.circle,
            ),
            child: const _PulsingDot(),
          ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(),
    );
  }
}

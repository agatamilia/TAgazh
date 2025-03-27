// widgets/audio_message_item.dart
import 'package:flutter/material.dart';
import 'package:peTaniku/models/audio_message.dart';
import 'package:peTaniku/providers/chat_provider.dart';
import 'package:provider/provider.dart';
import '../models/audio_message.dart';

class AudioMessageItem extends StatelessWidget {
  final AudioMessage message;
  final bool isPlaying;
  final VoidCallback onPlayPressed;

  const AudioMessageItem({
    super.key,
    required this.message,
    required this.isPlaying,
    required this.onPlayPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
            onPressed: onPlayPressed,
          ),
          Expanded(
            child: Text(
              message.transcription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
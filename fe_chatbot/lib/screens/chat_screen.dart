import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/chat_provider.dart';
import '../providers/session_provider.dart';
import '../services/permission_service.dart';
import '../widgets/chat_message_item.dart';
import '../widgets/voice_input_overlay.dart';
import '../widgets/weather_widget.dart';
import '../widgets/suggestion_chips.dart';
import '../models/message.dart';
import 'session_list_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    // Check permissions after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
      _loadSessionMessages();
    });
  }

  Future<void> _loadSessionMessages() async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (sessionProvider.currentSession != null) {
      await chatProvider.loadMessages(sessionProvider.currentSession!.id);
    }
  }

  Future<void> _checkPermissions() async {
    if (_permissionsChecked) return;
    
    // Check location permission for weather widget
    bool hasLocationPermission = await PermissionService.hasLocationPermission();
    if (!hasLocationPermission && mounted) {
      bool granted = await PermissionService.requestLocationPermission();
      if (!granted && mounted) {
        await PermissionService.showPermissionDialog(context, 'Lokasi');
      }
    }
    
    // Check microphone permission for voice input
    bool hasMicrophonePermission = await PermissionService.hasMicrophonePermission();
    if (!hasMicrophonePermission && mounted) {
      bool granted = await PermissionService.requestMicrophonePermission();
      if (!granted && mounted) {
        await PermissionService.showPermissionDialog(context, 'Mikrofon');
      }
    }
    
    // Check storage permission for audio files
    bool hasStoragePermission = await PermissionService.hasStoragePermission();
    if (!hasStoragePermission && mounted) {
      bool granted = await PermissionService.requestStoragePermission();
      if (!granted && mounted) {
        await PermissionService.showPermissionDialog(context, 'Penyimpanan');
      }
    }
    
    _permissionsChecked = true;
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmitted(BuildContext context, String text) {
    if (text.isEmpty && !Provider.of<ChatProvider>(context, listen: false).hasImagePending) return;
    
    _textController.clear();
    
    // Send message using provider
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    
    if (sessionProvider.currentSession != null) {
      chatProvider.sendMessage(text, sessionProvider.currentSession!.id, sessionProvider);
    }
    
    _scrollToBottom();
  }

  void _onSuggestionSelected(String suggestion) {
    _textController.text = suggestion;
  }

  Future<void> _openDeepSeekAI() async {
    const url = 'https://deepseek.ai';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  void _showSessionList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SessionListScreen(),
      ),
    );
  }

  Widget _buildVoiceOutputToggle(ChatProvider chatProvider) {
    return Tooltip(
      message: "Aktifkan/nonaktifkan suara untuk jawaban asisten",
      child: Row(
        children: [
          Icon(
            chatProvider.useVoiceOutput ? Icons.volume_up : Icons.volume_off,
            size: 20,
            color: Colors.white,
          ),
          Switch(
            value: chatProvider.useVoiceOutput,
            onChanged: (value) {
              chatProvider.toggleVoiceOutput();
            },
            activeColor: Colors.white,
            activeTrackColor: Colors.green[300],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);
    
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Scroll to bottom when new messages arrive
        if (chatProvider.messages.isNotEmpty) {
          _scrollToBottom();
        }
        
        return Scaffold(
          appBar: AppBar(
            title: Text(sessionProvider.currentSession?.name ?? 'PeTaniku'),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: _showSessionList,
                tooltip: 'Riwayat Chat',
              ),
              _buildVoiceOutputToggle(chatProvider),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Weather widget
                  const WeatherWidget(),
                  
                  // Chat messages
                  Expanded(
                    child: chatProvider.messages.isEmpty
                        ? _buildWelcomeScreen()
                        : _buildChatList(chatProvider, sessionProvider),
                  ),
                  
                  // Input area
                  _buildInputArea(chatProvider, sessionProvider),
                ],
              ),
              
              // Voice input overlay
              if (chatProvider.isListening) 
                VoiceInputOverlay(
                  onCancel: () => chatProvider.cancelListening(),
                  onFinish: () {
                    if (sessionProvider.currentSession != null) {
                      chatProvider.stopListening(sessionProvider.currentSession!.id, sessionProvider);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green[100],
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                "🌾",
                style: TextStyle(fontSize: 48),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Selamat datang di PeTaniku!",
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Tanyakan tentang teknik bertani, cuaca, atau hama tanaman",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(ChatProvider chatProvider, SessionProvider sessionProvider) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: chatProvider.messages.length + (chatProvider.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatProvider.messages.length && chatProvider.isLoading) {
          return ChatMessageItem(
            message: ChatMessage(
              content: "...",
              role: MessageRole.assistant,
            ),
            isTyping: true,
          );
        }
        
        final message = chatProvider.messages[index];
        
        // Check if this is a non-farming related response with DeepSeek link
        if (message.role == MessageRole.assistant && 
            message.content.contains("https://deepseek.ai")) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Dismissible(
                key: Key(message.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Hapus Pesan'),
                        content: const Text('Apakah Anda yakin ingin menghapus pesan ini?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Hapus'),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) {
                  if (sessionProvider.currentSession != null) {
                    chatProvider.deleteMessage(message.id, sessionProvider.currentSession!.id);
                  }
                },
                child: ChatMessageItem(message: message),
              ),
              if (message.content.contains("https://deepseek.ai"))
                Padding(
                  padding: const EdgeInsets.only(left: 56, top: 8),
                  child: ElevatedButton(
                    onPressed: _openDeepSeekAI,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Buka DeepSeek AI"),
                  ),
                ),
            ],
          );
        }
        
        return Dismissible(
          key: Key(message.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Hapus Pesan'),
                  content: const Text('Apakah Anda yakin ingin menghapus pesan ini?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Hapus'),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) {
            if (sessionProvider.currentSession != null) {
              chatProvider.deleteMessage(message.id, sessionProvider.currentSession!.id);
            }
          },
          child: ChatMessageItem(message: message),
        );
      },
    );
  }

  Widget _buildInputArea(ChatProvider chatProvider, SessionProvider sessionProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Text input and buttons
          Row(
            children: [
              // Voice input button
              FloatingActionButton(
                onPressed: chatProvider.isLoading 
                    ? null 
                    : chatProvider.isListening 
                        ? () => chatProvider.stopListening(sessionProvider.currentSession?.id ?? '', sessionProvider) 
                        : () => chatProvider.startListening(context),
                mini: true,
                backgroundColor: chatProvider.isListening 
                    ? Colors.red 
                    : Theme.of(context).colorScheme.primary,
                child: Icon(
                  chatProvider.isListening ? Icons.mic_off : Icons.mic,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              
              // Text input field
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: chatProvider.hasImagePending 
                        ? "Ketik pertanyaan tentang gambar ini..." 
                        : "Tanyakan sesuatu tentang pertanian...",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: chatProvider.isLoading 
                          ? null 
                          : () => chatProvider.pickImage(context),
                    ),
                  ),
                  enabled: !chatProvider.isListening && !chatProvider.isLoading,
                  onSubmitted: (text) => _handleSubmitted(context, text),
                ),
              ),
              const SizedBox(width: 8),
              
              // Send button
              FloatingActionButton(
                onPressed: chatProvider.isLoading 
                    ? null 
                    : () => _handleSubmitted(context, _textController.text),
                mini: true,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          
          // Suggestion chips
          const SizedBox(height: 12),
          SuggestionChips(
            onSuggestionSelected: _onSuggestionSelected,
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../models/chat_session.dart';
import 'chat_screen.dart';
import 'package:intl/intl.dart';

class SessionListScreen extends StatelessWidget {
  const SessionListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PeTaniku'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createNewSession(context),
          ),
        ],
      ),
      body: Consumer<SessionProvider>(
        builder: (context, sessionProvider, child) {
          if (sessionProvider.sessions.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          return ListView.builder(
            itemCount: sessionProvider.sessions.length,
            itemBuilder: (context, index) {
              final session = sessionProvider.sessions[index];
              return _buildSessionItem(context, session);
            },
          );
        },
      ),
    );
  }
  
  Widget _buildSessionItem(BuildContext context, ChatSession session) {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    
    return Dismissible(
      key: Key(session.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Hapus Percakapan'),
              content: const Text('Apakah Anda yakin ingin menghapus percakapan ini?'),
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
        sessionProvider.deleteSession(session);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Percakapan "${session.name}" telah dihapus')),
        );
      },
      child: ListTile(
        title: Text(session.name),
        subtitle: Text(dateFormat.format(session.updatedAt)),
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.chat, color: Colors.white),
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              child: Text('Ubah Nama'),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Text('Hapus Pesan'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Hapus Percakapan'),
            ),
          ],
          onSelected: (value) async {
            if (value == 'rename') {
              _renameSession(context, session);
            } else if (value == 'clear') {
              _clearSessionMessages(context, session);
            } else if (value == 'delete') {
              _deleteSession(context, session);
            }
          },
        ),
        onTap: () {
          sessionProvider.setCurrentSession(session);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChatScreen(),
            ),
          );
        },
      ),
    );
  }
  
  void _createNewSession(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final TextEditingController controller = TextEditingController(text: 'Percakapan Baru');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Percakapan Baru'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Masukkan nama percakapan',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  sessionProvider.createSession(controller.text);
                  Navigator.of(context).pop();
                  
                  // Navigate to the chat screen with the new session
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatScreen(),
                    ),
                  );
                }
              },
              child: const Text('Buat'),
            ),
          ],
        );
      },
    );
  }
  
  void _renameSession(BuildContext context, ChatSession session) {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final TextEditingController controller = TextEditingController(text: session.name);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ubah Nama Percakapan'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Masukkan nama baru',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  sessionProvider.renameSession(session, controller.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
  
  void _clearSessionMessages(BuildContext context, ChatSession session) {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Pesan'),
          content: const Text('Apakah Anda yakin ingin menghapus semua pesan dalam percakapan ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                sessionProvider.clearSessionMessages(session);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Semua pesan telah dihapus')),
                );
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }
  
  void _deleteSession(BuildContext context, ChatSession session) {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Percakapan'),
          content: const Text('Apakah Anda yakin ingin menghapus percakapan ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                sessionProvider.deleteSession(session);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Percakapan "${session.name}" telah dihapus')),
                );
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }
}


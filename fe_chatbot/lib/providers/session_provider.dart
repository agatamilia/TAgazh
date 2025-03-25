import 'package:flutter/foundation.dart';
import '../models/chat_session.dart';
import '../services/api_service.dart';

class SessionProvider with ChangeNotifier {
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  final ApiService _apiService = ApiService();

  List<ChatSession> get sessions => _sessions;
  ChatSession? get currentSession => _currentSession;

  SessionProvider() {
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      _sessions = await _apiService.getSessions();
      
      // Create a new session on app start if no sessions exist
      if (_sessions.isEmpty) {
        await createSession('Chat Baru');
      } else {
        // Use the most recent session
        _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _currentSession = _sessions.first;
      }
      
      notifyListeners();
    } catch (e) {
      print('Error loading sessions: $e');
      // Create a new session if there was an error
      await createSession('Chat Baru');
    }
  }

  Future<void> createSession(String name) async {
    try {
      final session = await _apiService.createSession(name);
      _sessions.insert(0, session);
      _currentSession = session;
      notifyListeners();
    } catch (e) {
      print('Error creating session: $e');
    }
  }

  Future<void> updateSessionName(String sessionId, String newName) async {
    try {
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        _sessions[index].name = newName;
        _sessions[index].updatedAt = DateTime.now();
        await _apiService.updateSession(_sessions[index]);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating session name: $e');
    }
  }

  void setCurrentSession(ChatSession session) {
    _currentSession = session;
    notifyListeners();
  }

  Future<void> renameSession(ChatSession session, String newName) async {
    try {
      final index = _sessions.indexWhere((s) => s.id == session.id);
      if (index != -1) {
        _sessions[index].name = newName;
        _sessions[index].updatedAt = DateTime.now();
        await _apiService.updateSession(_sessions[index]);
        notifyListeners();
      }
    } catch (e) {
      print('Error renaming session: $e');
    }
  }

  Future<void> deleteSession(ChatSession session) async {
    try {
      await _apiService.deleteSession(session.id);
      _sessions.removeWhere((s) => s.id == session.id);
      
      if (_currentSession?.id == session.id) {
        _currentSession = _sessions.isNotEmpty ? _sessions.first : null;
        
        // If we deleted the last session, create a new one
        if (_currentSession == null) {
          await createSession('Chat Baru');
        }
      }
      
      notifyListeners();
    } catch (e) {
      print('Error deleting session: $e');
    }
  }

  Future<void> clearSessionMessages(ChatSession session) async {
    try {
      await _apiService.clearMessages(session.id);
      notifyListeners();
    } catch (e) {
      print('Error clearing session messages: $e');
    }
  }

  // Update session's updatedAt timestamp
  Future<void> updateSessionTimestamp(String sessionId) async {
    try {
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        _sessions[index].updatedAt = DateTime.now();
        await _apiService.updateSession(_sessions[index]);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating session timestamp: $e');
    }
  }
}

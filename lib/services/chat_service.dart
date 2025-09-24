import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roomie/models/message_model.dart';
import 'package:roomie/models/chat_model.dart';
import 'package:roomie/services/auth_service.dart';

class ChatService {
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://roomie-cfc03-default-rtdb.firebaseio.com/',
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  /// Create a new chat between two users
  Future<String> createOrGetChat({
    required String otherUserId,
    required String otherUserName,
    String? otherUserImageUrl,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Create a consistent chat ID based on user IDs (sorted)
      final participants = [currentUser.uid, otherUserId]..sort();
      final chatId = '${participants[0]}_${participants[1]}';

      final chatRef = _database.ref('chats/$chatId');
      final chatSnapshot = await chatRef.get();

      if (!chatSnapshot.exists) {
        // Create new chat
        final chatData = ChatModel(
          id: chatId,
          participants: participants,
          participantNames: {
            currentUser.uid: currentUser.displayName ?? 'You',
            otherUserId: otherUserName,
          },
          participantImages: {
            currentUser.uid: currentUser.photoURL,
            otherUserId: otherUserImageUrl,
          },
          unreadCounts: {
            currentUser.uid: 0,
            otherUserId: 0,
          },
        );

        await chatRef.set(chatData.toMap());
        debugPrint('Created new chat: $chatId');
      }

      return chatId;
    } catch (e) {
      debugPrint('Error creating/getting chat: $e');
      rethrow;
    }
  }

  /// Send a message
  Future<void> sendMessage({
    required String chatId,
    required String message,
    MessageType type = MessageType.text,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final messageId = _database.ref('chats/$chatId/messages').push().key!;
      final messageData = MessageModel(
        id: messageId,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? 'Unknown',
        senderImageUrl: currentUser.photoURL,
        receiverId: '', // Will be determined from chat participants
        message: message,
        timestamp: DateTime.now(),
        type: type,
      );

      // Add message to messages in Realtime Database
      final messageRef = _database.ref('chats/$chatId/messages/$messageId');
      await messageRef.set(messageData.toMap());

      // Update chat's last message and unread counts
      final chatRef = _database.ref('chats/$chatId');
      final chatSnapshot = await chatRef.get();
      
      if (chatSnapshot.exists) {
        final chatData = ChatModel.fromMap(
          Map<String, dynamic>.from(chatSnapshot.value as Map), 
          chatId
        );
        final otherParticipant = chatData.participants
            .firstWhere((id) => id != currentUser.uid, orElse: () => '');

        final updatedUnreadCounts = Map<String, int>.from(chatData.unreadCounts);
        if (otherParticipant.isNotEmpty) {
          updatedUnreadCounts[otherParticipant] = 
              (updatedUnreadCounts[otherParticipant] ?? 0) + 1;
        }

        await chatRef.update({
          'lastMessage': message,
          'lastSenderId': currentUser.uid,
          'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
          'unreadCounts': updatedUnreadCounts,
        });
      }

      debugPrint('Message sent successfully: $messageId');
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Get messages stream for a chat
  Stream<List<MessageModel>> getMessagesStream(String chatId) {
    return _database.ref('chats/$chatId/messages')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <MessageModel>[];

      final messagesMap = Map<String, dynamic>.from(data as Map);
      final messages = messagesMap.entries.map((entry) {
        final messageData = Map<String, dynamic>.from(entry.value as Map);
        return MessageModel.fromMap(messageData, entry.key);
      }).toList();

      // Sort by timestamp descending (newest first)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return messages;
    });
  }

  /// Get user's chats stream
  Stream<List<ChatModel>> getUserChatsStream() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _database.ref('chats')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <ChatModel>[];

      final chatsMap = Map<String, dynamic>.from(data as Map);
      final chats = <ChatModel>[];

      for (final entry in chatsMap.entries) {
        final chatData = Map<String, dynamic>.from(entry.value as Map);
        final chat = ChatModel.fromMap(chatData, entry.key);
        
        // Only include chats where current user is a participant
        if (chat.participants.contains(currentUser.uid)) {
          chats.add(chat);
        }
      }

      // Sort by last message time descending
      chats.sort((a, b) {
        final aTime = a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return chats;
    });
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      final chatRef = _database.ref('chats/$chatId');
      await chatRef.update({
        'unreadCounts/${currentUser.uid}': 0,
      });

      debugPrint('Messages marked as read for chat: $chatId');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Search for users to start a chat with
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return [];

      final usersQuery = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      return usersQuery.docs
          .where((doc) => doc.id != currentUser.uid) // Exclude current user
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }
}
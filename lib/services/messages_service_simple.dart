import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagesServiceSimple {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtimeDB = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all conversations for the current user
  Future<List<Map<String, dynamic>>> getAllConversations() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user');
      return [];
    }

    print('🔄 Loading conversations for user: ${user.uid}');
    
    try {
      final conversations = <Map<String, dynamic>>[];

      // Get all groups from Firestore
      final groupsSnapshot = await _firestore.collection('groups').get();
      print('📊 Found ${groupsSnapshot.docs.length} groups in database');

      for (final groupDoc in groupsSnapshot.docs) {
        final groupData = groupDoc.data();
        final groupId = groupDoc.id;
        final members = List<String>.from(groupData['members'] ?? []);

        print('👥 Checking group: ${groupData['name']} (ID: $groupId)');
        
        // Include if user is a member OR user has messages in this group
        bool shouldInclude = members.contains(user.uid);

        // Check for user messages in Realtime Database
        if (!shouldInclude) {
          final messagesRef = _realtimeDB.ref('groupChats/$groupId/messages');
          final messagesSnapshot = await messagesRef.get();
          
          if (messagesSnapshot.exists) {
            final messages = Map<String, dynamic>.from(messagesSnapshot.value as Map);
            for (final msgEntry in messages.entries) {
              final message = Map<String, dynamic>.from(msgEntry.value);
              if (message['senderId'] == user.uid) {
                shouldInclude = true;
                print('✅ Found user messages in this group');
                break;
              }
            }
          }
        }

        if (shouldInclude) {
          // Get the latest message
          String lastMessage = 'Start chatting...';
          DateTime lastMessageTime = (groupData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          
          final messagesRef = _realtimeDB.ref('groupChats/$groupId/messages');
          final lastMessageSnapshot = await messagesRef.orderByChild('timestamp').limitToLast(1).get();
          
          if (lastMessageSnapshot.exists) {
            final messages = Map<String, dynamic>.from(lastMessageSnapshot.value as Map);
            if (messages.isNotEmpty) {
              final latestMessage = messages.values.last;
              lastMessage = latestMessage['message'] ?? 'Message';
              lastMessageTime = DateTime.fromMillisecondsSinceEpoch(
                latestMessage['timestamp'] as int
              );
            }
          }

          conversations.add({
            'id': groupId,
            'name': groupData['name'] ?? 'Group Chat',
            'type': 'group',
            'imageUrl': groupData['imageUrl'],
            'lastMessage': lastMessage,
            'lastMessageTime': lastMessageTime,
            'unreadCount': 0,
            'memberCount': members.length,
            'groupData': groupData,
          });

          print('✅ Added conversation: ${groupData['name']}');
        }
      }

      // Sort by last message time (most recent first)
      conversations.sort((a, b) {
        final aTime = a['lastMessageTime'] as DateTime;
        final bTime = b['lastMessageTime'] as DateTime;
        return bTime.compareTo(aTime);
      });

      print('🎉 Returning ${conversations.length} total conversations');
      return conversations;

    } catch (e, stackTrace) {
      print('❌ Error loading conversations: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Stream version for real-time updates
  Stream<List<Map<String, dynamic>>> getConversationsStream() {
    return Stream.periodic(Duration(seconds: 3))
        .asyncMap((_) => getAllConversations());
  }
}
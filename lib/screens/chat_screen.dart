import 'package:flutter/material.dart';
import 'package:roomie/services/auth_service.dart';
import 'package:roomie/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> chatData;
  final String chatType; // 'group' or 'individual'

  const ChatScreen({
    super.key,
    required this.chatData,
    required this.chatType,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  bool _isInitialized = false;
  String? _chatId;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    if (_isInitialized) return;
    
    print('🔄 Initializing chat: type=${widget.chatType}');
    print('📋 Chat data: ${widget.chatData}');
    
    try {
      if (widget.chatType == 'group') {
        // Initialize group chat
        final groupId = widget.chatData['id'];
        final groupName = widget.chatData['name'] ?? 'Group Chat';
        final members = List<String>.from(widget.chatData['members'] ?? []);
        
        print('👥 Group chat - ID: $groupId, Name: $groupName, Members: $members');
        
        // Create member names map
        final memberNames = <String, String>{};
        for (String memberId in members) {
          memberNames[memberId] = 'Member'; // You can enhance this to fetch actual names
        }
        
        await _chatService.createOrGetGroupChat(
          groupId: groupId,
          groupName: groupName,
          memberIds: members,
          memberNames: memberNames,
        );
        _chatId = groupId;
        print('✅ Group chat initialized: $_chatId');
      } else {
        // Initialize individual chat
        final otherUserId = widget.chatData['id'] ?? widget.chatData['userId'];
        final otherUserName = widget.chatData['name'] ?? 'User';
        final otherUserImageUrl = widget.chatData['imageUrl'] ?? widget.chatData['profileImageUrl'];
        
        print('👤 Individual chat - Other user ID: $otherUserId, Name: $otherUserName');
        
        final currentUser = _authService.currentUser;
        if (currentUser != null) {
          _chatId = await _chatService.createOrGetChat(
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserImageUrl: otherUserImageUrl,
          );
          print('✅ Individual chat initialized: $_chatId');
        } else {
          print('❌ Current user is null');
        }
      }
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('❌ Error initializing chat: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _chatId == null) {
      print('❌ Cannot send message: messageText=$messageText, chatId=$_chatId');
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      print('❌ Cannot send message: user not authenticated');
      return;
    }

    print('📤 Sending message: type=${widget.chatType}, chatId=$_chatId, message=$messageText');

    try {
      if (widget.chatType == 'group') {
        await _chatService.sendGroupMessage(
          groupId: _chatId!,
          message: messageText,
        );
        print('✅ Group message sent successfully');
      } else {
        await _chatService.sendMessage(
          chatId: _chatId!,
          message: messageText,
        );
        print('✅ Individual message sent successfully');
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('❌ Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  void _showChatInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildChatInfoSheet(),
    );
  }

  Widget _buildChatInfoSheet() {
    if (widget.chatType == 'group') {
      return _buildGroupInfoSheet();
    } else {
      return _buildPersonInfoSheet();
    }
  }

  Widget _buildGroupInfoSheet() {
    final group = widget.chatData;
    final members = List<String>.from(group['members'] ?? []);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF007AFF),
                backgroundImage: group['imageUrl'] != null 
                    ? NetworkImage(group['imageUrl']) 
                    : null,
                child: group['imageUrl'] == null
                    ? Text(
                        (group['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'G',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group['name'] ?? 'Group',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF121417),
                      ),
                    ),
                    Text(
                      '${members.length} members',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF677583),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (group['description'] != null && group['description'].isNotEmpty) ...[
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF121417),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              group['description'],
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF677583),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Text(
            'Group Info',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF121417),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.people, 'Members', '${members.length}'),
          _buildInfoRow(Icons.calendar_today, 'Created', 
              group['createdAt'] != null 
                  ? _formatDate(DateTime.fromMillisecondsSinceEpoch(group['createdAt']))
                  : 'Unknown'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPersonInfoSheet() {
    final person = widget.chatData;
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF007AFF),
                backgroundImage: person['profileImageUrl'] != null 
                    ? NetworkImage(person['profileImageUrl']) 
                    : null,
                child: person['profileImageUrl'] == null
                    ? Text(
                        (person['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person['name'] ?? 'User',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF121417),
                      ),
                    ),
                    if (person['email'] != null) ...[
                      Text(
                        person['email'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF677583),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Contact Info',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF121417),
            ),
          ),
          const SizedBox(height: 12),
          if (person['phone'] != null) 
            _buildInfoRow(Icons.phone, 'Phone', person['phone']),
          if (person['email'] != null) 
            _buildInfoRow(Icons.email, 'Email', person['email']),
          _buildInfoRow(Icons.calendar_today, 'Joined', 
              person['createdAt'] != null 
                  ? _formatDate(DateTime.fromMillisecondsSinceEpoch(person['createdAt']))
                  : 'Unknown'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF677583),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF121417),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF677583),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    Widget? leadingAvatar;

    if (widget.chatType == 'group') {
      title = widget.chatData['name'] ?? 'Group Chat';
      subtitle = '${widget.chatData['memberCount'] ?? 0} members';
      leadingAvatar = CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFF007AFF),
        backgroundImage: widget.chatData['imageUrl'] != null 
            ? NetworkImage(widget.chatData['imageUrl']) 
            : null,
        child: widget.chatData['imageUrl'] == null
            ? Text(
                (widget.chatData['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'G',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      );
    } else {
      title = widget.chatData['name'] ?? 'Chat';
      subtitle = widget.chatData['email'] ?? 'User';
      leadingAvatar = CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFF007AFF),
        backgroundImage: widget.chatData['profileImageUrl'] != null 
            ? NetworkImage(widget.chatData['profileImageUrl']) 
            : null,
        child: widget.chatData['profileImageUrl'] == null
            ? Text(
                (widget.chatData['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back,
                color: Color(0xFF121417),
              ),
            ),
          ],
        ),
        leadingWidth: 56,
        title: Row(
          children: [
            leadingAvatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF121417),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF677583),
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showChatInfo,
            icon: const Icon(
              Icons.info_outline,
              color: Color(0xFF121417),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _isInitialized && _chatId != null
                  ? (widget.chatType == 'group'
                      ? _chatService.getGroupMessagesStream(_chatId!)
                      : _chatService.getMessagesStream(_chatId!).map((messages) => 
                          messages.map((msg) => {
                            'senderId': msg.senderId,
                            'senderName': msg.senderName,
                            'message': msg.message,
                            'timestamp': msg.timestamp.millisecondsSinceEpoch,
                            'isSystemMessage': false,
                          }).toList()))
                  : Stream.value([]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting || !_isInitialized) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Error loading messages',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF677583),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.chatType == 'group' 
                              ? Icons.group_outlined 
                              : Icons.chat_bubble_outline,
                          size: 48,
                          color: const Color(0xFF677583),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.chatType == 'group' 
                              ? 'No messages in group yet'
                              : 'No messages yet',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF121417),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF677583),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Auto-scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index];
                    return _buildMessageBubble(messageData);
                  },
                );
              },
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Color(0xFFE5E5EA),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            color: Color(0xFF677583),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF121417),
                        ),
                        maxLines: 4,
                        minLines: 1,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF007AFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData) {
    final currentUser = _authService.currentUser;
    final isMyMessage = messageData['senderId'] == currentUser?.uid;
    final isSystemMessage = messageData['isSystemMessage'] == true;
    final timestamp = messageData['timestamp'] as int?;
    final timeString = timestamp != null
        ? _formatTime(DateTime.fromMillisecondsSinceEpoch(timestamp))
        : '';

    // System messages (like welcome messages)
    if (isSystemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              messageData['message'] ?? '',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF677583),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF007AFF),
              child: Text(
                (messageData['senderName'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isMyMessage
                    ? const Color(0xFF007AFF)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMyMessage ? 18 : 4),
                  bottomRight: Radius.circular(isMyMessage ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMyMessage && widget.chatType == 'group') ...[
                    Text(
                      messageData['senderName'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    messageData['message'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: isMyMessage ? Colors.white : const Color(0xFF121417),
                      height: 1.3,
                    ),
                  ),
                  if (timeString.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeString,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMyMessage
                            ? Colors.white.withValues(alpha: 0.7)
                            : const Color(0xFF677583),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMyMessage) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF34C759),
              child: Text(
                (messageData['senderName'] as String?)?.substring(0, 1).toUpperCase() ?? 'M',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
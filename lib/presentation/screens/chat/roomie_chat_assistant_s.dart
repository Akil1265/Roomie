import 'package:flutter/material.dart';
import 'package:roomie/data/datasources/gemini_service.dart';
import 'package:roomie/data/datasources/auth_service.dart';

class RoomieChatAssistantScreen extends StatefulWidget {
  final bool isModal;
  const RoomieChatAssistantScreen({super.key, this.isModal = false});

  @override
  State<RoomieChatAssistantScreen> createState() => _RoomieChatAssistantScreenState();
}

class _RoomieChatAssistantScreenState extends State<RoomieChatAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  final AuthService _authService = AuthService();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message from Gemini
    _messages.add({
      'senderId': 'assistant',
      'senderName': 'Roomie Assistant',
      'message': _geminiService.getWelcomeMessage(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isSystemMessage': false,
    });
  }

  // Formats timestamps similar to main chat screen (relative simple format)
  String _formatTime(int? epoch) {
    if (epoch == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epoch);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    final currentUser = _authService.currentUser;
    
    setState(() {
      _messages.add({
        'senderId': currentUser?.uid ?? 'user',
        'senderName': currentUser?.displayName ?? 'You',
        'message': userMessage,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isSystemMessage': false,
      });
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Get response from Gemini AI
      final response = await _geminiService.sendMessage(userMessage);
      
      if (mounted) {
        setState(() {
          _messages.add({
            'senderId': 'assistant',
            'senderName': 'Roomie Assistant',
            'message': response,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'isSystemMessage': false,
          });
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'senderId': 'assistant',
            'senderName': 'Roomie Assistant',
            'message': '😅 Sorry, I encountered an error. Please try again!',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'isSystemMessage': false,
          });
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isModal) {
      // Modal version without Scaffold
      return Column(
        children: [
          // Modal header with drag handle
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF4285F4),
                      child: Icon(Icons.support_agent, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Roomie Assistant',
                            style: TextStyle(
                              color: Color(0xFF121417),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Powered by Gemini AI',
                            style: TextStyle(
                              color: Color(0xFF677583),
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (String value) {
                        if (value == 'clear') {
                          setState(() {
                            _messages.clear();
                            _messages.add({
                              'senderId': 'assistant',
                              'senderName': 'Roomie Assistant',
                              'message': _geminiService.getWelcomeMessage(),
                              'timestamp': DateTime.now().millisecondsSinceEpoch,
                              'isSystemMessage': false,
                            });
                          });
                          _geminiService.resetChat();
                        } else if (value == 'info') {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('About Roomie Assistant'),
                              content: const Text(
                                'I\'m your AI-powered roommate assistant, powered by Google Gemini AI! I can help you with expense management, roommate coordination, house organization, and much more.\n\nI provide personalized advice based on real AI understanding of your questions.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Got it!'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'clear',
                          child: Row(
                            children: [
                              Icon(Icons.refresh),
                              SizedBox(width: 8),
                              Text('Clear Chat'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'info',
                          child: Row(
                            children: [
                              Icon(Icons.info_outline),
                              SizedBox(width: 8),
                              Text('About'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Messages List
          Expanded(
            child: Container(
              color: const Color(0xFFF8F9FA),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }
                  
                  final messageData = _messages[index];
                  return _buildMessageBubble(messageData);
                },
              ),
            ),
          ),
          // Message Input
          _buildMessageInput(),
        ],
      );
    }

    // Full screen version with Scaffold
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF121417),
          ),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF4285F4),
              child: Icon(Icons.support_agent, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Roomie Assistant',
                    style: TextStyle(
                      color: Color(0xFF121417),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Powered by Gemini AI',
                    style: TextStyle(
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String value) {
              if (value == 'clear') {
                setState(() {
                  _messages.clear();
                  _messages.add({
                    'senderId': 'assistant',
                    'senderName': 'Roomie Assistant',
                    'message': _geminiService.getWelcomeMessage(),
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                    'isSystemMessage': false,
                  });
                });
                _geminiService.resetChat();
              } else if (value == 'info') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('About Roomie Assistant'),
                    content: const Text(
                      'I\'m your AI-powered roommate assistant, powered by Google Gemini AI! I can help you with expense management, roommate coordination, house organization, and much more.\n\nI provide personalized advice based on real AI understanding of your questions.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it!'),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('About'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                
                final messageData = _messages[index];
                return _buildMessageBubble(messageData);
              },
            ),
          ),
          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData) {
    final currentUser = _authService.currentUser;
    final isUser = messageData['senderId'] != 'assistant' &&
        (messageData['senderId'] == (currentUser?.uid ?? 'user'));
    final message = messageData['message'] as String? ?? '';
    final timestampEpoch = messageData['timestamp'] as int?;
    final timeString = _formatTime(timestampEpoch);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF4285F4),
              child: Icon(Icons.support_agent, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF4285F4) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
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
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.3,
                      color: isUser ? Colors.white : const Color(0xFF121417),
                    ),
                  ),
                  if (timeString.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeString,
                      style: TextStyle(
                        fontSize: 11,
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.7)
                            : const Color(0xFF677583),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF34C759),
              child: Text(
                (messageData['senderName'] as String?)?.substring(0, 1).toUpperCase() ?? 'Y',
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

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF4285F4),
            child: Icon(Icons.support_agent, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Assistant is typing',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask me anything about roommate life...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFF4285F4)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                mini: true,
                onPressed: _sendMessage,
                backgroundColor: const Color(0xFF4285F4),
                child: const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Powered by Google Gemini AI',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
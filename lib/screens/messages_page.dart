import 'package:flutter/material.dart';
import 'package:roomie/services/messages_service_simple.dart';
import 'package:roomie/screens/chat_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final MessagesServiceSimple _messagesService = MessagesServiceSimple();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, groups, individual
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('📱 MessagesPage: Loading conversations...');
      final conversations = await _messagesService.getAllConversations();
      print('📱 MessagesPage: Got ${conversations.length} conversations');
      
      // Debug print conversation details
      for (final conv in conversations) {
        print('📱 Conversation: ${conv['name']} (${conv['type']}) - Last: ${conv['lastMessage']}');
      }
      
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
        print('📱 MessagesPage: Updated UI with ${_conversations.length} conversations');
      }
    } catch (e) {
      print('❌ MessagesPage: Error loading conversations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }
  
  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  List<Map<String, dynamic>> get _filteredConversations {
    List<Map<String, dynamic>> filtered = [];
    
    // First, filter by type
    switch (_selectedFilter) {
      case 'groups':
        filtered = _conversations.where((conv) => conv['type'] == 'group').toList();
        break;
      case 'individual':
        filtered = _conversations.where((conv) => conv['type'] == 'individual').toList();
        break;
      case 'all':
      default:
        filtered = List.from(_conversations);
    }
    
    // Then, filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((conv) {
        final name = (conv['name'] ?? '').toString().toLowerCase();
        final lastMessage = (conv['lastMessage'] ?? '').toString().toLowerCase();
        return name.contains(query) || lastMessage.contains(query);
      }).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Custom App Bar
          Container(
            color: Colors.white,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and search bar
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isSearching
                          ? Row(
                              key: const ValueKey('search'),
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: _onSearchChanged,
                                      autofocus: true,
                                      decoration: const InputDecoration(
                                        hintText: 'Search conversations...',
                                        hintStyle: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search,
                                          color: Colors.grey,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: _toggleSearch,
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Color(0xFF007AFF),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('title'),
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Messages',
                                  style: TextStyle(
                                    color: Color(0xFF121417),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    // Refresh button
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        onPressed: _loadConversations,
                                        icon: const Icon(
                                          Icons.refresh,
                                          color: Color(0xFF121417),
                                          size: 20,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Search button
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        onPressed: _toggleSearch,
                                        icon: const Icon(
                                          Icons.search,
                                          color: Color(0xFF121417),
                                          size: 20,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    // Filter tabs (only show when not searching)
                    if (!_isSearching) _buildFilterTabs(),
                  ],
                ),
              ),
            ),
          ),
          // Conversations List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredConversations.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadConversations,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100), // Space for tab navigation
                          itemCount: _filteredConversations.length,
                          itemBuilder: (context, index) {
                            final conversation = _filteredConversations[index];
                            return _buildConversationTile(conversation);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Row(
      children: [
        _buildFilterChip('All', 'all'),
        const SizedBox(width: 8),
        _buildFilterChip('Groups', 'groups'),
        const SizedBox(width: 8),
        _buildFilterChip('Direct', 'individual'),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
        print('🔍 Filter changed to: $value');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF007AFF) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF677583),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    if (_isSearching && _searchQuery.isNotEmpty) {
      message = 'No conversations found matching "$_searchQuery"';
    } else {
      switch (_selectedFilter) {
        case 'groups':
          message = 'No group conversations found';
          break;
        case 'individual':
          message = 'No direct conversations found';
          break;
        default:
          message = 'No conversations\nStart chatting by joining a group or messaging someone';
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _isSearching && _searchQuery.isNotEmpty
                    ? Icons.search_off
                    : Icons.chat_bubble_outline,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching && _searchQuery.isNotEmpty
                  ? 'No results found'
                  : 'No conversations',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF121417),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF677583),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final isGroup = conversation['type'] == 'group';
    final name = conversation['name'] ?? 'Unknown';
    final lastMessage = conversation['lastMessage'] ?? 'No messages yet';
    final imageUrl = conversation['imageUrl'];
    final unreadCount = conversation['unreadCount'] ?? 0;
    final lastMessageTime = conversation['lastMessageTime'];

    // Format time
    String timeText = '';
    if (lastMessageTime != null) {
      try {
        final dateTime = lastMessageTime is DateTime
            ? lastMessageTime
            : DateTime.fromMillisecondsSinceEpoch(lastMessageTime as int);
        timeText = timeago.format(dateTime);
      } catch (e) {
        timeText = '';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          // Navigate to chat
          if (isGroup) {
            // Navigate to group chat
            print('Navigate to group chat: ${conversation['id']}');
          } else {
            // Navigate to individual chat
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatData: conversation,
                  chatType: 'individual',
                ),
              ),
            );
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: _buildAvatar(imageUrl, isGroup),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF121417),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (timeText.isNotEmpty)
              Text(
                timeText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF677583),
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                lastMessage,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF677583),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
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
      ),
    );
  }

  Widget _buildAvatar(String? imageUrl, bool isGroup) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: isGroup ? const Color(0xFF007AFF).withValues(alpha: 0.1) : Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    isGroup ? Icons.group : Icons.person,
                    color: isGroup ? const Color(0xFF007AFF) : Colors.grey[600],
                    size: 24,
                  );
                },
              )
            : Icon(
                isGroup ? Icons.group : Icons.person,
                color: isGroup ? const Color(0xFF007AFF) : Colors.grey[600],
                size: 24,
              ),
      ),
    );
  }
}
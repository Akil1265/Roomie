import 'package:flutter/material.dart';
import 'package:roomie/presentation/screens/chat/chat_screen.dart';
import 'package:roomie/presentation/screens/chat/group_chat_s.dart';
import 'package:roomie/data/datasources/messages_service.dart';
import 'package:roomie/presentation/widgets/roomie_loading_widget.dart';
import 'package:timeago/timeago.dart' as timeago;

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final MessagesService _messagesService = MessagesService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, groups, individual

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> conversations,
  ) {
    List<Map<String, dynamic>> filtered = [];

    // First, filter by type
    switch (_selectedFilter) {
      case 'groups':
        filtered =
            conversations.where((conv) => conv['type'] == 'group').toList();
        break;
      case 'individual':
        filtered =
            conversations
                .where((conv) => conv['type'] == 'individual')
                .toList();
        break;
      case 'all':
      default:
        filtered = List.from(conversations);
    }

    // Then, filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((conv) {
            final name = (conv['name'] ?? '').toLowerCase();
            final lastMessage = (conv['lastMessage'] ?? '').toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || lastMessage.contains(query);
          }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Header with title
          Container(
            color: colorScheme.surface,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: 20.0,
                  bottom: 16.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Messages',
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),

          // Search bar and Filter tabs on same row
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            child: Row(
              children: [
                // Search bar (left side)
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: '',
                        prefixIcon: Icon(
                          Icons.search,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Filter tabs (right side)
                Row(
                  children: [
                    _buildFilterTab('all', 'All'),
                    const SizedBox(width: 8),
                    _buildFilterTab('groups', 'Groups'),
                    const SizedBox(width: 8),
                    _buildFilterTab('individual', 'Direct'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesService.getAllConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: RoomieLoadingWidget(
                        size: 80,
                        text: 'Loading conversations...',
                        showText: true,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print('❌ Snapshot error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading conversations',
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final conversations = snapshot.data ?? [];
                print('📱 Messages page received ${conversations.length} conversations');
                print('📊 Conversation types: ${conversations.map((c) => c['type']).toList()}');
                
                final filteredConversations = _applyFilters(conversations);
                print('🔍 Filtered to ${filteredConversations.length} conversations (filter: $_selectedFilter)');

                if (filteredConversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation by joining a group!',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredConversations.length,
                  itemBuilder: (context, index) {
                    final conversation = filteredConversations[index];
                    return _buildConversationTile(conversation);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String value, String label) {
    final isSelected = _selectedFilter == value;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
      color: isSelected
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final isGroup = conversation['type'] == 'group';
    final lastMessageTime = conversation['lastMessageTime'] as DateTime?;
    final timeText =
        lastMessageTime != null
            ? timeago.format(lastMessageTime, locale: 'en_short')
            : '';

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor:
              isGroup
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondaryContainer,
          backgroundImage:
              conversation['imageUrl'] != null &&
                      conversation['imageUrl'].isNotEmpty
                  ? NetworkImage(conversation['imageUrl'])
                  : null,
          child:
              conversation['imageUrl'] == null ||
                      conversation['imageUrl'].isEmpty
                  ? Icon(
                    isGroup ? Icons.group : Icons.person,
                    color: isGroup
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSecondaryContainer,
                    size: 20,
                  )
                  : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation['name'] ?? 'Unknown',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (timeText.isNotEmpty)
              Text(
                timeText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              conversation['lastMessage'] ?? 'No messages yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            if (isGroup && conversation['memberCount'] != null) ...[
              const SizedBox(height: 2),
              Text(
                '${conversation['memberCount']} members',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
        onTap: () => _openConversation(conversation),
      ),
    );
  }

  void _openConversation(Map<String, dynamic> conversation) {
    final isGroup = conversation['type'] == 'group';

    if (isGroup) {
      // Navigate to group chat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => GroupChatScreen(
                group: conversation['groupData'] ?? conversation,
              ),
        ),
      );
    } else {
      // Navigate to individual chat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ChatScreen(
                chatData: {
                  'id': conversation['id'],
                  'name': conversation['name'] ?? 'User',
                  'imageUrl': conversation['imageUrl'],
                  'otherUserId': conversation['otherUserId'],
                  'userData': conversation['userData'] ?? {},
                },
                chatType: 'individual',
              ),
        ),
      );
    }
  }
}

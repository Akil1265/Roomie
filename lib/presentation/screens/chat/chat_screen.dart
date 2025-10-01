import 'package:flutter/material.dart';
import 'package:roomie/data/datasources/auth_service.dart';
import 'package:roomie/data/datasources/chat_service.dart';
import 'package:roomie/presentation/widgets/roomie_loading_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roomie/data/datasources/cloudinary_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> chatData;
  final String chatType; // 'group' or 'individual'

  const ChatScreen({super.key, required this.chatData, required this.chatType});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  bool _isInitialized = false;
  String? _chatId;
  bool _isUploadingImage = false;

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

        print(
          '👥 Group chat - ID: $groupId, Name: $groupName, Members: $members',
        );

        // Create member names map
        final memberNames = <String, String>{};
        for (String memberId in members) {
          memberNames[memberId] =
              'Member'; // You can enhance this to fetch actual names
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
        final otherUserId = widget.chatData['otherUserId'] ?? widget.chatData['userId'];
        final otherUserName = widget.chatData['otherUserName'] ?? widget.chatData['name'] ?? 'User';
        final otherUserImageUrl =
            widget.chatData['otherUserImageUrl'] ?? widget.chatData['profileImageUrl'] ?? widget.chatData['imageUrl'];

        print(
          '👤 Individual chat - Other user ID: $otherUserId, Name: $otherUserName',
        );

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

  Future<void> _pickAndSendImage() async {
    if (_chatId == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() => _isUploadingImage = true);

        String? imageUrl;

        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          imageUrl = await _cloudinaryService.uploadBytes(
            bytes: bytes,
            fileName: 'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
            folder: CloudinaryFolder.other,
          );
        } else {
          imageUrl = await _cloudinaryService.uploadFile(
            file: File(image.path),
            folder: CloudinaryFolder.other,
          );
        }

        // Send image URL as message
        if (widget.chatType == 'group') {
          await _chatService.sendGroupMessage(
            groupId: _chatId!,
            message: imageUrl ?? '',
          );
        } else {
          await _chatService.sendMessage(
            chatId: _chatId!,
            message: imageUrl ?? '',
          );
        }

        _scrollToBottom();
      }
    } catch (e) {
      print('❌ Error sending image: $e');
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send image: $e',
              style: TextStyle(color: colorScheme.onError),
            ),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _takePhotoAndSend() async {
    if (_chatId == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() => _isUploadingImage = true);

        String? imageUrl;

        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          imageUrl = await _cloudinaryService.uploadBytes(
            bytes: bytes,
            fileName: 'chat_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
            folder: CloudinaryFolder.other,
          );
        } else {
          imageUrl = await _cloudinaryService.uploadFile(
            file: File(image.path),
            folder: CloudinaryFolder.other,
          );
        }

        // Send image URL as message
        if (widget.chatType == 'group') {
          await _chatService.sendGroupMessage(
            groupId: _chatId!,
            message: imageUrl ?? '',
          );
        } else {
          await _chatService.sendMessage(
            chatId: _chatId!,
            message: imageUrl ?? '',
          );
        }

        _scrollToBottom();
      }
    } catch (e) {
      print('❌ Error taking photo: $e');
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to take photo: $e',
              style: TextStyle(color: colorScheme.onError),
            ),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;
  final indicatorColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.15);

        return Container(
          color: colorScheme.surface,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select Image Source',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Camera option
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _takePhotoAndSend();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.primary),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Camera',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Gallery option
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.secondary),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.photo_library,
                            size: 40,
                            color: colorScheme.secondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Gallery',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
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

    print(
      '📤 Sending message: type=${widget.chatType}, chatId=$_chatId, message=$messageText',
    );

    try {
      if (widget.chatType == 'group') {
        await _chatService.sendGroupMessage(
          groupId: _chatId!,
          message: messageText,
        );
        print('✅ Group message sent successfully');
      } else {
        await _chatService.sendMessage(chatId: _chatId!, message: messageText);
        print('✅ Individual message sent successfully');
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('❌ Error sending message: $e');
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send message: $e',
              style: TextStyle(color: colorScheme.onError),
            ),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
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
    final description = group['description'] as String?;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
  final indicatorColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.12);

    return Container(
      color: colorScheme.surface,
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
                color: indicatorColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage:
                    group['imageUrl'] != null
                        ? NetworkImage(group['imageUrl'])
                        : null,
                child:
                    group['imageUrl'] == null
                        ? Text(
                          (group['name'] as String?)
                                  ?.substring(0, 1)
                                  .toUpperCase() ??
                              'G',
                          style:
                              textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ) ??
                              TextStyle(
                                color: colorScheme.onPrimaryContainer,
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
                      style:
                          textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ) ??
                          TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    Text(
                      '${members.length} members',
                      style:
                          textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ) ??
                          TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (description != null && description.isNotEmpty) ...[
            Text(
              'Description',
              style:
                  textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ) ??
                  TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style:
                  textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ) ??
                  TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'Group Info',
            style:
                textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ) ??
                TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.people, 'Members', '${members.length}'),
          _buildInfoRow(
            Icons.calendar_today,
            'Created',
            group['createdAt'] != null
                ? _formatDate(
                  DateTime.fromMillisecondsSinceEpoch(group['createdAt']),
                )
                : 'Unknown',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPersonInfoSheet() {
    final person = widget.chatData;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
  final indicatorColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.12);

    return Container(
      color: colorScheme.surface,
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
                color: indicatorColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage:
                    person['profileImageUrl'] != null
                        ? NetworkImage(person['profileImageUrl'])
                        : null,
                child:
                    person['profileImageUrl'] == null
                        ? Text(
                          (person['name'] as String?)
                                  ?.substring(0, 1)
                                  .toUpperCase() ??
                              'U',
                          style:
                              textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ) ??
                              TextStyle(
                                color: colorScheme.onPrimaryContainer,
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
                      style:
                          textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ) ??
                          TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    if (person['email'] != null) ...[
                      Text(
                        person['email'],
                        style:
                            textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ) ??
                            TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Contact Info',
            style:
                textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ) ??
                TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 12),
          if (person['phone'] != null)
            _buildInfoRow(Icons.phone, 'Phone', person['phone']),
          if (person['email'] != null)
            _buildInfoRow(Icons.email, 'Email', person['email']),
          _buildInfoRow(
            Icons.calendar_today,
            'Joined',
            person['createdAt'] != null
                ? _formatDate(
                  DateTime.fromMillisecondsSinceEpoch(person['createdAt']),
                )
                : 'Unknown',
          ),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ) ??
                TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ) ??
                TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    String title;
    String subtitle;
    Widget? leadingAvatar;

    if (widget.chatType == 'group') {
      title = widget.chatData['name'] ?? 'Group Chat';
      subtitle = '${widget.chatData['memberCount'] ?? 0} members';
      leadingAvatar = CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage:
            widget.chatData['imageUrl'] != null
                ? NetworkImage(widget.chatData['imageUrl'])
                : null,
        child:
            widget.chatData['imageUrl'] == null
                ? Text(
                  (widget.chatData['name'] as String?)
                          ?.substring(0, 1)
                          .toUpperCase() ??
                      'G',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                )
                : null,
      );
    } else {
      title = widget.chatData['name'] ?? 'Chat';
      subtitle = widget.chatData['email'] ?? 'User';
      final imageUrl = widget.chatData['profileImageUrl'] ?? widget.chatData['imageUrl'];
      leadingAvatar = CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
        child:
            imageUrl == null
                ? Text(
                  (widget.chatData['name'] as String?)
                          ?.substring(0, 1)
                          .toUpperCase() ??
                      'U',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                )
                : null,
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
  surfaceTintColor: colorScheme.surface.withValues(alpha: 0),
        elevation: 1,
  shadowColor: colorScheme.shadow.withValues(alpha: 0),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
        ),
        title: Row(
          children: [
            leadingAvatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
            icon: Icon(Icons.info_outline, color: colorScheme.onSurface),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream:
                  _isInitialized && _chatId != null
                      ? (widget.chatType == 'group'
                          ? _chatService.getGroupMessagesStream(_chatId!)
                          : _chatService
                              .getMessagesStream(_chatId!)
                              .map(
                                (messages) =>
                                    messages
                                        .map(
                                          (msg) => {
                                            'senderId': msg.senderId,
                                            'senderName': msg.senderName,
                                            'message': msg.message,
                                            'timestamp':
                                                msg
                                                    .timestamp
                                                    .millisecondsSinceEpoch,
                                            'isSystemMessage': false,
                                          },
                                        )
                                        .toList(),
                              ))
                      : Stream.value([]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    !_isInitialized) {
                  return const Center(
                    child: RoomieLoadingWidget(
                      size: 60,
                      showText: true,
                      text: 'Loading messages...',
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
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
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.chatType == 'group'
                              ? 'No messages in group yet'
                              : 'No messages yet',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
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
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Camera button
                  Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: IconButton(
                      onPressed: _isUploadingImage ? null : _takePhotoAndSend,
                      icon:
                          _isUploadingImage
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.camera_alt,
                                  color: colorScheme.primary,
                                  size: 22,
                                ),
                    ),
                  ),
                  // Attachment button (gallery + camera options)
                  Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: IconButton(
                      onPressed:
                          _isUploadingImage ? null : _showImageSourceDialog,
                      icon:
                          _isUploadingImage
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.attach_file,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 22,
                                ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
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
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send,
                        color: colorScheme.onPrimary,
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
    final message = messageData['message'] ?? '';
    final timestamp = messageData['timestamp'] as int?;
    final timeString =
        timestamp != null
            ? _formatTime(DateTime.fromMillisecondsSinceEpoch(timestamp))
            : '';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Check if message is an image URL
    final isImage =
        message.startsWith('https://res.cloudinary.com') ||
        message.toLowerCase().contains('.jpg') ||
        message.toLowerCase().contains('.png') ||
        message.toLowerCase().contains('.gif') ||
        message.toLowerCase().contains('.jpeg') ||
        message.toLowerCase().contains('.webp');

    // System messages (like welcome messages)
    if (isSystemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              messageData['message'] ?? '',
              style:
                  textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ) ??
                  TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
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
              backgroundColor: colorScheme.secondaryContainer,
              child: Text(
                (messageData['senderName'] as String?)
                        ?.substring(0, 1)
                        .toUpperCase() ??
                    'U',
                style:
                    textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ) ??
                    TextStyle(
                      color: colorScheme.onSecondaryContainer,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isMyMessage
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMyMessage ? 18 : 4),
                  bottomRight: Radius.circular(isMyMessage ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
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
                      style:
                          textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ) ??
                          TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Display image or text
                  if (isImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        message,
                        fit: BoxFit.cover,
                        width: 200,
                        height: 200,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 200,
                            height: 200,
                            color: colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: RoomieLoadingWidget(
                                size: 50,
                                showText: true,
                                text: 'Setting up chat...',
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: colorScheme.surfaceContainerHighest,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style:
                                      textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ) ??
                                      TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Text(
                      message,
                      style:
                          textTheme.bodyLarge?.copyWith(
                            color:
                                isMyMessage
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                            height: 1.3,
                          ) ??
                          TextStyle(
                            fontSize: 16,
                            color:
                                isMyMessage
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                            height: 1.3,
                          ),
                    ),
                  if (timeString.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeString,
                      style:
                          textTheme.labelSmall?.copyWith(
                            color:
                                isMyMessage
                                    ? colorScheme.onPrimary.withValues(alpha: 0.7)
                                    : colorScheme.onSurfaceVariant,
                          ) ??
                          TextStyle(
                            fontSize: 11,
                            color:
                                isMyMessage
                                    ? colorScheme.onPrimary.withValues(alpha: 0.7)
                                    : colorScheme.onSurfaceVariant,
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
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                (messageData['senderName'] as String?)
                        ?.substring(0, 1)
                        .toUpperCase() ??
                    'M',
                style:
                    textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ) ??
                    TextStyle(
                      color: colorScheme.onPrimaryContainer,
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

// ignore_for_file: unused_element

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// ignore: unused_import
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:roomie/data/datasources/auth_service.dart';
import 'package:roomie/data/datasources/chat_service.dart';
import 'package:roomie/data/models/message_model.dart';
import 'package:roomie/presentation/widgets/roomie_loading_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

// Emoji picker removed per request

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatData,
    required this.chatType,
  });

  final Map<String, dynamic> chatData;
  final String chatType;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _voiceRecorder = AudioRecorder();
  final Uuid _uuid = const Uuid();

  Stream<List<MessageModel>>? _messagesStream;
  bool _initialized = false;
  bool _isGroup = false;
  String? _containerId;
  List<String> _memberIds = [];
  Map<String, String> _memberNames = {};
  Map<String, String?> _memberImages = {};
  MessageModel? _editingMessage;
  bool _isUploading = false;
  // Emoji picker removed
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  DateTime? _lastDeliverySync;
  DateTime? _lastReadSync;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    if (_initialized) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      final data = widget.chatData;
      if (widget.chatType == 'group') {
        _isGroup = true;
        final groupId = data['id'] ?? data['groupId'];
        if (groupId == null) {
          throw Exception('Missing group identifier');
        }

        final groupName = data['name'] ?? data['groupName'] ?? 'Group chat';
        final members = List<String>.from(data['members'] ?? const <String>[]);
        final memberNames = Map<String, String>.from(
          data['memberNames'] ?? const <String, String>{},
        );
        final memberImages = Map<String, String?>.from(
          (data['memberImages'] ?? const <String, dynamic>{}).map(
            (key, value) => MapEntry(key, value?.toString()),
          ),
        );

        if (!members.contains(currentUser.uid)) {
          members.add(currentUser.uid);
        }
        memberNames[currentUser.uid] = currentUser.displayName ?? 'You';

        _memberIds = members;
        _memberNames = memberNames;
        _memberImages = memberImages;

        _containerId = await _chatService.createOrGetGroupChat(
          groupId: groupId,
          groupName: groupName,
          memberIds: members,
          memberNames: memberNames,
        );
        _messagesStream = _chatService.getGroupMessagesStream(_containerId!);
      } else {
        _isGroup = false;
        final otherUserId = data['otherUserId'] ?? data['userId'];
        if (otherUserId == null) {
          throw Exception('Missing user identifier');
        }
        final otherUserName = data['otherUserName'] ?? data['name'] ?? 'User';
        final otherUserImage = data['otherUserImageUrl'] ??
            data['profileImageUrl'] ??
            data['imageUrl'];

        _containerId = await _chatService.createOrGetChat(
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserImageUrl: otherUserImage?.toString(),
        );

        _memberIds = [currentUser.uid, otherUserId];
        _memberNames = {
          currentUser.uid: currentUser.displayName ?? 'You',
          otherUserId: otherUserName,
        };
        _memberImages = {otherUserId: otherUserImage?.toString()};

        _messagesStream = _chatService.getMessagesStream(_containerId!);
      }

      setState(() {
        _initialized = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 150));
      _scrollToBottom();
    } catch (e, stackTrace) {
      debugPrint('Chat init failed: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open chat: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final String title;
    final String subtitle;
    final Widget leadingAvatar;

    if (widget.chatType == 'group') {
      title = widget.chatData['name'] ?? widget.chatData['groupName'] ?? 'Group chat';
      final memberCount = _memberIds.isNotEmpty
          ? _memberIds.length
          : (widget.chatData['memberCount'] as int?) ?? 0;
      subtitle = '$memberCount members';
      final imageUrl = widget.chatData['imageUrl'] ?? widget.chatData['groupImageUrl'];
      leadingAvatar = CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
        child: imageUrl == null
            ? Text(
                title.isNotEmpty ? title.substring(0, 1).toUpperCase() : 'G',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      );
    } else {
      final otherId = _memberIds.firstWhere(
        (id) => id != _authService.currentUser?.uid,
        orElse: () => widget.chatData['otherUserId'] ??
            widget.chatData['userId'] ??
            '',
      );
      title = _memberNames[otherId] ??
          widget.chatData['name'] ??
          widget.chatData['otherUserName'] ??
          'Chat';
      subtitle = widget.chatData['status'] ??
          widget.chatData['email'] ??
          'Online';
      final imageUrl = _memberImages[otherId] ??
          widget.chatData['imageUrl'] ??
          widget.chatData['profileImageUrl'];
      leadingAvatar = CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
        child: imageUrl == null
            ? Text(
                title.isNotEmpty ? title.substring(0, 1).toUpperCase() : 'U',
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
        elevation: 0.5,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
        ),
        titleSpacing: 0,
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
          Expanded(child: _buildMessagesArea()),
          if (_isUploading)
            LinearProgressIndicator(
              minHeight: 2,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessagesArea() {
    if (!_initialized || _messagesStream == null) {
      return const Center(
        child: RoomieLoadingWidget(
          size: 60,
          showText: true,
          text: 'Loading messages...',
        ),
      );
    }

    return StreamBuilder<List<MessageModel>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        if (snapshot.connectionState == ConnectionState.waiting) {
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
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  'Something went wrong',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
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

        final messages = snapshot.data ?? const <MessageModel>[];
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.chatType == 'group'
                      ? Icons.group_outlined
                      : Icons.chat_bubble_outline,
                  size: 52,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.chatType == 'group'
                      ? 'No messages in this group yet'
                      : 'Say hello 👋',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Start the conversation with a message or attachment.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        _syncMessageStates(messages);

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return _buildMessageBubble(message);
          },
        );
      },
    );
  }

  Widget _buildComposer() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = _messageController.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_editingMessage != null) _buildEditingBanner(),
            Row(
              children: [
                // Emoji button removed
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Message',
                      ),
                      onTap: () {
                        // no-op
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isUploading ? null : _showAttachmentSheet,
                  icon: Icon(
                    Icons.attach_file,
                    color: _isUploading
                        // ignore: deprecated_member_use
                        ? colorScheme.onSurfaceVariant.withOpacity(0.4)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (hasText || _editingMessage != null)
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primary,
                    child: IconButton(
                      icon: Icon(Icons.send, color: colorScheme.onPrimary),
                      onPressed: _isUploading ? null : _handleSendPressed,
                    ),
                  )
                else ...[
                  if (_isRecording) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        _formatRecordingDuration(_recordDuration),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel',
                      onPressed: _isUploading
                          ? null
                          : () => _stopRecording(send: false),
                      icon: Icon(Icons.delete_outline,
                          color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.red,
                      child: IconButton(
                        tooltip: 'Send voice',
                        icon: const Icon(Icons.stop, color: Colors.white),
                        onPressed:
                            _isUploading ? null : () => _stopRecording(send: true),
                      ),
                    ),
                  ] else ...[
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colorScheme.primary,
                      child: IconButton(
                        tooltip: 'Voice message',
                        icon: Icon(Icons.mic, color: colorScheme.onPrimary),
                        onPressed: _isUploading ? null : _startRecording,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditingBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final editing = _editingMessage!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.edit, size: 18, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Editing: ${editing.message}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _messageController.clear();
              });
            },
            icon: Icon(Icons.close, size: 18, color: colorScheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }

  // Emoji picker removed

  Future<void> _startRecording() async {
    if (_isRecording) return;
    final hasPerm = await _voiceRecorder.hasPermission();
    if (!hasPerm) {
      _showError('Microphone permission denied.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await _voiceRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      ),
      path: path,
    );
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    String? recordedPath;
    try {
      recordedPath = await _voiceRecorder.stop();
    } catch (e) {
      debugPrint('record stop error: $e');
    }

    final duration = _recordDuration;
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
    });

    if (!send || recordedPath == null) {
      if (recordedPath != null) {
        try { await File(recordedPath).delete(); } catch (_) {}
      }
      return;
    }

    File? file;
    try {
      file = File(recordedPath);
      final bytes = await file.readAsBytes();
      setState(() => _isUploading = true);
      final url = await _chatService.uploadChatFile(
        bytes: bytes,
        fileName: p.basename(recordedPath),
        contentType: 'audio/m4a',
        folder: _isGroup ? 'groups/$_containerId/audio' : 'chats/$_containerId/audio',
      );
      final attachment = MessageAttachment(
        url: url,
        name: 'Voice message',
        type: AttachmentType.voice,
        mimeType: 'audio/m4a',
        size: bytes.lengthInBytes,
        durationInMs: duration.inMilliseconds,
      );
      await _sendRichMessage(
        type: MessageType.voice,
        attachments: [attachment],
      );
    } catch (e) {
      _showError('Failed to send voice message: $e');
    } finally {
      if (file != null) {
        try { await file.delete(); } catch (_) {}
      }
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handleSendPressed() async {
    if (_editingMessage != null) {
      await _applyEdit();
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty || _containerId == null) {
      return;
    }

    await _sendRichMessage(
      text: text,
      type: MessageType.text,
    );
    _messageController.clear();
    setState(() {});
  }

  Future<void> _applyEdit() async {
    final editing = _editingMessage;
    if (editing == null || _containerId == null) return;

    final newText = _messageController.text.trim();
    if (newText.isEmpty || newText == editing.message) {
      setState(() {
        _editingMessage = null;
        _messageController.clear();
      });
      return;
    }

    try {
      if (_isGroup) {
        await _chatService.editGroupMessage(
          groupId: _containerId!,
          messageId: editing.id,
          newText: newText,
        );
      } else {
        await _chatService.editMessage(
          chatId: _containerId!,
          messageId: editing.id,
          newText: newText,
        );
      }
      setState(() {
        _editingMessage = null;
        _messageController.clear();
      });
    } catch (e) {
      _showError('Failed to edit message: $e');
    }
  }

  Future<void> _sendRichMessage({
    required MessageType type,
    String? text,
    List<MessageAttachment> attachments = const [],
    PollData? poll,
    TodoData? todo,
    Map<String, dynamic>? extraData,
  }) async {
    if (_containerId == null) return;

    try {
      if (_isGroup) {
        await _chatService.sendGroupMessage(
          groupId: _containerId!,
          message: text,
          type: type,
          attachments: attachments,
          poll: poll,
          todo: todo,
          extraData: extraData,
        );
      } else {
        await _chatService.sendMessage(
          chatId: _containerId!,
          message: text,
          type: type,
          attachments: attachments,
          poll: poll,
          todo: todo,
          extraData: extraData,
        );
      }
      _scrollToBottom();
    } catch (e) {
      _showError('Failed to send message: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: colorScheme.onError),
        ),
        backgroundColor: colorScheme.error,
      ),
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _syncMessageStates(List<MessageModel> messages) {
    if (_containerId == null || messages.isEmpty) return;

    final now = DateTime.now();
    const debounce = Duration(seconds: 3);

    if (_isGroup) {
      if (_lastReadSync == null || now.difference(_lastReadSync!) > debounce) {
        _chatService.markGroupMessagesAsRead(_containerId!);
        _lastReadSync = now;
      }
      return;
    }

    if (_lastDeliverySync == null || now.difference(_lastDeliverySync!) > debounce) {
      _chatService.markMessagesAsDelivered(_containerId!);
      _lastDeliverySync = now;
    }

    if (_lastReadSync == null || now.difference(_lastReadSync!) > debounce) {
      _chatService.markMessagesAsRead(_containerId!);
      _lastReadSync = now;
    }
  }


  void _showAttachmentSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: colorScheme.onSurfaceVariant.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.insert_drive_file, color: colorScheme.primary),
                  title: Text('Document', style: textTheme.bodyLarge),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendDocument();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: colorScheme.primary),
                  title: Text('Gallery', style: textTheme.bodyLarge),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: colorScheme.primary),
                  title: Text('Camera', style: textTheme.bodyLarge),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.poll, color: colorScheme.primary),
                  title: Text('Create poll', style: textTheme.bodyLarge),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePollSheet();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.checklist, color: colorScheme.primary),
                  title: Text('Create to-do list', style: textTheme.bodyLarge),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateTodoSheet();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_containerId == null) return;

    try {
      final XFile? file = source == ImageSource.camera
          ? await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80)
          : await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);

      if (file == null) return;

      setState(() => _isUploading = true);

      final bytes = await file.readAsBytes();
      final fileName = file.name.isNotEmpty ? file.name : 'image_${_uuid.v4()}.jpg';
      final extension = p.extension(fileName).toLowerCase();
      final contentType = _inferImageContentType(extension);

      final url = await _chatService.uploadChatFile(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
        folder: _isGroup ? 'groups/$_containerId/images' : 'chats/$_containerId/images',
      );

      final attachment = MessageAttachment(
        url: url,
        name: fileName,
        type: AttachmentType.image,
        mimeType: contentType,
        size: bytes.lengthInBytes,
      );

      await _sendRichMessage(
        type: MessageType.image,
        attachments: [attachment],
      );
    } catch (e) {
      _showError('Failed to send image: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickAndSendDocument() async {
    if (_containerId == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      Uint8List? bytes = picked.bytes;
      if (bytes == null && picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes == null) {
        _showError('Unable to read selected file.');
        return;
      }

      setState(() => _isUploading = true);

      final fileName = picked.name.isNotEmpty ? picked.name : 'file_${_uuid.v4()}';
      final extension = p.extension(fileName).toLowerCase();
      final contentType = _inferFileContentType(extension);

      final url = await _chatService.uploadChatFile(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
        folder: _isGroup ? 'groups/$_containerId/files' : 'chats/$_containerId/files',
      );

      final attachment = MessageAttachment(
        url: url,
        name: fileName,
        type: AttachmentType.document,
        mimeType: contentType,
        size: picked.size,
      );

      await _sendRichMessage(
        type: MessageType.file,
        attachments: [attachment],
      );
    } catch (e) {
      _showError('Failed to share file: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showCreatePollSheet() {
    final questionController = TextEditingController();
    final optionControllers = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];
    bool allowMultiple = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final options = optionControllers
                .map((controller) => controller.text.trim())
                .where((text) => text.isNotEmpty)
                .toList();
            final canSubmit =
                questionController.text.trim().isNotEmpty && options.length >= 2;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create poll',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: questionController,
                    decoration: const InputDecoration(
                      labelText: 'Question',
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  for (int i = 0; i < optionControllers.length; i++) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: optionControllers[i],
                            decoration: InputDecoration(
                              labelText: 'Option ${i + 1}',
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        if (optionControllers.length > 2)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setModalState(() {
                                optionControllers.removeAt(i).dispose();
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: optionControllers.length >= 6
                          ? null
                          : () {
                              setModalState(() {
                                optionControllers.add(TextEditingController());
                              });
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Add option'),
                    ),
                  ),
                  SwitchListTile(
                    value: allowMultiple,
                    onChanged: (value) => setModalState(() {
                      allowMultiple = value;
                    }),
                    title: const Text('Allow multiple votes'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: canSubmit
                        ? () {
                            final poll = PollData(
                              question: questionController.text.trim(),
                              allowMultiple: allowMultiple,
                              createdAt: DateTime.now(),
                              options: optionControllers
                                  .map((controller) => controller.text.trim())
                                  .where((text) => text.isNotEmpty)
                                  .map(
                                    (text) => PollOption(
                                      id: _uuid.v4(),
                                      title: text,
                                      votes: {},
                                    ),
                                  )
                                  .toList(),
                            );
                            Navigator.pop(context);
                            _sendRichMessage(
                              type: MessageType.poll,
                              poll: poll,
                            );
                          }
                        : null,
                    child: const Text('Send poll'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      questionController.dispose();
      for (final controller in optionControllers) {
        controller.dispose();
      }
    });
  }

  void _showCreateTodoSheet() {
    final titleController = TextEditingController();
    final itemControllers = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final items = itemControllers
                .map((controller) => controller.text.trim())
                .where((text) => text.isNotEmpty)
                .toList();
            final canSubmit =
                titleController.text.trim().isNotEmpty && items.isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create to-do list',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'List title',
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  for (int i = 0; i < itemControllers.length; i++) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: itemControllers[i],
                            decoration: InputDecoration(
                              labelText: 'Task ${i + 1}',
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        if (itemControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setModalState(() {
                                itemControllers.removeAt(i).dispose();
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: itemControllers.length >= 8
                          ? null
                          : () {
                              setModalState(() {
                                itemControllers.add(TextEditingController());
                              });
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Add task'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: canSubmit
                        ? () {
                            final todo = TodoData(
                              title: titleController.text.trim(),
                              items: itemControllers
                                  .map((controller) => controller.text.trim())
                                  .where((text) => text.isNotEmpty)
                                  .map(
                                    (text) => TodoItem(
                                      id: _uuid.v4(),
                                      title: text,
                                    ),
                                  )
                                  .toList(),
                            );
                            Navigator.pop(context);
                            _sendRichMessage(
                              type: MessageType.todo,
                              todo: todo,
                            );
                          }
                        : null,
                    child: const Text('Send to-do list'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      for (final controller in itemControllers) {
        controller.dispose();
      }
    });
  }

  Widget _buildMessageBubble(MessageModel message) {
    final currentUserId = _authService.currentUser?.uid;
    final isMine = message.senderId == currentUserId;
    final isSystem = message.isSystemMessage || message.type == MessageType.system;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.message,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final bubbleColor = isMine
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final textColor = isMine
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return GestureDetector(
      onLongPress: () => _onMessageLongPress(message, isMine),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 6),
                  bottomRight: Radius.circular(isMine ? 6 : 18),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment:
                      isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (_isGroup && !isMine)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _resolveUserName(message.senderId, fallback: message.senderName),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (message.attachments.isNotEmpty)
                      ...message.attachments.map(
                        (attachment) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildAttachmentPreview(attachment),
                        ),
                      ),
                    if (message.message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.message,
                          style: textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    if (message.poll != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _buildPollWidget(message),
                      ),
                    if (message.todo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _buildTodoWidget(message),
                      ),
                    _buildStatusRow(message, isMine),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(MessageAttachment attachment) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    switch (attachment.type) {
      case AttachmentType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _openImagePreview(attachment.url),
            child: Image.network(
              attachment.url,
              fit: BoxFit.cover,
              width: 220,
              height: 220,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  width: 220,
                  height: 220,
                  child: Center(
                    child: RoomieLoadingWidget(size: 36, showText: false),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      // Voice/audio playback removed; show as generic file link
      case AttachmentType.voice:
      case AttachmentType.audio:
        return InkWell(
          onTap: () => _openExternalLink(attachment.url),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.audiotrack, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    attachment.name.isNotEmpty ? attachment.name : 'Audio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.open_in_new, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      default:
        return InkWell(
          onTap: () => _openExternalLink(attachment.url),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.insert_drive_file, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildPollWidget(MessageModel message) {
    final poll = message.poll!;
    final currentUserId = _authService.currentUser?.uid;
    final totalVotes =
        poll.options.fold<int>(0, (sum, option) => sum + option.votes.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          poll.question,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        ...poll.options.map((option) {
          final hasVoted = currentUserId != null && option.votes.contains(currentUserId);
          final voteCount = option.votes.length;
          final ratio = totalVotes == 0 ? 0.0 : voteCount / totalVotes;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                _chatService.togglePollVote(
                  containerId: _containerId!,
                  messageId: message.id,
                  optionId: option.id,
                  isGroup: _isGroup,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
          color: hasVoted
            // ignore: deprecated_member_use
            ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$voteCount vote${voteCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            totalVotes == 0 ? 'No votes yet' : '$totalVotes total votes',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }

  Widget _buildTodoWidget(MessageModel message) {
    final todo = message.todo!;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          todo.title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        ...todo.items.map(
          (item) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: item.isDone,
            dense: true,
            onChanged: (_) {
              _chatService.updateTodoItem(
                containerId: _containerId!,
                messageId: message.id,
                itemId: item.id,
                isGroup: _isGroup,
              );
            },
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              item.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration: item.isDone ? TextDecoration.lineThrough : null,
                    color: item.isDone
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                  ),
            ),
            secondary: item.isDone && item.completedBy != null
                ? Icon(Icons.check_circle, color: colorScheme.primary)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(MessageModel message, bool isMine) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final timeString = _formatTimestamp(message.timestamp);
    final isEdited = message.editedAt != null;
    final seenCount = _isGroup
        ? message.seenBy.keys.where((id) => id != message.senderId).length
        : 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              'Edited',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Text(
          timeString,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (isMine) ...[
          const SizedBox(width: 4),
          Icon(
            _statusIcon(message.status),
            size: 16,
            color: _statusColor(message.status, colorScheme),
          ),
        ],
        if (_isGroup && seenCount > 0) ...[
          const SizedBox(width: 6),
          Icon(Icons.remove_red_eye, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(
            '$seenCount',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  IconData _statusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
    }
  }

  Color _statusColor(MessageStatus status, ColorScheme colorScheme) {
    switch (status) {
      case MessageStatus.read:
        return colorScheme.primary;
      case MessageStatus.delivered:
        return colorScheme.onSurfaceVariant;
      case MessageStatus.sent:
  return colorScheme.onSurfaceVariant.withOpacity(0.7);
      case MessageStatus.sending:
  return colorScheme.onSurfaceVariant.withOpacity(0.6);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _formatFullDate(DateTime timestamp) {
    final local = timestamp.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final time = _formatTimestamp(timestamp);
    return '$day/$month/$year $time';
  }

  void _onMessageLongPress(MessageModel message, bool isMine) {
    final actions = <_MessageAction>[
      if (message.message.isNotEmpty)
        _MessageAction(
          icon: Icons.copy,
          label: 'Copy text',
          onSelected: () {
            Clipboard.setData(ClipboardData(text: message.message));
            Navigator.pop(context);
          },
        ),
      if (isMine && message.type == MessageType.text)
        _MessageAction(
          icon: Icons.edit,
          label: 'Edit message',
          onSelected: () {
            Navigator.pop(context);
            setState(() {
              _editingMessage = message;
              _messageController.text = message.message;
              _messageController.selection = TextSelection.collapsed(
                offset: message.message.length,
              );
            });
          },
        ),
      if (message.editHistory.isNotEmpty)
        _MessageAction(
          icon: Icons.history,
          label: 'View edit history',
          onSelected: () {
            Navigator.pop(context);
            _showEditHistory(message);
          },
        ),
      _MessageAction(
        icon: Icons.info_outline,
        label: 'Message info',
        onSelected: () {
          Navigator.pop(context);
          _showMessageInfo(message);
        },
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ...actions.map(
                (action) => ListTile(
                  leading: Icon(action.icon, color: colorScheme.primary),
                  title: Text(action.label, style: textTheme.bodyLarge),
                  onTap: action.onSelected,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditHistory(MessageModel message) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final entries = List<MessageEditEntry>.from(message.editHistory);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit history',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  const Text('No edits yet')
                else
                  ...entries.map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.text),
                      subtitle: Text(_formatFullDate(entry.editedAt)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessageInfo(MessageModel message) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final seenEntries = message.seenBy.entries
        .where((entry) => entry.key != message.senderId)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    DateTime? readAt;
    if (!_isGroup) {
      final otherId = _memberIds.firstWhere(
        (id) => id != message.senderId,
        orElse: () => '',
      );
      if (otherId.isNotEmpty) {
        readAt = message.seenBy[otherId];
      }
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message info',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                if (!_isGroup)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _statusIcon(message.status),
                      color: _statusColor(message.status, colorScheme),
                    ),
                    title: Text(
                      message.status.name.toUpperCase(),
                      style: textTheme.bodyLarge,
                    ),
                    subtitle: Text(
                      switch (message.status) {
                        MessageStatus.read when readAt != null =>
                          'Read at ${_formatFullDate(readAt)}',
                        MessageStatus.read => 'Read',
                        MessageStatus.delivered => 'Delivered',
                        MessageStatus.sent => 'Sent',
                        MessageStatus.sending => 'Sending…',
                      },
                    ),
                  ),
                if (_isGroup) ...[
                  Text(
                    'Seen by',
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (seenEntries.isEmpty)
                    Text(
                      'No one has seen this yet',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...seenEntries.map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          child: Text(
                            _resolveUserName(entry.key).substring(0, 1).toUpperCase(),
                          ),
                        ),
                        title: Text(_resolveUserName(entry.key)),
                        subtitle: Text(_formatFullDate(entry.value)),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _openImagePreview(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('Unable to open file.');
    }
  }

  void _showChatInfo() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        if (_isGroup) {
          return _buildGroupInfoSheet();
        }
        return _buildPersonInfoSheet();
      },
    );
  }

  String _formatRecordingDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _inferImageContentType(String extension) {
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  String _inferFileContentType(String extension) {
    switch (extension) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.txt':
        return 'text/plain';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.aac':
        return 'audio/aac';
      case '.m4a':
        return 'audio/m4a';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }

  Widget _buildGroupInfoSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final groupName = widget.chatData['name'] ?? widget.chatData['groupName'] ?? 'Group';
    final imageUrl = widget.chatData['imageUrl'] ?? widget.chatData['groupImageUrl'];
    final members = _memberIds;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                  child: imageUrl == null
                      ? Text(
                          groupName.substring(0, 1).toUpperCase(),
                          style: textTheme.headlineSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
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
                        groupName,
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${members.length} members',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Members',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...members.map(
              (memberId) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  child: Text(
                    _resolveUserName(memberId).substring(0, 1).toUpperCase(),
                  ),
                ),
                title: Text(_resolveUserName(memberId)),
                subtitle: Text(memberId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonInfoSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final otherId = _memberIds.firstWhere(
      (id) => id != _authService.currentUser?.uid,
      orElse: () => widget.chatData['otherUserId'] ?? '',
    );
    final name = _resolveUserName(otherId, fallback: widget.chatData['name']);
    final imageUrl = _memberImages[otherId] ??
        widget.chatData['imageUrl'] ??
        widget.chatData['profileImageUrl'];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                  child: imageUrl == null
                      ? Text(
                          name.substring(0, 1).toUpperCase(),
                          style: textTheme.headlineSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
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
                        name,
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.chatData['email'] != null)
                        Text(
                          widget.chatData['email'],
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Contact info',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.chatData['phone'] != null)
              _buildInfoRow(Icons.phone, 'Phone', widget.chatData['phone']),
            if (widget.chatData['email'] != null)
              _buildInfoRow(Icons.email, 'Email', widget.chatData['email']),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _resolveUserName(String userId, {String? fallback}) {
    if (_authService.currentUser?.uid == userId) {
      return 'You';
    }
    return _memberNames[userId] ?? fallback ?? 'Member';
  }
}

class _MessageAction {
  _MessageAction({
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
}



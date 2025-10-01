import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:roomie/data/models/user_model.dart';
import 'package:roomie/data/datasources/firestore_service.dart';
import 'package:roomie/data/datasources/chat_manager.dart';
import 'package:roomie/presentation/screens/chat/chat_screen.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId;

  const OtherUserProfileScreen({super.key, required this.userId});

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ChatManager _chatManager = ChatManager();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  UserModel? _user;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isProcessingFollow = false;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await _loadUserData();
    await _checkIfFollowing();
    await _loadFollowCounts();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _firestoreService.getUserDetails(widget.userId);
      if (userData != null && mounted) {
        setState(() {
          _user = UserModel.fromMap(userData, widget.userId);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _checkIfFollowing() async {
    final isFollowing =
        await _firestoreService.isFollowing(_currentUserId, widget.userId);
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
      });
    }
  }

  Future<void> _loadFollowCounts() async {
    final followers = await _firestoreService.getFollowersCount(widget.userId);
    final following = await _firestoreService.getFollowingCount(widget.userId);
    if (mounted) {
      setState(() {
        _followersCount = followers;
        _followingCount = following;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (mounted) {
      setState(() {
        _isProcessingFollow = true;
      });
    }
    try {
      if (_isFollowing) {
        await _firestoreService.unfollowUser(_currentUserId, widget.userId);
        if (mounted) {
          setState(() {
            _followersCount--;
          });
        }
      } else {
        await _firestoreService.followUser(_currentUserId, widget.userId);
        if (mounted) {
          setState(() {
            _followersCount++;
          });
        }
      }
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingFollow = false;
        });
      }
    }
  }

  Future<void> _openChat() async {
    if (_user == null) return;
    
    try {
      // Create or get existing individual chat using ChatManager
      final individualChat = await _chatManager.createOrGetIndividualChat(
        otherUserId: widget.userId,
        otherUserName: _user!.name ?? 'Unknown User',
        otherUserImageUrl: _user!.profileImageUrl,
      );
      
      // Prepare chat data for individual chat
      final chatData = {
        'id': individualChat.id,
        'name': _user!.name ?? 'Unknown User',
        'otherUserId': widget.userId,
        'otherUserName': _user!.name ?? 'Unknown User',
        'profileImageUrl': _user!.profileImageUrl,
        'otherUserImageUrl': _user!.profileImageUrl,
        'imageUrl': _user!.profileImageUrl, // For compatibility with messages page
        'email': _user!.email,
        'userData': {
          'name': _user!.name ?? 'Unknown User',
          'profileImageUrl': _user!.profileImageUrl,
          'email': _user!.email,
          'uid': widget.userId,
        },
      };
      
      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatData: chatData,
              chatType: 'individual',
            ),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: ${e.toString()}'),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _user?.name ?? 'Profile',
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          : _user == null
              ? const Center(child: Text('User not found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        backgroundImage: _user!.profileImageUrl != null
                            ? NetworkImage(_user!.profileImageUrl!)
                            : null,
                        child: _user!.profileImageUrl == null
                          ? Icon(Icons.person, size: 60, color: colorScheme.onSurfaceVariant)
                          : null,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _user!.name ?? 'No Name',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _user!.bio ?? 'No bio available.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFollowerInfo('Followers', _followersCount),
                          Container(
                            height: 40,
                            width: 1,
                            color: colorScheme.outlineVariant,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          _buildFollowerInfo('Following', _followingCount),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (widget.userId != _currentUserId)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isProcessingFollow
                                    ? null
                                    : _toggleFollow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFollowing
                                      ? colorScheme.surfaceContainerHighest
                                      : colorScheme.primary,
                                  foregroundColor: _isFollowing
                                      ? colorScheme.onSurface
                                      : colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                ),
                child: _isProcessingFollow
                  ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  colorScheme.onPrimary),
                                        ))
                                    : Text(
                                        _isFollowing ? 'Unfollow' : 'Follow',
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: _isFollowing
                                              ? colorScheme.onSurface
                                              : colorScheme.onPrimary,
                                        ),
                                      ),
                              ),
                            ),
                            if (_isFollowing) ...[
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _openChat,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.secondary,
                                    foregroundColor: colorScheme.onSecondary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Message',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildInfoSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFollowerInfo(String label, int count) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      children: [
        Text(
          count.toString(),
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Information',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        if (_user?.occupation != null) ...[
          _buildInfoRow(
              Icons.work_outline, 'Occupation', _user!.occupation!),
          const Divider(height: 32),
        ],
        if (_user?.age != null) ...[
          _buildInfoRow(Icons.cake_outlined, 'Age', '${_user!.age} years old'),
          const Divider(height: 32),
        ],
        if (_user?.createdAt != null) ...[
          _buildInfoRow(Icons.calendar_today_outlined, 'Member Since',
              '${_user!.createdAt!.toLocal()}'.split(' ')[0]),
        ],
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 16),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

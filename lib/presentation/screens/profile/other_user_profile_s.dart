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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _user?.name ?? 'Profile',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('User not found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: _user!.profileImageUrl != null
                            ? NetworkImage(_user!.profileImageUrl!)
                            : null,
                        child: _user!.profileImageUrl == null
                            ? Icon(Icons.person,
                                size: 60, color: Colors.grey.shade400)
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _user!.name ?? 'No Name',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF121417)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _user!.bio ?? 'No bio available.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF677583)),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFollowerInfo('Followers', _followersCount),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey.shade300,
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
                                      ? Colors.grey.shade200
                                      : const Color(0xFF007AFF),
                                  foregroundColor: _isFollowing
                                      ? Colors.black
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                ),
                                child: _isProcessingFollow
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ))
                                    : Text(
                                        _isFollowing ? 'Unfollow' : 'Follow',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                            if (_isFollowing) ...[
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _openChat,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Message',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
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
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF121417)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF677583)),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF121417),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF121417)),
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roomie/presentation/screens/groups/join_requests_s.dart';
import 'package:roomie/presentation/screens/profile/other_user_profile_s.dart';
import 'package:roomie/data/datasources/firestore_service.dart';

class CurrentGroupDetailScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  final VoidCallback? onLeaveGroup;

  const CurrentGroupDetailScreen({
    super.key,
    required this.group,
    this.onLeaveGroup,
  });

  @override
  State<CurrentGroupDetailScreen> createState() =>
      _CurrentGroupDetailScreenState();
}

class _CurrentGroupDetailScreenState extends State<CurrentGroupDetailScreen> {
  late Future<List<Map<String, dynamic>>> _membersFuture;
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, bool> _followingStatus = {};

  @override
  void initState() {
    super.initState();
    _membersFuture = _fetchGroupMembers();
    _membersFuture.then((members) => _checkFollowingStatus(members));
  }

  void _refreshFollowingStatus() {
    _membersFuture.then((members) => _checkFollowingStatus(members));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchGroupMembers() async {
    final memberIds = List<String>.from(widget.group['members'] ?? []);
    debugPrint('Group members IDs: $memberIds');
    if (memberIds.isEmpty) {
      return [];
    }

    final membersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: memberIds)
        .get();

    final membersList = membersQuery.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
    debugPrint('Fetched members data: $membersList');
    return membersList;
  }

  Future<void> _checkFollowingStatus(List<Map<String, dynamic>> members) async {
    for (var member in members) {
      if (member['id'] != _currentUserId) {
        final isFollowing =
            await _firestoreService.isFollowing(_currentUserId, member['id']);
        if (mounted) {
          setState(() {
            _followingStatus[member['id']] = isFollowing;
          });
        }
      }
    }
  }

  Future<void> _toggleFollow(String memberId) async {
    final isCurrentlyFollowing = _followingStatus[memberId] ?? false;
    if (mounted) {
      setState(() {
        _followingStatus[memberId] = !isCurrentlyFollowing;
      });
    }
    try {
      if (isCurrentlyFollowing) {
        await _firestoreService.unfollowUser(_currentUserId, memberId);
      } else {
        await _firestoreService.followUser(_currentUserId, memberId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _followingStatus[memberId] = isCurrentlyFollowing; // Revert on error
        });
      }
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat.yMMMd().format(timestamp.toDate());
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _currencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'INR':
      default:
        return '₹';
    }
  }

  String _formatRent(double amount, String currency) {
    if (amount <= 0) return 'Not specified';
    final formatter = NumberFormat.compactCurrency(
      symbol: _currencySymbol(currency),
      decimalDigits: 0,
    );
    return '${formatter.format(amount)}/month';
  }

  String _formatAdvance(double amount, String currency) {
    if (amount <= 0) return 'No advance';
    final formatter = NumberFormat.compactCurrency(
      symbol: _currencySymbol(currency),
      decimalDigits: 0,
    );
    return '${formatter.format(amount)} deposit';
  }

  Future<void> _showLeaveGroupDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leave Group'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to leave this group?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Leave'),
              onPressed: () {
                if (widget.onLeaveGroup != null) {
                  widget.onLeaveGroup!();
                }
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context)
                    .pop(); // Go back from the group detail screen
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = List<String>.from(widget.group['images'] ?? []);
    final bool hasImages = images.isNotEmpty;
    final dynamic rentRaw = widget.group['rent'];
    double rentAmount = _toDouble(widget.group['rentAmount']);
    String rentCurrency = (widget.group['rentCurrency'] ?? '').toString();
    double advanceAmount = _toDouble(widget.group['advanceAmount']);

    if (rentAmount == 0 && rentRaw != null) {
      if (rentRaw is Map<String, dynamic>) {
        rentAmount = _toDouble(rentRaw['amount']);
      } else if (rentRaw is num || rentRaw is String) {
        rentAmount = _toDouble(rentRaw);
      }
    }

    if (rentCurrency.isEmpty && rentRaw is Map<String, dynamic>) {
      rentCurrency = (rentRaw['currency'] ?? 'INR').toString();
    }
    if (rentCurrency.isEmpty) {
      rentCurrency = 'INR';
    }

    if (advanceAmount == 0 && rentRaw is Map<String, dynamic>) {
      advanceAmount = _toDouble(rentRaw['advanceAmount']);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'group-image-${widget.group['id']}',
                child:
                    hasImages
                        ? _buildImageSlider(images)
                        : _buildPlaceholderImage(),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                      Expanded(
                        child: Text(
                          widget.group['name'] ?? 'Unnamed Group',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF121417),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.group['description'] ?? 'No description available.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF677583),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFE8E8E8)),
                  const SizedBox(height: 24),
                  _buildFullWidthInfoCard(
                    icon: Icons.location_on_outlined,
                    title: 'Location',
                    value: widget.group['location'] ?? 'Not specified',
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.attach_money,
                          title: 'Rent',
                          value: _formatRent(rentAmount, rentCurrency),
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Advance',
                          value: _formatAdvance(advanceAmount, rentCurrency),
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.group_outlined,
                          title: 'Roommates',
                          value: widget.group['capacity']?.toString() ?? 'N/A',
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.home_outlined,
                          title: 'Room Type',
                          value: widget.group['roomType'] ?? 'N/A',
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.calendar_today_outlined,
                    title: 'Created On',
                    value: _formatTimestamp(
                      widget.group['createdAt'] as Timestamp?,
                    ),
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 24),
                  if (widget.group['amenities'] != null &&
                      (widget.group['amenities'] as List).isNotEmpty) ...[
                    const Text(
                      'Facilities',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF121417),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAmenitiesGrid(
                      List<String>.from(widget.group['amenities']),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Members',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF121417),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => JoinRequestsScreen(
                                    group: widget.group,
                                  ),
                                ),
                              );
                            },
                            child: Image.asset(
                              'assets/icons/manage_request.png',
                              width: 24,
                              height: 24,
                              errorBuilder: (context, error, stack) => SizedBox(
                                width: 24,
                                height: 24,
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _showLeaveGroupDialog,
                            child: Image.asset(
                              'assets/icons/leave_group.png',
                              width: 30,
                              height: 30,
                              errorBuilder: (context, error, stack) => SizedBox(
                                width: 24,
                                height: 24,
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMembersSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSlider(List<String> images) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return Image.network(
              images[index],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderImage();
              },
            );
          },
        ),
        if (images.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentImageIndex == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: const Center(
        child: Icon(Icons.group, color: Colors.grey, size: 60),
      ),
    );
  }

  Widget _buildAmenitiesGrid(List<String> amenities) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          amenities.map((amenity) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                amenity,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildMembersSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No members found.'));
        }

        final members = snapshot.data!;
        return Column(
          children: members.map((member) {
            final isCreator = member['uid'] == widget.group['createdBy'];
            final isCurrentUser = member['id'] == _currentUserId;
            final isFollowing = _followingStatus[member['id']] ?? false;

            debugPrint(
                'Building member item: ${member['name']}, isCurrentUser: $isCurrentUser, isCreator: $isCreator');

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                onTap: () async {
                  if (!isCurrentUser) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OtherUserProfileScreen(
                          userId: member['id'],
                        ),
                      ),
                    );
                    // Refresh following status when returning
                    _refreshFollowingStatus();
                  }
                },
                contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFF0F0F0),
                  backgroundImage: member['profileImageUrl'] != null
                      ? NetworkImage(member['profileImageUrl'])
                      : null,
                  child: member['profileImageUrl'] == null
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                title: Text(
                  member['name'] ?? 'Unnamed Member',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: isCurrentUser
                    ? const Text('You', style: TextStyle(color: Colors.grey))
                    : isCreator
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                color: Colors.indigo,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : (!isFollowing
                            ? ElevatedButton(
                                onPressed: () => _toggleFollow(member['id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 2,
                                  ),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: const Size(0, 30),
                                ),
                                child: const Text('Follow'),
                              )
                            : const SizedBox.shrink()),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFullWidthInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF677583),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF121417),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF677583),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF121417),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

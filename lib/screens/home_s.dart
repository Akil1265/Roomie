import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roomie/screens/create_group_s.dart';
import 'package:roomie/screens/user_profile_s.dart';
import 'package:roomie/screens/chat_screen.dart';
import 'package:roomie/screens/available_group_detail_s.dart';
import 'package:roomie/screens/join_requests_s.dart';
import 'package:roomie/screens/current_group_detail_s.dart';
import 'package:roomie/screens/messages_page.dart';
import 'package:roomie/screens/notifications_s.dart'; // Import notifications screen
import 'package:roomie/services/groups_service.dart';
import 'package:roomie/services/notification_service.dart';
import 'package:roomie/services/auth_service.dart';
import 'package:roomie/models/notification_model.dart';
import 'package:roomie/widgets/roomie_loading_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 1);
  int _currentPageIndex = 1; // 0: Search, 1: Home, 2: Messages

  final GroupsService _groupsService = GroupsService();
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _availableGroups = [];
  Map<String, dynamic>? _currentUserGroup;
  bool _isLoadingGroups = true;
  bool _canUserCreateGroup = true;

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

  String _formatAmount(double amount, String currency, {String? suffix}) {
    if (amount <= 0) return 'Not specified';
    final formatter = NumberFormat.compactCurrency(
      symbol: _currencySymbol(currency),
      decimalDigits: 0,
    );
    final formatted = formatter.format(amount);
    if (suffix != null && suffix.isNotEmpty) {
      return '$formatted $suffix';
    }
    return formatted;
  }

  Map<String, dynamic> _parseRentDetails(Map<String, dynamic> group) {
    final dynamic rentRaw = group['rent'];
    double rentAmount = _toDouble(group['rentAmount']);
    String rentCurrency = (group['rentCurrency'] ?? '').toString();
    double advanceAmount = _toDouble(group['advanceAmount']);

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

    return {
      'rentAmount': rentAmount,
      'rentCurrency': rentCurrency,
      'advanceAmount': advanceAmount,
    };
  }

  Widget _buildMetaChip({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    final userId = _authService.currentUser?.uid;

    if (userId == null) {
      return _buildNotificationIconShell();
    }

    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.getNotifications(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildNotificationIconShell();
        }

        final notifications = snapshot.data ?? const [];
        final unreadCount =
            notifications.where((notification) => !notification.isRead).length;

        return _buildNotificationIconShell(unreadCount: unreadCount);
      },
    );
  }

  Widget _buildNotificationIconShell({int unreadCount = 0}) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _buildNotificationIcon()),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minHeight: 18, minWidth: 18),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsScreen(),
            ),
          );
        },
        icon: const Icon(
          Icons.notifications_none,
          color: Color(0xFF121417),
          size: 24,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserGroupData();
  }

  Future<void> _loadUserGroupData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingGroups = true;
    });

    try {
      print('=== Loading user group data ===');
      final currentGroup = await _groupsService.getCurrentUserGroup();
      final canCreate = await _groupsService.canUserCreateGroup();
      final availableGroups = await _groupsService.getAvailableGroups();

      print('Current group: ${currentGroup?['name'] ?? 'None'}');
      print('Can create group: $canCreate');
      print('Available groups: ${availableGroups.length}');

      if (mounted) {
        setState(() {
          _currentUserGroup = currentGroup;
          _canUserCreateGroup = canCreate;
          _availableGroups = availableGroups;
          _isLoadingGroups = false;
        });
        print('UI updated with new data');
      }
    } catch (e) {
      print('Error loading user group data: $e');
      if (mounted) {
        setState(() {
          _isLoadingGroups = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading group data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    if (_currentUserGroup == null) return;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Leave Group'),
              content: Text(
                'Are you sure you want to leave ${_currentUserGroup!['name']}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Leave'),
                ),
              ],
            ),
      );

      if (confirmed == true) {
        await _groupsService.leaveGroup(_currentUserGroup!['id']);
        // Pop the details screen
        if (mounted) Navigator.of(context).pop();
        await _loadUserGroupData(); // Refresh home screen data

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully left the group'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leaving group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToGroupDetails() {
    if (_currentUserGroup == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CurrentGroupDetailScreen(
              group: _currentUserGroup!,
              onLeaveGroup: _leaveGroup,
            ),
      ),
    ).then((_) => _loadUserGroupData());
  }

  void navigateToPage(int pageIndex) {
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
            },
            children: [
              _buildSearchPage(),
              _buildHomeContent(),
              _buildMessagesPage(),
            ],
          ),
          // Page indicators
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageIndicator(0, 'Search'),
                const SizedBox(width: 12),
                _buildPageIndicator(1, 'Home'),
                const SizedBox(width: 12),
                _buildPageIndicator(2, 'Messages'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index, String label) {
    final isActive = _currentPageIndex == index;
    return GestureDetector(
      onTap: () => navigateToPage(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF121417) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isActive ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Home',
                      style: TextStyle(
                        color: Color(0xFF121417),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        // Notifications button with badge
                        _buildNotificationButton(),
                        const SizedBox(width: 8),
                        // Profile button
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const UserProfileScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.person_outline,
                              color: Color(0xFF121417),
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Add button - Only show if user can create (no current group)
                        if (_canUserCreateGroup)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => const CreateGroupScreen(),
                                  ),
                                ).then((_) => _loadUserGroupData());
                              },
                              icon: const Icon(
                                Icons.add,
                                color: Color(0xFF121417),
                                size: 24,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUserGroupData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoadingGroups)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: RoomieLoadingWidget(
                            size: 80,
                            text: 'Loading groups...',
                            showText: true,
                          ),
                        ),
                      )
                    else ...[
                      // Current Room Section (show if user is in a group)
                      if (_currentUserGroup != null) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            'Current Room',
                            style: TextStyle(
                              color: Color(0xFF121417),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildCozyCornerCard(),
                        // Available Rooms section below current room
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                          child: Text(
                            'Available Rooms',
                            style: TextStyle(
                              color: Color(0xFF121417),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildAvailableGroupsList(),
                      ],
                      // Available Groups Section (only show if user has no group)
                      if (_currentUserGroup == null) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Text(
                            'Available Groups',
                            style: TextStyle(
                              color: Color(0xFF121417),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildAvailableGroupsList(),
                      ],
                    ],
                    const SizedBox(
                      height: 100,
                    ), // Bottom padding for page indicators
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCozyCornerCard() {
    final pricing = _parseRentDetails(_currentUserGroup!);
    final double rentAmount = pricing['rentAmount'] as double;
    final String rentCurrency = pricing['rentCurrency'] as String;
    final double advanceAmount = pricing['advanceAmount'] as double;
    final String roomType =
        (_currentUserGroup!['roomType'] ?? 'Shared').toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      child: GestureDetector(
        onTap: _navigateToGroupDetails,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group Image
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: const Color(0xFFF5F5F5),
                    child: Image.network(
                      _currentUserGroup!['imageUrl'] ??
                          'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 50,
                          ),
                        );
                      },
                    ),
                  ),
                  // Group Details
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUserGroup!['name'] ?? 'My Group',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF121417),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentUserGroup!['description'] ??
                              'Your current group where you can connect with roommates.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF677583),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (rentAmount > 0)
                              _buildMetaChip(
                                icon: Icons.attach_money,
                                color: Colors.green,
                                label: _formatAmount(
                                  rentAmount,
                                  rentCurrency,
                                  suffix: 'per month',
                                ),
                              ),
                            if (advanceAmount > 0)
                              _buildMetaChip(
                                icon: Icons.account_balance_wallet_outlined,
                                color: Colors.deepPurple,
                                label: _formatAmount(
                                  advanceAmount,
                                  rentCurrency,
                                  suffix: 'advance',
                                ),
                              ),
                            _buildMetaChip(
                              icon: Icons.home_outlined,
                              color: Colors.teal,
                              label: roomType,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_currentUserGroup!['memberCount'] ?? 1} members',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF677583),
                              ),
                            ),
                            // Chat Button
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ChatScreen(
                                          chatData: _currentUserGroup!,
                                          chatType: 'group',
                                        ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Chat',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableGroupsList() {
    if (_availableGroups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.group_add_outlined,
                color: Colors.grey,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'No groups available',
                style: TextStyle(
                  color: Color(0xFF121417),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _canUserCreateGroup
                    ? 'Create your first group to get started'
                    : 'You are already in a group.',
                style: const TextStyle(color: Color(0xFF677583), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children:
            _availableGroups.map((group) {
              final pricing = _parseRentDetails(group);
              final double rentAmount = pricing['rentAmount'] as double;
              final String rentCurrency = pricing['rentCurrency'] as String;
              final double advanceAmount = pricing['advanceAmount'] as double;
              final String roomType =
                  (group['roomType'] ?? 'Shared').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                AvailableGroupDetailScreen(group: group),
                      ),
                    ).then(
                      (_) => _loadUserGroupData(),
                    ); // Refresh data when returning
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group['name'] ?? 'Unknown Group',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF121417),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${group['location'] ?? 'Location'}, ${group['memberCount'] ?? 0} members',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF677583),
                                ),
                              ),
                              if (group['description'] != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  group['description'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF677583),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (rentAmount > 0)
                                    _buildMetaChip(
                                      icon: Icons.attach_money,
                                      color: Colors.green,
                                      label: _formatAmount(
                                        rentAmount,
                                        rentCurrency,
                                        suffix: 'per month',
                                      ),
                                    ),
                                  if (advanceAmount > 0)
                                    _buildMetaChip(
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      color: Colors.deepPurple,
                                      label: _formatAmount(
                                        advanceAmount,
                                        rentCurrency,
                                        suffix: 'advance',
                                      ),
                                    ),
                                  if (roomType.isNotEmpty)
                                    _buildMetaChip(
                                      icon: Icons.home_outlined,
                                      color: Colors.teal,
                                      label: roomType,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFF5F5F5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                group['imageUrl'] != null
                                    ? Image.network(
                                      group['imageUrl'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return const Icon(
                                          Icons.group,
                                          color: Colors.grey,
                                          size: 30,
                                        );
                                      },
                                    )
                                    : const Icon(
                                      Icons.group,
                                      color: Colors.grey,
                                      size: 30,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildSearchPage() {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF121417),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Search functionality coming soon',
              style: TextStyle(fontSize: 16, color: Color(0xFF677583)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesPage() {
    return const MessagesPage();
  }
}

// Group Details Screen
class GroupDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> group;
  final bool isCurrentUserGroup;
  final VoidCallback? onLeaveGroup;

  const GroupDetailsScreen({
    super.key,
    required this.group,
    required this.isCurrentUserGroup,
    this.onLeaveGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF121417)),
        ),
        title: Text(
          group['name'] ?? 'Group Details',
          style: const TextStyle(
            color: Color(0xFF121417),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Image
            Container(
              height: 250,
              width: double.infinity,
              color: const Color(0xFFF5F5F5),
              child: Image.network(
                group['imageUrl'] ??
                    'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.image, color: Colors.grey, size: 50),
                  );
                },
              ),
            ),

            // Group Details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group['name'] ?? 'Group Name',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF121417),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFF677583),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        group['location'] ?? 'Location',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF677583),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.people_outline,
                        color: Color(0xFF677583),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${group['memberCount'] ?? 0} members',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF677583),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF121417),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    group['description'] ?? 'No description available.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF677583),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  if (isCurrentUserGroup) ...[
                    // Manage Join Requests Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => JoinRequestsScreen(group: group),
                            ),
                          );
                        },
                        icon: const Icon(Icons.group_add, size: 18),
                        label: const Text(
                          'Manage Join Requests',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Leave Group Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onLeaveGroup,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Leave Group',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

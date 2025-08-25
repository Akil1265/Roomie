import 'package:flutter/material.dart';
import 'package:roomie/screens/create_group_s.dart';
import 'package:roomie/screens/user_profile_s.dart';
import 'package:roomie/services/mongo_groups_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final MongoGroupsService _mongoGroupsService = MongoGroupsService();
  List<Map<String, dynamic>> _availableGroups = [];
  Map<String, dynamic>? _currentUserGroup;
  bool _isLoadingGroups = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableGroups();
    _loadCurrentUserGroup();
  }

  Future<void> _loadAvailableGroups() async {
    setState(() {
      _isLoadingGroups = true;
    });

    try {
      final groups = await _mongoGroupsService.getAllGroups();
      setState(() {
        _availableGroups = groups;
        _isLoadingGroups = false;
      });
    } catch (e) {
      print('Error loading groups: $e');
      setState(() {
        _isLoadingGroups = false;
      });
    }
  }

  Future<void> _loadCurrentUserGroup() async {
    // This would be your logic to get the current user's joined group
    // For now, I'll simulate with the first group if available
    try {
      final groups = await _mongoGroupsService.getAllGroups();
      if (groups.isNotEmpty) {
        setState(() {
          _currentUserGroup = groups.first;
        });
      }
    } catch (e) {
      print('Error loading current user group: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget currentPage;
    switch (_selectedIndex) {
      case 0:
        currentPage = _buildHomeContent();
        break;
      case 1:
        currentPage = _buildMessagesPage();
        break;
      case 3:
        currentPage = _buildSearchPage();
        break;
      case 4:
        currentPage = _buildProfilePage();
        break;
      default:
        currentPage = _buildHomeContent();
    }

    return currentPage;
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
                    // Add button (create group)
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
                              builder: (context) => const CreateGroupScreen(),
                            ),
                          ).then((_) => _loadAvailableGroups());
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
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Featured Group Card - Always show "The Cozy Corner" as in the design
                  Padding(
                    padding: const EdgeInsets.all(16.0),
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
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF5F5F5),
                                ),
                                child: Image.network(
                                  _currentUserGroup?['imageUrl'] ??
                                      'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFFF5F5F5),
                                      child: const Center(
                                        child: Icon(
                                          Icons.image,
                                          color: Colors.grey,
                                          size: 50,
                                        ),
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
                                      _currentUserGroup?['name'] ??
                                          'The Cozy Corner',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF121417),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _currentUserGroup?['description'] ??
                                          'A friendly group of young professionals looking for a roommate in a spacious apartment near downtown.',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF677583),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${_currentUserGroup?['memberCount'] ?? 3} members',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF677583),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF007AFF),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Text(
                                            'Chat ...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
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

                  // Available Groups Section
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

                  // Groups List
                  if (_isLoadingGroups)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    )
                  else if (_availableGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.group_add_outlined,
                              color: Colors.grey,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No groups available',
                              style: TextStyle(
                                color: Color(0xFF121417),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Create your first group or wait for others to join',
                              style: TextStyle(
                                color: Color(0xFF677583),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Urban Living Group
                          Container(
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
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Urban Living',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF121417),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Downtown, 2 members',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF677583),
                                          ),
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
                                      child: Image.network(
                                        'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80',
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return const Icon(
                                            Icons.apartment,
                                            color: Colors.grey,
                                            size: 30,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // The Green Oasis Group
                          Container(
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
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'The Green Oasis',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF121417),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Near the park, 4 members',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF677583),
                                          ),
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
                                      child: Image.network(
                                        'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&q=80',
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return const Icon(
                                            Icons.nature,
                                            color: Colors.grey,
                                            size: 30,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Dynamic groups from the service
                          ...List.generate(_availableGroups.length, (index) {
                            final group = _availableGroups[index];
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
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group['name'] ??
                                                'Group ${index + 1}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF121417),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${group['location'] ?? 'Location'}, ${group['memberCount'] ?? 1} members',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF677583),
                                            ),
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
                            );
                          }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 100), // Space for bottom navigation
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildMessagesPage() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: const SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: Color(0xFF677583),
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Messages',
                style: TextStyle(
                  color: Color(0xFF121417),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Coming soon',
                style: TextStyle(color: Color(0xFF677583), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildSearchPage() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: const SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, color: Color(0xFF677583), size: 64),
              SizedBox(height: 16),
              Text(
                'Search',
                style: TextStyle(
                  color: Color(0xFF121417),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Find groups and roommates',
                style: TextStyle(color: Color(0xFF677583), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildProfilePage() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: const SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, color: Color(0xFF677583), size: 64),
              SizedBox(height: 16),
              Text(
                'Profile',
                style: TextStyle(
                  color: Color(0xFF121417),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Manage your account',
                style: TextStyle(color: Color(0xFF677583), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F2F4), width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(Icons.home, 0, true),
              _buildBottomNavItem(Icons.chat_bubble_outline, 1, false),
              _buildBottomNavItem(Icons.add_box_outlined, 2, false),
              _buildBottomNavItem(Icons.search, 3, false),
              _buildBottomNavItem(Icons.person_outline, 4, false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, int index, bool filled) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 2) {
          // Plus/Add button - navigate to create group
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
          ).then((_) => _loadAvailableGroups());
        } else if (index == 4) {
          // Profile button
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserProfileScreen()),
          );
        } else {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Icon(
          isSelected && filled ? Icons.home : icon,
          color: isSelected ? const Color(0xFF121417) : const Color(0xFF677583),
          size: 24,
        ),
      ),
    );
  }
}

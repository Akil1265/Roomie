import 'package:flutter/material.dart';
import 'package:roomie/screens/create_group_s.dart';
import 'package:roomie/screens/user_profile_s.dart';
import 'package:roomie/services/groups_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 1); // Start at home (middle page)
  int _currentPageIndex = 1; // 0: Search, 1: Home, 2: Messages
  final GroupsService _groupsService = GroupsService();
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
  final groups = await _groupsService.getAllGroups();
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
  final groups = await _groupsService.getAllGroups();
      if (groups.isNotEmpty) {
        setState(() {
          _currentUserGroup = groups.first;
        });
      }
    } catch (e) {
      print('Error loading current user group: $e');
    }
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
              _buildSearchPage(),     // Page 0 - Swipe left to reach from home
              _buildHomeContent(),    // Page 1 - Center/Default page
              _buildMessagesPage(),   // Page 2 - Swipe right to reach from home
            ],
          ),
          // Page indicators
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageIndicator(0, 'Search'),
                const SizedBox(width: 20),
                _buildPageIndicator(1, 'Home'),
                const SizedBox(width: 20),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF121417) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: isActive ? null : Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey[600],
          fontSize: 12,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
                                  builder: (context) => const UserProfileScreen(),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPage() {
    return SearchPageWidget();
  }

  Widget _buildMessagesPage() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: () {
                          // Add any message actions here
                        },
                        icon: const Icon(
                          Icons.more_vert,
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
            // Messages content
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.grey[400],
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No messages yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your group messages will appear here',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }






}

class SearchPageWidget extends StatefulWidget {
  const SearchPageWidget({super.key});

  @override
  State<SearchPageWidget> createState() => _SearchPageWidgetState();
}

class _SearchPageWidgetState extends State<SearchPageWidget> {
  final TextEditingController _searchController = TextEditingController();
  final GroupsService _groupsService = GroupsService();
  List<Map<String, dynamic>> _allGroups = [];
  List<Map<String, dynamic>> _filteredGroups = [];
  bool _isLoading = false;
  String _selectedLocation = 'All';
  double _maxRent = 2000;
  String _selectedOccupation = 'All';
  int _preferredMembers = 0; // 0 means any
  String _sortBy = 'Rent: Low to High';

  @override
  void initState() {
    super.initState();
    // Don't load groups automatically - only when user searches
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _searchGroups(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all groups first
      final allGroups = await _groupsService.getAllGroups();
      
      // Filter groups based on search query
      final searchQuery = query.toLowerCase();
      final matchingGroups = allGroups.where((group) {
        final name = (group['name'] ?? '').toString().toLowerCase();
        final description = (group['description'] ?? '').toString().toLowerCase();
        final location = (group['location'] ?? '').toString().toLowerCase();
        
        return name.contains(searchQuery) || 
               description.contains(searchQuery) || 
               location.contains(searchQuery);
      }).toList();

      // Process and format matching group data for display
      _allGroups = matchingGroups.map((group) {
        // Determine group type based on max members
        String groupType = 'Small Group';
        final maxMembers = group['maxMembers'] ?? 0;
        if (maxMembers > 6) {
          groupType = 'Large Group';
        } else if (maxMembers > 3) {
          groupType = 'Medium Group';
        }

        return {
          'id': group['id'] ?? '',
          'title': group['name'] ?? 'Unnamed Group',
          'location': group['location'] ?? 'Unknown Location',
          'rent': (group['rent'] ?? 0).toDouble(),
          'type': groupType,
          'description': group['description'] ?? 'No description available',
          'imageUrl': group['imageUrl'] ?? '',
          'memberCount': group['memberCount'] ?? 0,
          'maxMembers': group['maxMembers'] ?? 0,
          'createdBy': group['createdBy'] ?? '',
          'members': group['members'] ?? [],
          'isActive': group['isActive'] ?? true,
          'createdAt': group['createdAt'],
          'updatedAt': group['updatedAt'],
        };
      }).toList();

      // Apply filters after getting search results
      _applyFilters();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching groups: $e');
      setState(() {
        _allGroups = [];
        _filteredGroups = [];
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty && query.length >= 2) {
      // Only search when user has typed at least 2 characters
      _searchGroups(query);
    } else {
      // Clear results when search is empty or too short
      setState(() {
        _allGroups = [];
        _filteredGroups = [];
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredGroups = _allGroups.where((group) {
        // Search filter
        final query = _searchController.text.toLowerCase();
        final matchesSearch = query.isEmpty ||
            group['title'].toString().toLowerCase().contains(query) ||
            group['description'].toString().toLowerCase().contains(query) ||
            group['location'].toString().toLowerCase().contains(query);

        // Location filter
        final matchesLocation = _selectedLocation == 'All' || group['location'] == _selectedLocation;

        // Rent filter
        final matchesRent = group['rent'] <= _maxRent;

        // Member count filter (0 means any)
        final matchesMembers = _preferredMembers == 0 || group['maxMembers'] == _preferredMembers;

        // For occupation filter, we'll check if any group member has the occupation
        // For now, we'll skip this until you have occupation data in groups
        final matchesOccupation = _selectedOccupation == 'All';

        return matchesSearch && matchesLocation && matchesRent && matchesMembers && matchesOccupation;
      }).toList();

      // Apply sorting
      _filteredGroups.sort((a, b) {
        switch (_sortBy) {
          case 'Rent: Low to High':
            return a['rent'].compareTo(b['rent']);
          case 'Rent: High to Low':
            return b['rent'].compareTo(a['rent']);
          case 'Recently Added':
            if (a['createdAt'] != null && b['createdAt'] != null) {
              return b['createdAt'].compareTo(a['createdAt']);
            }
            return b['id'].compareTo(a['id']); // Fallback
          case 'Most Popular':
            return b['memberCount'].compareTo(a['memberCount']);
          default:
            return 0;
        }
      });
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF5FE),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Filters',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF121417),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Location Filter
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF121417),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildLocationChip('All Areas', 'All', setModalState),
                            _buildLocationChip('Downtown', 'Downtown', setModalState),
                            _buildLocationChip('Suburbs', 'Suburbs', setModalState),
                            _buildLocationChip('City Center', 'City Center', setModalState),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Rent Range Slider
                        const Text(
                          'Rent Range',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF121417),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '\$500',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Expanded(
                              child: Slider(
                                value: _maxRent,
                                min: 500,
                                max: 2500,
                                divisions: 40,
                                activeColor: const Color(0xFF121417),
                                inactiveColor: const Color(0xFF677583).withValues(alpha: 0.3),
                                onChanged: (value) {
                                  setState(() {
                                    _maxRent = value;
                                  });
                                  setModalState(() {});
                                },
                              ),
                            ),
                            Text(
                              '\$${_maxRent.toInt()}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Member Count Filter
                        const Text(
                          'Preferred Members',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF121417),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildMemberChip('Any', 0, setModalState),
                            _buildMemberChip('2 Members', 2, setModalState),
                            _buildMemberChip('3 Members', 3, setModalState),
                            _buildMemberChip('4+ Members', 4, setModalState),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Occupation Filter
                        const Text(
                          'Occupation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF121417),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildOccupationChip('All', 'All', setModalState),
                            _buildOccupationChip('Student', 'Student', setModalState),
                            _buildOccupationChip('Professional', 'Professional', setModalState),
                            _buildOccupationChip('Freelancer', 'Freelancer', setModalState),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Apply Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _applyFilters();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF121417),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Apply Filters',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        // Extra padding for safe area
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLocationChip(String label, String value, Function setModalState) {
    final isSelected = _selectedLocation == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLocation = value;
        });
        setModalState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF121417) : const Color(0xFFFAF5FE),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: const Color(0xFF677583).withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF677583),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberChip(String label, int value, Function setModalState) {
    final isSelected = _preferredMembers == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _preferredMembers = value;
        });
        setModalState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF121417) : const Color(0xFFFAF5FE),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: const Color(0xFF677583).withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF677583),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildOccupationChip(String label, String value, Function setModalState) {
    final isSelected = _selectedOccupation == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOccupation = value;
        });
        setModalState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF121417) : const Color(0xFFFAF5FE),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: const Color(0xFF677583).withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF677583),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: group['imageUrl'] != null && group['imageUrl'].toString().isNotEmpty
                  ? Image.network(
                      group['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage();
                      },
                    )
                  : _buildPlaceholderImage(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        group['title'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF121417),
                        ),
                      ),
                    ),
                    if (group['rent'] != null && group['rent'] > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\$${group['rent'].toInt()}/month',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Location and Type
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        group['location'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        group['type'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF677583),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  group['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Members info
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${group['memberCount']}/${group['maxMembers']} members',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: group['isActive'] == true ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: group['isActive'] == true ? Colors.green[200]! : Colors.red[200]!,
                        ),
                      ),
                      child: Text(
                        group['isActive'] == true ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 12,
                          color: group['isActive'] == true ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO: Implement view details
                          print('View details for ${group['title']}');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF007AFF),
                          side: const BorderSide(color: Color(0xFF007AFF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('View Details'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final success = await _groupsService.joinGroup(group['id']);
                            if (success && mounted) {
                              // Refresh the search results
                              final currentQuery = _searchController.text.trim();
                              if (currentQuery.isNotEmpty && currentQuery.length >= 2) {
                                _searchGroups(currentQuery);
                              }
                            }
                          } catch (e) {
                            // Silent error - just print to console
                            print('Error joining group: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Join Group'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No Image',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Here',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF121417),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar and Filter
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF1F2F4)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Type to search groups (min 2 characters)...',
                              hintStyle: TextStyle(color: Color(0xFF677583)),
                              prefixIcon: Icon(Icons.search, color: Color(0xFF677583)),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: IconButton(
                          onPressed: _showFilterDialog,
                          icon: Icon(Icons.tune, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),

                  // Results Count
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.trim().isEmpty 
                        ? 'Start typing to search for groups...'
                        : _searchController.text.trim().length < 2
                            ? 'Type at least 2 characters to search...'
                            : '${_filteredGroups.length} groups found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Results List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF007AFF)),
                    )
                  : _searchController.text.trim().isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Search for Groups',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Type in the search box above to find\ngroups by name, description, or location',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _searchController.text.trim().length < 2
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Keep Typing...',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Type at least 2 characters to start searching',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _filteredGroups.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No groups found',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try different search terms or filters',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _filteredGroups.length,
                                  itemBuilder: (context, index) {
                                    return _buildGroupCard(_filteredGroups[index]);
                                  },
                                ),
            ),
          ],
        ),
      ),
    );
  }
}

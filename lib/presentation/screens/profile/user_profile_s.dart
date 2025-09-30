import 'package:flutter/material.dart';
import 'package:roomie/models/user_model.dart';
import 'package:roomie/screens/profile/edit_profile_s.dart';
import 'package:roomie/services/auth_service.dart';
import 'package:roomie/services/firestore_service.dart';
import 'package:roomie/services/profile_image_notifier.dart';
import 'package:roomie/widgets/profile_image_widget.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final ProfileImageNotifier _profileImageNotifier = ProfileImageNotifier();
  UserModel? _currentUser;
  bool _isLoading = true;
  // Legacy Mongo widget removed; key no longer required.

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    print('Profile: Loading user data...'); // Debug log
    try {
      final user = _authService.currentUser;
      print(
        'Profile: Current user: ${user?.uid} - ${user?.email}',
      ); // Debug log
      if (user != null) {
        final userData = await _firestoreService.getUserDetails(user.uid);
        print('Profile: Raw user data from Firestore: $userData'); // Debug log
        if (userData != null) {
          print(
            'Profile: User data loaded: ${userData['profileImageUrl']}',
          ); // Debug log
          setState(() {
            _currentUser = UserModel.fromMap(userData, user.uid);
            _isLoading = false;
          });

          // Update global profile image state
          _profileImageNotifier.updateProfileImage(userData['profileImageUrl']);
        } else {
          // Create basic user data if it doesn't exist
          print(
            'Profile: No user data found in Firestore, creating basic user data',
          ); // Debug log
          setState(() {
            _currentUser = UserModel(
              uid: user.uid,
              email: user.email ?? '',
              name: user.displayName,
              phone: user.phoneNumber,
              profileImageUrl: user.photoURL,
            );
            _isLoading = false;
          });
          // Also seed notifier with Google photoURL if present
          if (user.photoURL != null) {
            _profileImageNotifier.updateProfileImage(user.photoURL!);
          }
        }
      } else {
        print('Profile: No authenticated user found'); // Debug log
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Profile: Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is authenticated
    if (_authService.currentUser == null) {
      print('Profile: User not authenticated, redirecting to login');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF121417)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Profile',
            style: TextStyle(
              color: Color(0xFF121417),
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: -0.015,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF121417)),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF121417)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Profile',
            style: TextStyle(
              color: Color(0xFF121417),
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: -0.015,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Color(0xFF677583)),
              SizedBox(height: 16),
              Text(
                'No user data found',
                style: TextStyle(fontSize: 18, color: Color(0xFF677583)),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF121417)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF121417),
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.015,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF121417)),
            onPressed: () async {
              if (_currentUser != null) {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            EditProfileScreen(currentUser: _currentUser!),
                  ),
                );

                // Reload user data if profile was updated
                if (result is Map) {
                  // Optimistic update if we received new URL back
                  final newUrl = result['profileImageUrl'] as String?;
                  if (newUrl != null && newUrl.isNotEmpty) {
                    print('Optimistically updating profile image to $newUrl');
                    _profileImageNotifier.updateProfileImage(newUrl);
                    setState(() {
                      _currentUser = _currentUser!.copyWith(
                        profileImageUrl: newUrl,
                      );
                    });
                  }
                  _loadUserData(); // still refetch to ensure consistency
                } else if (result == true) {
                  // Backward compatibility if we just returned true
                  _loadUserData();
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Picture Section
            Center(
              child: ProfileImageWidget(
                // Prefer model URL; if null fallback to global notifier current value
                imageUrl:
                    _currentUser!.profileImageUrl ??
                    _profileImageNotifier.currentImageId,
                radius: 60,
                placeholder: const Icon(
                  Icons.person,
                  size: 60,
                  color: Color(0xFF677583),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // User Name
            Text(
              _currentUser!.displayName,
              style: const TextStyle(
                color: Color(0xFF121417),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.015,
              ),
            ),

            const SizedBox(height: 8),

            // User Bio
            Text(
              _currentUser!.displayBio,
              style: const TextStyle(color: Color(0xFF677583), fontSize: 16),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            // Profile Information Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildInfoCard(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: _currentUser!.email,
                  ),
                  if (_currentUser!.phone != null) ...[
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      icon: Icons.phone_outlined,
                      title: 'Phone',
                      value: _currentUser!.phone!,
                    ),
                  ],
                  if (_currentUser!.occupation != null) ...[
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      icon: Icons.work_outline,
                      title: 'Occupation',
                      value: _currentUser!.occupation!,
                    ),
                  ],
                  if (_currentUser!.age != null) ...[
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      icon: Icons.cake_outlined,
                      title: 'Age',
                      value: '${_currentUser!.age} years old',
                    ),
                  ],
                  // Show join date
                  if (_currentUser!.createdAt != null) ...[
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      icon: Icons.calendar_today_outlined,
                      title: 'Member Since',
                      value: _formatDate(_currentUser!.createdAt!),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    _showLogoutDialog();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF121417),
                    side: const BorderSide(color: Color(0xFF677583)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F2F4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFADCBEA).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF121417), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF677583),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF121417),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(
              color: Color(0xFF121417),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Color(0xFF677583)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF677583)),
              ),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                try {
                  await _authService.signOut();
                  if (mounted) {
                    // Navigate back to login screen and clear all previous routes
                    navigator.pushNamedAndRemoveUntil('/', (route) => false);
                  }
                } catch (e) {
                  if (mounted) {
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error logging out: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

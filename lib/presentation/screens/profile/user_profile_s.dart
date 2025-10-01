import 'package:flutter/material.dart';
import 'package:roomie/data/models/user_model.dart';
import 'package:roomie/presentation/screens/profile/edit_profile_s.dart';
import 'package:roomie/data/datasources/auth_service.dart';
import 'package:roomie/data/datasources/firestore_service.dart';
import 'package:roomie/data/datasources/profile_image_notifier.dart';
import 'package:roomie/presentation/widgets/profile_image_widget.dart';

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
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Profile',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: -0.015,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Profile',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: -0.015,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
              SizedBox(height: 16),
              Text(
                'No user data found',
                style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
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
          'Profile',
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.015,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: colorScheme.primary),
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
                placeholder: Icon(
                  Icons.person,
                  size: 60,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // User Name
            Text(
              _currentUser!.displayName,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.015,
              ),
            ),

            const SizedBox(height: 8),

            // User Bio
            Text(
              _currentUser!.displayBio,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
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
                      foregroundColor: colorScheme.onSurface,
                      side: BorderSide(color: colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Logout',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;

        return AlertDialog(
          title: Text(
            'Logout',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
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
                        backgroundColor: colorScheme.error,
                      ),
                    );
                  }
                }
              },
              child: Text('Logout', style: TextStyle(color: colorScheme.error)),
            ),
          ],
        );
      },
    );
  }
}

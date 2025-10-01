import 'package:flutter/material.dart';
import 'package:roomie/data/datasources/auth_service.dart';
import 'package:roomie/data/datasources/firestore_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class UserDetailsScreen extends StatefulWidget {
  final bool isFromPhoneSignup;
  const UserDetailsScreen({super.key, this.isFromPhoneSignup = false});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _occupationController = TextEditingController();
  final _ageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  File? _profileImageFile;

  void _saveUserDetails() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authService = AuthService(); // Instantiate AuthService
        final user = authService.currentUser; // Access currentUser
        if (user != null) {
          await FirestoreService().saveUserProfile(
            userId: user.uid,
            username: _usernameController.text.trim(),
            bio: _bioController.text.trim(),
            email: user.email ?? '',
            phone: '',
            profileImage: _profileImageFile, // Use the selected image file
            occupation:
                _occupationController.text.trim().isEmpty
                    ? null
                    : _occupationController.text.trim(),
            age:
                _ageController.text.trim().isEmpty
                    ? null
                    : int.tryParse(_ageController.text.trim()),
          );

          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          }
        } else {
          // Handle case where user is null, though unlikely if coming from OTP screen
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User not logged in.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to save details: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _profileImageFile = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Form(
            // Wrap in Form to use GlobalKey
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Padding(
                  padding: const EdgeInsets.only(top: 24.0, bottom: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button and title row
                      Row(
                        children: [
                          GestureDetector(
                            onTap:
                                () => Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/login',
                                  (route) => false,
                                ),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                        color: colorScheme.onSurface.withAlpha(25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                                  child: Icon(
                                Icons.arrow_back_ios_new,
                                size: 18,
                                    color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'User Details',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                          ), // To balance the back button space
                        ],
                      ),
                    ],
                  ),
                ),

                // Form Fields
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Profile Photo uploader
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: GestureDetector(
                            onTap: _pickProfileImage,
                            child: Row(
                              children: [
                                _profileImageFile == null
                                    ? Container(
                                      height: 60,
                                      width: 60,
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person_outline,
                                        color: colorScheme.primary,
                                        size: 28,
                                      ),
                                    )
                                    : Container(
                                      height: 60,
                                      width: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: DecorationImage(
                                          image: FileImage(_profileImageFile!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                SizedBox(width: 16),
                                Text(
                                  _profileImageFile == null
                                      ? 'Add profile photo'
                                      : 'Change profile photo',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Username field
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              hintText: 'Username',
                              filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a username';
                              }
                              return null;
                            },
                          ),
                        ),

                        // Occupation field
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: TextFormField(
                            controller: _occupationController,
                            decoration: InputDecoration(
                              hintText: 'Occupation',
                              filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                          ),
                        ),

                        // Age field
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Age',
                              filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final age = int.tryParse(value);
                                if (age == null || age < 13 || age > 120) {
                                  return 'Please enter a valid age (13-120)';
                                }
                              }
                              return null;
                            },
                          ),
                        ),

                        // Bio field
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  bottom: 8,
                                ),
                                child: Text(
                                  'Bio (Optional)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              TextFormField(
                                controller: _bioController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Tell us about yourself...',
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  hintStyle: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Next button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child:
                        _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                                ),
                              )
                            : ElevatedButton(
                              onPressed: _saveUserDetails,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: Text(
                                'Next',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

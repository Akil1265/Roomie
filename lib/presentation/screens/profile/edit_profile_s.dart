import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roomie/data/datasources/firestore_service.dart';
import 'package:roomie/data/datasources/auth_service.dart';
import 'package:roomie/data/models/user_model.dart';
import 'package:roomie/presentation/widgets/profile_image_widget.dart';
import 'dart:io';


class EditProfileScreen extends StatefulWidget {
  final UserModel currentUser;

  const EditProfileScreen({super.key, required this.currentUser});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers for form fields
  late TextEditingController _usernameController;
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  late TextEditingController _occupationController;
  late TextEditingController _ageController;

  File? _selectedImage;
  XFile? _selectedXFile; // For web compatibility
  bool _isLoading = false;
  String? _currentProfileImageUrl;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current user data
    _usernameController = TextEditingController(
      text: widget.currentUser.username ?? '',
    );
    _nameController = TextEditingController(
      text: widget.currentUser.name ?? '',
    );
    _bioController = TextEditingController(text: widget.currentUser.bio ?? '');
    _phoneController = TextEditingController(
      text: widget.currentUser.phone ?? '',
    );
    _occupationController = TextEditingController(
      text: widget.currentUser.occupation ?? '',
    );
    _ageController = TextEditingController(
      text: widget.currentUser.age?.toString() ?? '',
    );
    _currentProfileImageUrl = widget.currentUser.profileImageUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _occupationController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _selectedXFile = image;
          // For mobile compatibility, also set File if not web
          if (!kIsWeb) {
            _selectedImage = File(image.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not found');

      // Parse age
      int? age;
      if (_ageController.text.isNotEmpty) {
        age = int.tryParse(_ageController.text);
        if (age == null) {
          throw Exception('Invalid age format');
        }
      }

      // Show a specific message if trying to upload image
      if (_selectedXFile != null) {
        if (mounted) {
          final colorScheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Uploading profile image...'),
              backgroundColor: colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // First save the profile with image (if new image selected)
      await _firestoreService.saveUserProfile(
        userId: user.uid,
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        email: widget.currentUser.email,
        phone: _phoneController.text.trim(),
        profileImage: _selectedXFile ?? _selectedImage, // Pass XFile or File
      );

      // Then update additional fields directly in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'name':
                _nameController.text.trim().isEmpty
                    ? null
                    : _nameController.text.trim(),
            'occupation':
                _occupationController.text.trim().isEmpty
                    ? null
                    : _occupationController.text.trim(),
            'age': age,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Fetch fresh doc to obtain latest profileImageUrl immediately
        final fresh = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final freshData = fresh.data();
        final freshUrl = freshData?['profileImageUrl'] as String?;
        if (mounted) {
          Navigator.of(context).pop({'profileImageUrl': freshUrl});
        }
      }
    } catch (e) {
      print('Error updating profile: $e'); // Add debugging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Profile',
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.015,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child:
                _isLoading
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onSurface),
                      ),
                    )
                    : Text(
                      'Save',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile Picture Section
              Center(
                child: Stack(
                  children: [
                    // Show selected image if user picked one, otherwise show current MongoDB profile image
                    ProfileImageWidget(
                      imageUrl: _currentProfileImageUrl,
                      localPreviewFile: !kIsWeb ? _selectedImage : null,
                      radius: 60,
                      placeholder: Icon(
                        Icons.person,
                        size: 60,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: colorScheme.onPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Profile Picture Status Text
              Text(
                _selectedXFile != null || _selectedImage != null
                    ? 'New image selected'
                    : (_currentProfileImageUrl != null &&
                            _currentProfileImageUrl!.isNotEmpty
                        ? 'Current profile image'
                        : 'No profile image'),
                style: TextStyle(
                  color: _selectedXFile != null || _selectedImage != null
                      ? colorScheme.secondary
                      : colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              // Form Fields
              _buildTextField(
                controller: _usernameController,
                label: 'Username',
                hint: 'Enter your username',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Enter your full name',
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _bioController,
                label: 'Bio',
                hint: 'Tell us about yourself',
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _phoneController,
                label: 'Phone',
                hint: 'Enter your phone number',
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _occupationController,
                label: 'Occupation',
                hint: 'Enter your occupation',
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _ageController,
                label: 'Age',
                hint: 'Enter your age',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final age = int.tryParse(value);
                    if (age == null || age < 18 || age > 100) {
                      return 'Please enter a valid age (18-100)';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.error),
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

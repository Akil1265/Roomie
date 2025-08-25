import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roomie/services/firestore_service.dart';
import 'package:roomie/services/auth_service.dart';
import 'package:roomie/models/user_model.dart';
import 'package:roomie/widgets/mongodb_profile_image.dart';
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
  late TextEditingController _locationController;
  late TextEditingController _occupationController;
  late TextEditingController _ageController;

  File? _selectedImage;
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
    _locationController = TextEditingController(
      text: widget.currentUser.location ?? '',
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
    _locationController.dispose();
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
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
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
      if (_selectedImage != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uploading profile image...'),
              backgroundColor: Colors.blue,
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
        profileImage: _selectedImage,
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
            'location':
                _locationController.text.trim().isEmpty
                    ? null
                    : _locationController.text.trim(),
            'occupation':
                _occupationController.text.trim().isEmpty
                    ? null
                    : _occupationController.text.trim(),
            'age': age,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      print('Error updating profile: $e'); // Add debugging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF121417)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF121417),
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.015,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF121417),
                      ),
                    )
                    : const Text(
                      'Save',
                      style: TextStyle(
                        color: Color(0xFF121417),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                    _selectedImage != null
                        ? CircleAvatar(
                          radius: 60,
                          backgroundColor: const Color(0xFFF1F2F4),
                          backgroundImage: FileImage(_selectedImage!),
                        )
                        : MongoDBProfileImage(
                          imageId: _currentProfileImageUrl,
                          radius: 60,
                          placeholder: const Icon(
                            Icons.person,
                            size: 60,
                            color: Color(0xFF677583),
                          ),
                        ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF121417),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
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
                _selectedImage != null
                    ? 'New image selected'
                    : (_currentProfileImageUrl != null &&
                            _currentProfileImageUrl!.isNotEmpty
                        ? 'Current profile image'
                        : 'No profile image'),
                style: TextStyle(
                  color:
                      _selectedImage != null
                          ? Colors.green
                          : const Color(0xFF677583),
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
                controller: _locationController,
                label: 'Location',
                hint: 'Enter your location',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF121417),
            fontSize: 16,
            fontWeight: FontWeight.w500,
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
            hintStyle: const TextStyle(color: Color(0xFF677583)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF1F2F4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF1F2F4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF121417)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: const TextStyle(color: Color(0xFF121417), fontSize: 16),
        ),
      ],
    );
  }
}

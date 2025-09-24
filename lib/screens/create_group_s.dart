import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roomie/services/groups_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFFE0E0E0)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    final path = Path();

    // Top border
    while (startX < size.width) {
      path.moveTo(startX, 0);
      path.lineTo(startX + dashWidth, 0);
      startX += dashWidth + dashSpace;
    }

    // Right border
    double startY = 0;
    while (startY < size.height) {
      path.moveTo(size.width, startY);
      path.lineTo(size.width, startY + dashWidth);
      startY += dashWidth + dashSpace;
    }

    // Bottom border
    startX = size.width;
    while (startX > 0) {
      path.moveTo(startX, size.height);
      path.lineTo(startX - dashWidth, size.height);
      startX -= dashWidth + dashSpace;
    }

    // Left border
    startY = size.height;
    while (startY > 0) {
      path.moveTo(0, startY);
      path.lineTo(0, startY - dashWidth);
      startY -= dashWidth + dashSpace;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _groupNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _memberCountController =
      TextEditingController(); // Now used for "Other Details"
  final _rentController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String? _webImagePath;
  bool _isLoading = false;
  final GroupsService _groupsService = GroupsService();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (kIsWeb) {
            _webImagePath = image.path;
            _selectedImage = null;
          } else {
            _selectedImage = File(image.path);
            _webImagePath = null;
          }
        });
        print('Image selected: ${image.path}');
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  void _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter a group name')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse other details to extract member count and max members if provided
      final otherDetails = _memberCountController.text.trim();
      int memberCount = 1; // Default member count
      int maxMembers = 4; // Default max members

      // Try to extract numbers from other details for backend compatibility
      final RegExp numberRegex = RegExp(r'\d+');
      final matches = numberRegex.allMatches(otherDetails);
      if (matches.length >= 2) {
        memberCount = int.tryParse(matches.first.group(0)!) ?? 1;
        maxMembers = int.tryParse(matches.elementAt(1).group(0)!) ?? 4;
      }

      final groupId = await _groupsService.createGroup(
        name: _groupNameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        memberCount: memberCount,
        maxMembers: maxMembers,
        rent: double.tryParse(_rentController.text.trim()),
        imageFile: _selectedImage,
      );

      if (groupId != null) {
  print('Group created successfully with ID: $groupId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Handle the case where groupId is null (connection failed)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Database connection failed. Please check your internet and try again.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Error creating group: $e');
      if (mounted) {
        // Generic error for other exceptions
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _locationController.dispose();
    _memberCountController.dispose();
    _rentController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: const TextStyle(color: Colors.black, fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create Group',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upload Cover Image Section
                    SizedBox(
                      width: double.infinity,
                      height: 200,
                      child: CustomPaint(
                        painter: DashedBorderPainter(),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              (_selectedImage != null || _webImagePath != null)
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        kIsWeb && _webImagePath != null
                                            ? Image.network(
                                              _webImagePath!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                return Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.error,
                                                    color: Colors.grey,
                                                  ),
                                                );
                                              },
                                            )
                                            : _selectedImage != null
                                            ? Image.file(
                                              _selectedImage!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            )
                                            : Container(
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.error,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: _pickImage,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.6,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Icon(
                                                Icons.edit,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  : GestureDetector(
                                    onTap: _pickImage,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.image_outlined,
                                            size: 28,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Upload Cover Image',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap to select an image for your group',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8E8E8),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'Choose Image',
                                            style: TextStyle(
                                              color: Color(0xFF666666),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Group Name Field
                    _buildTextField(
                      controller: _groupNameController,
                      hint: 'Group Name',
                    ),
                    const SizedBox(height: 16),

                    // Description Field
                    _buildTextField(
                      controller: _descriptionController,
                      hint: 'Description',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),

                    // Location Field
                    _buildTextField(
                      controller: _locationController,
                      hint: 'Location',
                    ),
                    const SizedBox(height: 16),

                    // Rent Amount Field
                    _buildTextField(
                      controller: _rentController,
                      hint: 'Rent Amount',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Other Details Field (combining member count fields)
                    _buildTextField(
                      controller: _memberCountController,
                      hint: 'Other Details',
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Create Group Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE8E8E8), width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isLoading
                          ? const Color(0xFFCCCCCC)
                          : const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  disabledBackgroundColor: const Color(0xFFCCCCCC),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Text(
                          'Create Group',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

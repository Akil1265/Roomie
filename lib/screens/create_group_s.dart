import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roomie/services/groups_service.dart';
import 'package:roomie/services/enhanced_geocoding_service.dart';
import 'package:roomie/widgets/perfect_location_picker_widget.dart';
import 'package:geolocator/geolocator.dart';
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
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _rentAmountController = TextEditingController();
  final _capacityController = TextEditingController();
  final _descriptionController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String? _webImagePath;
  XFile? _webImageFile;
  bool _isLoading = false;
  final GroupsService _groupsService = GroupsService();
  final EnhancedGeocodingService _geocodingService = EnhancedGeocodingService();

  // Test geocoding with known coordinates
  Future<void> _testGeocoding() async {
    // Test with Bangalore coordinates
    double testLat = 12.9716;
    double testLng = 77.5946;

    print('Testing geocoding with Bangalore coordinates: $testLat, $testLng');

    try {
      final address = await _geocodingService.coordinatesToAddress(
        testLat,
        testLng,
      );
      final locationData = await _geocodingService.coordinatesToLocationData(
        testLat,
        testLng,
      );

      print('Test Result - Address: $address');
      print('Test Result - City: ${locationData.city}');
      print('Test Result - State: ${locationData.state}');
      print('Test Result - Pincode: ${locationData.pincode}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test: ${locationData.city}, ${locationData.state}'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Test geocoding failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // New fields for enhanced room model
  String _selectedRoomType = '1BHK';
  String _selectedCurrency = 'INR';
  final List<String> _selectedAmenities = [];
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

  final List<String> _roomTypes = ['1BHK', '2BHK', '3BHK', 'Shared', 'PG'];
  final List<String> _currencies = ['INR', 'USD', 'EUR'];
  final List<String> _availableAmenities = [
    'WiFi',
    'Parking',
    'AC',
    'Washing Machine',
    'Refrigerator',
    'Microwave',
    'Gym',
    'Swimming Pool',
    'Security',
    'Power Backup',
    'Lift',
    'Balcony',
  ];

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
            _webImageFile = image;
            _selectedImage = null;
          } else {
            _selectedImage = File(image.path);
            _webImagePath = null;
            _webImageFile = null;
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

  // Get current position
  Future<Position?> _getCurrentPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied'),
            ),
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
    } catch (e) {
      print('Error getting position: $e');
      return null;
    }
  }

  // Current location method
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await _getCurrentPosition();
      if (position != null) {
        await _updateAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get current location: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _updateAddressFromCoordinates(double lat, double lng) async {
    try {
      print('Starting address conversion for: $lat, $lng');

      // Update coordinates first
      setState(() {
        _latitude = lat;
        _longitude = lng;
      });

      // Show loading state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Converting coordinates to address...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final address = await _geocodingService.coordinatesToAddress(lat, lng);
      final locationData = await _geocodingService.coordinatesToLocationData(
        lat,
        lng,
      );

      print('Converted address: $address');
      print(
        'LocationData: ${locationData.city}, ${locationData.state}, ${locationData.pincode}',
      );

      setState(() {
        _locationController.text = address;
        _cityController.text = locationData.city;
        _stateController.text = locationData.state;
        _pincodeController.text = locationData.pincode;
      });

      // Show success message with actual data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Address: ${locationData.city}, ${locationData.state}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error converting coordinates to address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Geocoding failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _openLocationPicker() async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => PerfectLocationPickerWidget(
                initialLocation: _locationController.text,
                onLocationSelected: (
                  address, {
                  double? lat,
                  double? lng,
                }) async {
                  setState(() {
                    _latitude = lat;
                    _longitude = lng;
                  });

                  // If we have coordinates, convert them to a proper address
                  if (lat != null && lng != null) {
                    await _updateAddressFromCoordinates(lat, lng);
                  } else {
                    // Fallback to the provided address
                    setState(() {
                      _locationController.text = address;
                      // Parse address components if possible
                      final parts = address.split(', ');
                      if (parts.length >= 2) {
                        _cityController.text = parts[parts.length - 2];
                        _stateController.text = parts.last;
                      }
                    });
                  }
                },
              ),
        ),
      );
    } catch (e) {
      print('Error opening location picker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening location picker: $e')),
        );
      }
    }
  }

  void _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a room name')));
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a location')));
      return;
    }

    if (_rentAmountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter rent amount')));
      return;
    }

    if (_capacityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter room capacity')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare the enhanced room data
      final rentAmount =
          double.tryParse(_rentAmountController.text.trim()) ?? 0.0;
      final capacity = int.tryParse(_capacityController.text.trim()) ?? 4;

      final groupId = await _groupsService.createGroup(
        name: _groupNameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        memberCount: 1, // Creator is the first member
        maxMembers: capacity,
        rent: rentAmount,
        imageFile: _selectedImage,
        webPicked: _webImageFile,
      );

      if (groupId != null) {
        print('Room created successfully with ID: $groupId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
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
      print('Error creating room: $e');
      if (mounted) {
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
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _rentAmountController.dispose();
    _capacityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildCleanTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    return GestureDetector(
      onTap:
          readOnly && suffixIcon != null ? () => _openLocationPicker() : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            suffixIcon: suffixIcon,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 18,
            ),
          ),
          style: const TextStyle(color: Color(0xFF121417), fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF121417),
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Create Group',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF121417),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40), // Balance the back button
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Upload Cover Image Section
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
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
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Upload Room Image',
                                      style: TextStyle(
                                        color: Color(0xFF121417),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to select an image for your room',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Choose Image',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                    ),

                    const SizedBox(height: 32),

                    // Form Fields
                    _buildCleanTextField(
                      controller: _groupNameController,
                      hint: 'Room Name',
                    ),
                    const SizedBox(height: 16),

                    _buildCleanTextField(
                      controller: _descriptionController,
                      hint: 'Description',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Room Type Dropdown
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButton<String>(
                        value: _selectedRoomType,
                        hint: const Text('Select Room Type'),
                        isExpanded: true,
                        underline: const SizedBox(),
                        items:
                            _roomTypes.map((String type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedRoomType = newValue!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildCleanTextField(
                            controller: _locationController,
                            hint: 'Full Address',
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.location_on,
                                color: Color(0xFF007AFF),
                                size: 20,
                              ),
                              onPressed: _openLocationPicker,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color:
                                _isLoadingLocation
                                    ? Colors.grey.shade100
                                    : const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            onPressed:
                                _isLoadingLocation ? null : _getCurrentLocation,
                            icon:
                                _isLoadingLocation
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.grey.shade600,
                                            ),
                                      ),
                                    )
                                    : const Icon(
                                      Icons.my_location,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                            tooltip: 'Use Current Location',
                          ),
                        ),
                      ],
                    ),

                    // Coordinates to Address Button
                    if (_latitude != null && _longitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'GPS: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                if (_latitude != null && _longitude != null) {
                                  _updateAddressFromCoordinates(
                                    _latitude!,
                                    _longitude!,
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.refresh,
                                size: 16,
                                color: Color(0xFF007AFF),
                              ),
                              label: const Text(
                                'Update Address',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                              ),
                            ),
                            // Test geocoding button
                            TextButton.icon(
                              onPressed: _testGeocoding,
                              icon: const Icon(
                                Icons.bug_report,
                                size: 16,
                                color: Colors.purple,
                              ),
                              label: const Text(
                                'Test',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Location Details Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildCleanTextField(
                            controller: _cityController,
                            hint: 'City',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCleanTextField(
                            controller: _stateController,
                            hint: 'State',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildCleanTextField(
                      controller: _pincodeController,
                      hint: 'Pincode',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Rent Amount and Currency Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildCleanTextField(
                            controller: _rentAmountController,
                            hint: 'Rent Amount',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: DropdownButton<String>(
                              value: _selectedCurrency,
                              hint: const Text('Currency'),
                              isExpanded: true,
                              underline: const SizedBox(),
                              items:
                                  _currencies.map((String currency) {
                                    return DropdownMenuItem<String>(
                                      value: currency,
                                      child: Text(currency),
                                    );
                                  }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedCurrency = newValue!;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildCleanTextField(
                      controller: _capacityController,
                      hint: 'Maximum Roommates',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Amenities Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Amenities',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF121417),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                _availableAmenities.map((amenity) {
                                  final isSelected = _selectedAmenities
                                      .contains(amenity);
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedAmenities.remove(amenity);
                                        } else {
                                          _selectedAmenities.add(amenity);
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? const Color(0xFF007AFF)
                                                : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? const Color(0xFF007AFF)
                                                  : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        amenity,
                                        style: TextStyle(
                                          color:
                                              isSelected
                                                  ? Colors.white
                                                  : Colors.grey.shade700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Create Group Button
          Container(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
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
                          'Create Room',
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

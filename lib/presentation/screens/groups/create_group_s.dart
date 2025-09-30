import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roomie/presentation/screens/location/map_picker_s.dart';
import 'package:roomie/data/datasources/enhanced_geocoding_service.dart';
import 'package:roomie/data/datasources/groups_service.dart';

import 'dart:io';

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
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _rentAmountController = TextEditingController();
  final _advanceAmountController = TextEditingController();
  final _capacityController = TextEditingController();
  final _descriptionController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  final List<XFile> _webImageFiles = [];
  final List<Uint8List> _webImageBytes = [];
  bool _isLoading = false;
  final GroupsService _groupsService = GroupsService();
  final EnhancedGeocodingService _geocodingService = EnhancedGeocodingService();

  // New fields for enhanced room model
  String _selectedRoomType = '1BHK';
  String _selectedCurrency = 'INR';
  int _selectedCapacity = 4;
  final List<String> _selectedAmenities = [];
  // ignore: unused_field
  double? _latitude;
  // ignore: unused_field
  double? _longitude;
  // ignore: unused_field
  bool _isLoadingLocation = false;

  final List<String> _roomTypes = ['1BHK', '2BHK', '3BHK', 'Shared', 'PG'];
  final List<String> _currencies = ['INR', 'USD', 'EUR'];
  final List<int> _capacityOptions = List<int>.generate(
    10,
    (index) => index + 1,
  );
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

  @override
  void initState() {
    super.initState();
    _capacityController.text = _selectedCapacity.toString();
  }

  Future<void> _pickImages() async {
    try {
      List<XFile> pickedImages = [];

      try {
        pickedImages = await _picker.pickMultiImage(
          maxWidth: 800,
          maxHeight: 600,
          imageQuality: 85,
        );
      } catch (error) {
        if (error is UnimplementedError || error is UnsupportedError) {
          final XFile? singleImage = await _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 800,
            maxHeight: 600,
            imageQuality: 85,
          );
          if (singleImage != null) {
            pickedImages = [singleImage];
          }
        } else {
          rethrow;
        }
      }

      if (pickedImages.isEmpty) {
        return;
      }

      const int maxImagesAllowed = 6;
      final bool exceededLimit = pickedImages.length > maxImagesAllowed;
      final List<XFile> limitedImages =
          pickedImages.take(maxImagesAllowed).toList();

      if (kIsWeb) {
        final List<Uint8List> bytesList = [];
        for (final image in limitedImages) {
          bytesList.add(await image.readAsBytes());
        }

        setState(() {
          _webImageFiles
            ..clear()
            ..addAll(limitedImages);
          _webImageBytes
            ..clear()
            ..addAll(bytesList);
          _selectedImages.clear();
        });
      } else {
        setState(() {
          _selectedImages
            ..clear()
            ..addAll(limitedImages.map((image) => File(image.path)));
          _webImageFiles.clear();
          _webImageBytes.clear();
        });
      }

      if (exceededLimit && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can upload up to 6 images only.')),
        );
      }

      print('Images selected: ${limitedImages.length}');
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  bool get _hasSelectedImages =>
      _selectedImages.isNotEmpty || _webImageFiles.isNotEmpty;

  File? get _primaryLocalImage =>
      _selectedImages.isNotEmpty ? _selectedImages.first : null;

  Uint8List? get _primaryWebImageBytes =>
      _webImageBytes.isNotEmpty ? _webImageBytes.first : null;

  Widget _buildPrimaryImagePreview() {
    if (kIsWeb && _primaryWebImageBytes != null) {
      return Image.memory(
        _primaryWebImageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (_primaryLocalImage != null) {
      return Image.file(
        _primaryLocalImage!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.error, color: Colors.grey),
    );
  }

  Widget _buildImagePreviews() {
    if (!_hasSelectedImages) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: kIsWeb ? _webImageBytes.length : _selectedImages.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _showImagePreview(index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child:
                          kIsWeb
                              ? Image.memory(
                                _webImageBytes[index],
                                fit: BoxFit.cover,
                              )
                              : Image.file(
                                _selectedImages[index],
                                fit: BoxFit.cover,
                              ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeImage(index),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      if (kIsWeb) {
        _webImageBytes.removeAt(index);
        _webImageFiles.removeAt(index);
      } else {
        _selectedImages.removeAt(index);
      }
    });
  }

  void _showImagePreview(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child:
                kIsWeb
                    ? Image.memory(_webImageBytes[index], fit: BoxFit.contain)
                    : Image.file(_selectedImages[index], fit: BoxFit.contain),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _showCapacityPicker() async {
    final initialIndex = _capacityOptions.indexOf(_selectedCapacity);
    final initialItem = initialIndex >= 0 ? initialIndex : 0;
    int tempSelection = _selectedCapacity;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: Text(
                    'Select Roommates Count',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: initialItem,
                    ),
                    magnification: 1.05,
                    squeeze: 1.1,
                    itemExtent: 38,
                    useMagnifier: true,
                    onSelectedItemChanged: (index) {
                      tempSelection = _capacityOptions[index];
                    },
                    children:
                        _capacityOptions
                            .map(
                              (value) => Center(
                                child: Text(
                                  value.toString(),
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: const BorderSide(color: Color(0xFFE0E0E0)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCapacity = tempSelection;
                              _capacityController.text =
                                  _selectedCapacity.toString();
                            });
                            Navigator.pop(sheetContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
  // ignore: unused_element
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

      final street =
          locationData.address.isNotEmpty ? locationData.address : address;

      setState(() {
        _addressController.text = street;
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
              (context) => MapPickerScreen(
                onLocationSelected: (address, lat, lng) {
                  _updateAddressFromCoordinates(lat, lng);
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

    final streetText = _addressController.text.trim();
    if (streetText.isEmpty) {
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
        const SnackBar(content: Text('Please select room capacity')),
      );
      return;
    }

    if (_advanceAmountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter advance amount')),
      );
      return;
    }

    if (_selectedImages.isEmpty && _webImageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one image')),
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
      final advanceAmount =
          double.tryParse(_advanceAmountController.text.trim()) ?? 0.0;
      final locationParts =
          <String>[
            streetText,
            _cityController.text.trim(),
            _stateController.text.trim(),
            _pincodeController.text.trim(),
          ].where((part) => part.isNotEmpty).toList();
      final combinedLocation = locationParts.join(', ');

      final groupId = await _groupsService.createGroup(
        name: _groupNameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: combinedLocation.isNotEmpty ? combinedLocation : streetText,
        memberCount: 1,
        maxMembers: _selectedCapacity,
        rentAmount: rentAmount,
        rentCurrency: _selectedCurrency,
        advanceAmount: advanceAmount,
        roomType: _selectedRoomType,
        amenities: _selectedAmenities,
        imageFiles: _selectedImages,
        webPickedFiles: _webImageFiles,
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
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _rentAmountController.dispose();
    _advanceAmountController.dispose();
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
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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

  Widget _buildCleanDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButton<T>(
        value: value,
        hint: Text(
          hint,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF757575)),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        items: items,
        onChanged: onChanged,
        style: const TextStyle(color: Color(0xFF121417), fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Title
              const Text(
                'Create Group',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF121417),
                ),
              ),
              const SizedBox(height: 24),

              // Enhanced Image Picker
              GestureDetector(
                onTap: _pickImages,
                child: CustomPaint(
                  painter: DashedBorderPainter(),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child:
                          _hasSelectedImages
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(11.0),
                                child: _buildPrimaryImagePreview(),
                              )
                              : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 48,
                                    color: Color(0xFFBDBDBD),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Upload Room Images',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF757575),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Supports: JPG, PNG, JPEG (max 6)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFBDBDBD),
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Image Previews
              _buildImagePreviews(),

              const SizedBox(height: 24),

              // Group Name
              const Text(
                'Group Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF121417),
                ),
              ),
              const SizedBox(height: 8),
              _buildCleanTextField(
                controller: _groupNameController,
                hint: 'Enter a name for your group',
              ),
              const SizedBox(height: 16),

              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF121417),
                ),
              ),
              const SizedBox(height: 8),
              _buildCleanTextField(
                controller: _descriptionController,
                hint: 'Enter a brief description',
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Room Type
              const Text(
                'Room Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF121417),
                ),
              ),
              const SizedBox(height: 8),
              _buildCleanDropdown<String>(
                value: _selectedRoomType,
                hint: 'Select Room Type',
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
              const SizedBox(height: 16),

              // Location
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF121417),
                ),
              ),
              const SizedBox(height: 8),
              _buildCleanTextField(
                controller: _addressController,
                hint: 'Search or pick a location',
                readOnly: true,
                onTap: _openLocationPicker,
                suffixIcon: InkWell(
                  onTap: _openLocationPicker,
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF007AFF),
                    size: 22,
                  ),
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

              // Rent, Currency, and Roommates Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rent Amount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF121417),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCleanTextField(
                          controller: _rentAmountController,
                          hint: 'Enter monthly...',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Advance Amount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF121417),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCleanTextField(
                          controller: _advanceAmountController,
                          hint: 'Enter refundable dep',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Currency',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF121417),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCleanDropdown<String>(
                          value: _selectedCurrency,
                          hint: 'Currency',
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Roommates',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF121417),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCleanTextField(
                          controller: _capacityController,
                          hint: 'Enter count',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amenities Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
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
                            final isSelected = _selectedAmenities.contains(
                              amenity,
                            );
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

              // Create Group Button
              SizedBox(
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
            ],
          ),
        ),
      ),
    );
  }
}

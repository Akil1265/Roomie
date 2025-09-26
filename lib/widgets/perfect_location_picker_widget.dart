import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class PerfectLocationPickerWidget extends StatefulWidget {
  final String? initialLocation;
  final Function(String address) onLocationSelected;

  const PerfectLocationPickerWidget({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<PerfectLocationPickerWidget> createState() => _PerfectLocationPickerWidgetState();
}

class _PerfectLocationPickerWidgetState extends State<PerfectLocationPickerWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _selectedAddress = '';
  bool _isGettingCurrentLocation = false;
  List<String> _searchSuggestions = [];
  bool _showSuggestions = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    
    if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
      _searchController.text = widget.initialLocation!;
      _selectedAddress = widget.initialLocation!;
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingCurrentLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isGettingCurrentLocation = false;
        });
        _showError('Location services are disabled. Please enable GPS in your device settings.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isGettingCurrentLocation = false;
          });
          _showError('Location permission denied. Please allow location access.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isGettingCurrentLocation = false;
        });
        _showError('Location permission permanently denied. Please enable in device settings.');
        return;
      }

      // Get current position with timeout and fallback settings
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        ).timeout(const Duration(seconds: 20));
      } catch (e) {
        // Try with lower accuracy if high accuracy fails
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          ).timeout(const Duration(seconds: 15));
        } catch (e2) {
          // Final fallback with lowest accuracy
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 5),
            ),
          ).timeout(const Duration(seconds: 10));
        }
      }

      // Get address from coordinates
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          List<String> addressParts = [];
          
          // Build a more complete address
          if (place.name != null && place.name!.isNotEmpty) {
            addressParts.add(place.name!);
          }
          if (place.street != null && place.street!.isNotEmpty && place.street != place.name) {
            addressParts.add(place.street!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
            addressParts.add(place.subAdministrativeArea!);
          }
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }
          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            addressParts.add(place.postalCode!);
          }
          if (place.country != null && place.country!.isNotEmpty) {
            addressParts.add(place.country!);
          }
          
          String address = addressParts.isNotEmpty 
              ? addressParts.join(', ')
              : 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
          
          setState(() {
            _selectedAddress = address;
            _searchController.text = address;
            _isGettingCurrentLocation = false;
          });

          _showSuccess('Current location address found!');
        } else {
          // No placemarks found, try reverse geocoding with different approach
          await Future.delayed(const Duration(seconds: 1)); // Wait a bit
          List<Placemark> retryPlacemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          
          if (retryPlacemarks.isNotEmpty) {
            final place = retryPlacemarks.first;
            String address = '${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}';
            if (address.trim() == ', ,') {
              address = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
            }
            
            setState(() {
              _selectedAddress = address;
              _searchController.text = address;
              _isGettingCurrentLocation = false;
            });
            _showSuccess('Current location found!');
          } else {
            // Final fallback to coordinates
            String address = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
            setState(() {
              _selectedAddress = address;
              _searchController.text = address;
              _isGettingCurrentLocation = false;
            });
            _showSuccess('Location found (address lookup failed)');
          }
        }
      } catch (e) {
        print('Address lookup error: $e');
        // Address lookup failed, but we still have coordinates
        // Let's try a simple approach by using the coordinates to get basic location info
        try {
          // Wait a moment and try again with a different approach
          await Future.delayed(const Duration(milliseconds: 500));
          List<Placemark> fallbackPlacemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          
          if (fallbackPlacemarks.isNotEmpty) {
            final place = fallbackPlacemarks.first;
            String simpleAddress = '';
            
            if (place.locality != null && place.locality!.isNotEmpty) {
              simpleAddress += place.locality!;
            }
            if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
              if (simpleAddress.isNotEmpty) simpleAddress += ', ';
              simpleAddress += place.administrativeArea!;
            }
            if (place.country != null && place.country!.isNotEmpty) {
              if (simpleAddress.isNotEmpty) simpleAddress += ', ';
              simpleAddress += place.country!;
            }
            
            if (simpleAddress.isEmpty) {
              simpleAddress = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
            }
            
            setState(() {
              _selectedAddress = simpleAddress;
              _searchController.text = simpleAddress;
              _isGettingCurrentLocation = false;
            });
            _showSuccess('Location address found!');
          } else {
            // Use coordinates as final fallback
            String address = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
            setState(() {
              _selectedAddress = address;
              _searchController.text = address;
              _isGettingCurrentLocation = false;
            });
            _showSuccess('Location found (showing coordinates)');
          }
        } catch (e2) {
          // Final fallback to coordinates
          String address = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
          setState(() {
            _selectedAddress = address;
            _searchController.text = address;
            _isGettingCurrentLocation = false;
          });
          _showSuccess('Location found (address service unavailable)');
        }
      }

    } catch (e) {
      setState(() {
        _isGettingCurrentLocation = false;
      });
      String errorMessage = 'Error getting current location: ';
      if (e.toString().contains('TimeoutException')) {
        errorMessage += 'Location request timed out. Please try again.';
      } else if (e.toString().contains('LocationServiceDisabledException')) {
        errorMessage += 'Location services are disabled. Please enable GPS.';
      } else if (e.toString().contains('PermissionDeniedException')) {
        errorMessage += 'Location permission denied. Please allow location access.';
      } else {
        errorMessage += e.toString();
      }
      _showError(errorMessage);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _showSuggestions = false;
        _searchSuggestions = [];
      });
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        // Get addresses for the found locations
        List<String> suggestions = [];
        for (Location location in locations.take(3)) {
          try {
            List<Placemark> placemarks = await placemarkFromCoordinates(
              location.latitude,
              location.longitude,
            );
            if (placemarks.isNotEmpty) {
              final place = placemarks.first;
              List<String> addressParts = [];
              
              if (place.street != null && place.street!.isNotEmpty) {
                addressParts.add(place.street!);
              }
              if (place.locality != null && place.locality!.isNotEmpty) {
                addressParts.add(place.locality!);
              }
              if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
                addressParts.add(place.administrativeArea!);
              }
              
              String address = addressParts.join(', ');
              if (address.isNotEmpty) {
                suggestions.add(address);
              }
            }
          } catch (e) {
            // Continue to next location if this one fails
            continue;
          }
        }
        
        setState(() {
          _searchSuggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      setState(() {
        _showSuggestions = false;
        _searchSuggestions = [];
      });
    }
  }

  void _selectSuggestion(String suggestion) {
    setState(() {
      _selectedAddress = suggestion;
      _searchController.text = suggestion;
      _showSuggestions = false;
      _searchSuggestions = [];
    });
  }

  void _showManualLocationDialog() {
    final TextEditingController manualController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Location Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('If GPS is not working, you can enter your location manually:'),
            const SizedBox(height: 16),
            TextField(
              controller: manualController,
              decoration: const InputDecoration(
                hintText: 'Enter your city, address, or location...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (manualController.text.trim().isNotEmpty) {
                setState(() {
                  _selectedAddress = manualController.text.trim();
                  _searchController.text = manualController.text.trim();
                });
                Navigator.pop(context);
                _showSuccess('Location entered manually!');
              }
            },
            child: const Text('Use This Location'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Top App Bar (like Google Office Locations)
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title
                  const Expanded(
                    child: Text(
                      'Select Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area - Map Visual Style
            Expanded(
              child: Stack(
                children: [
                  // Map-like Background
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF4285F4), // Google Blue
                          Color(0xFF34A853), // Google Green
                          Color(0xFF1976D2), // Darker Blue
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Grid pattern to mimic map
                        CustomPaint(
                          size: Size(MediaQuery.of(context).size.width, 400),
                          painter: MapGridPainter(),
                        ),
                        // Map markers/pins scattered around
                        ...List.generate(8, (index) {
                          final positions = [
                            const Offset(0.2, 0.3),
                            const Offset(0.7, 0.2),
                            const Offset(0.15, 0.7),
                            const Offset(0.8, 0.6),
                            const Offset(0.5, 0.4),
                            const Offset(0.3, 0.8),
                            const Offset(0.9, 0.3),
                            const Offset(0.1, 0.5),
                          ];
                          return Positioned(
                            left: MediaQuery.of(context).size.width * positions[index].dx,
                            top: 200 * positions[index].dy,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }),
                        // Center location icon
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Main Location Pin
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Location Text
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'Tap to select location',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Current Location Button (Floating, exactly like reference)
                  Positioned(
                    right: 16,
                    bottom: 120,
                    child: Column(
                      children: [
                        // GPS Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _isGettingCurrentLocation ? null : _getCurrentLocation,
                            icon: _isGettingCurrentLocation
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.blue,
                                    ),
                                  )
                                : const Icon(
                                    Icons.my_location,
                                    color: Colors.blue,
                                    size: 24,
                                  ),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Manual Entry Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _showManualLocationDialog,
                            icon: const Icon(
                              Icons.edit_location_alt,
                              color: Colors.green,
                              size: 24,
                            ),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Search Panel (exactly like Google Maps reference)
            Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Field (exactly like your reference)
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _selectedAddress = value;
                      });
                      _searchLocation(value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search for a location...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {
                                  _selectedAddress = '';
                                  _showSuggestions = false;
                                  _searchSuggestions = [];
                                });
                              },
                              child: const Icon(
                                Icons.clear,
                                color: Colors.grey,
                                size: 20,
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  
                  // Search Suggestions (dropdown like Google Maps)
                  if (_showSuggestions && _searchSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _searchSuggestions[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on, color: Colors.blue, size: 20),
                            title: Text(
                              suggestion,
                              style: const TextStyle(fontSize: 14),
                            ),
                            onTap: () => _selectSuggestion(suggestion),
                          );
                        },
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Selected Location Display (shows address in text like reference)
                  if (_selectedAddress.isNotEmpty) ...[
                    const Text(
                      'Selected Location:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.blue.shade600, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedAddress,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedAddress.isNotEmpty
                          ? () {
                              widget.onLocationSelected(_selectedAddress);
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: const Text(
                        'Confirm Location',
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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

// Custom painter for map-like grid pattern
class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 0.5;

    // Draw grid lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
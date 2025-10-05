import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchMapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final double radiusKm;

  const SearchMapPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.radiusKm = 5.0,
  });

  @override
  State<SearchMapPickerScreen> createState() => _SearchMapPickerScreenState();
}

class _SearchMapPickerScreenState extends State<SearchMapPickerScreen> {
  GoogleMapController? _mapController;
  late LatLng _selectedLocation;
  late double _radiusKm;
  Marker? _selectedMarker;
  Circle? _radiusCircle;
  bool _isLoadingLocation = false;
  String _locationName = '';
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(
      widget.initialLat ?? 13.0827, // Default Chennai
      widget.initialLng ?? 80.2707,
    );
    _radiusKm = widget.radiusKm;
    _updateMarkerAndCircle();
    _getAddressFromLatLng(_selectedLocation);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _updateMarkerAndCircle();
    });
    _getAddressFromLatLng(location);
  }

  void _updateMarkerAndCircle() {
    setState(() {
      _selectedMarker = Marker(
        markerId: const MarkerId('selectedLocation'),
        position: _selectedLocation,
        infoWindow: InfoWindow(
          title: _locationName.isEmpty ? 'Selected Location' : _locationName,
          snippet: '${_radiusKm.toStringAsFixed(1)} km radius',
        ),
      );

      _radiusCircle = Circle(
        circleId: const CircleId('searchRadius'),
        center: _selectedLocation,
        radius: _radiusKm * 1000, // Convert km to meters
        fillColor: Colors.blue.withValues(alpha: 0.2),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      );
    });
  }

  Future<void> _getAddressFromLatLng(LatLng location) async {
    setState(() => _isLoadingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final name = placemark.name ?? '';
        final locality = placemark.locality ?? '';
        final area = placemark.subLocality ?? '';
        
        setState(() {
          _locationName = [name, area, locality]
              .where((s) => s.isNotEmpty)
              .take(2)
              .join(', ');
        });
        _updateMarkerAndCircle();
      }
    } catch (e) {
      setState(() => _locationName = 'Unknown location');
    } finally {
      setState(() => _isLoadingAddress = false);
    }
  }

  void _confirmSelection() {
    Navigator.pop(context, {
      'lat': _selectedLocation.latitude,
      'lng': _selectedLocation.longitude,
      'radius': _radiusKm,
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions denied')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final currentLocation = LatLng(position.latitude, position.longitude);
      _onTap(currentLocation);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocation, 14),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location & Radius'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _confirmSelection,
            tooltip: 'Confirm',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 13,
            ),
            onTap: _onTap,
            markers: _selectedMarker != null ? {_selectedMarker!} : {},
            circles: _radiusCircle != null ? {_radiusCircle!} : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),

          // Top info card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: cs.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _isLoadingAddress
                              ? const Text('Loading...')
                              : Text(
                                  _locationName.isEmpty
                                      ? 'Tap on map to select'
                                      : _locationName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${_selectedLocation.latitude.toStringAsFixed(4)}, '
                      'Lng: ${_selectedLocation.longitude.toStringAsFixed(4)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom radius slider card
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Search Radius',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_radiusKm.toStringAsFixed(1)} km',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      min: 1,
                      max: 50,
                      divisions: 49,
                      value: _radiusKm.clamp(1, 50),
                      onChanged: (v) {
                        setState(() {
                          _radiusKm = v;
                          _updateMarkerAndCircle();
                        });
                      },
                    ),
                    Text(
                      'Drag slider to adjust search radius',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'streetView',
            onPressed: _openStreetView,
            child: const Icon(Icons.streetview),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'myLocation',
            onPressed: _isLoadingLocation ? null : _getCurrentLocation,
            child: _isLoadingLocation
                ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  Future<void> _openStreetView() async {
    final lat = _selectedLocation.latitude;
    final lng = _selectedLocation.longitude;
    final uri = Uri.parse('google.streetview:cbll=$lat,$lng');
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web browser
        final webUri = Uri.parse(
          'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng',
        );
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not launch Street View')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

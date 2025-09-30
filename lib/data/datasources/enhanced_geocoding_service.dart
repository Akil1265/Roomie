import 'package:geocoding/geocoding.dart';
import 'package:roomie/data/models/group_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class EnhancedGeocodingService {
  static final EnhancedGeocodingService _instance =
      EnhancedGeocodingService._internal();
  factory EnhancedGeocodingService() => _instance;
  EnhancedGeocodingService._internal();

  /// Convert coordinates to LocationData using multiple fallback methods
  Future<LocationData> coordinatesToLocationData(double lat, double lng) async {
    // Method 1: Try the standard geocoding package
    try {
      final result = await _tryStandardGeocoding(lat, lng);
      if (result != null && result.city != 'Unknown City') {
        return result;
      }
    } catch (e) {
      print('Standard geocoding failed: $e');
    }

    // Method 2: Try alternative geocoding service
    try {
      final result = await _tryAlternativeGeocoding(lat, lng);
      if (result != null) {
        return result;
      }
    } catch (e) {
      print('Alternative geocoding failed: $e');
    }

    // Method 3: Use coordinate-based estimation
    return _getCoordinateBasedLocation(lat, lng);
  }

  /// Standard geocoding with better error handling
  Future<LocationData?> _tryStandardGeocoding(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      for (var place in placemarks) {
        print('=== Placemark ${placemarks.indexOf(place) + 1} ===');
        print('Name: "${place.name}"');
        print('Street: "${place.street}"');
        print('Locality: "${place.locality}"');
        print('SubLocality: "${place.subLocality}"');
        print('AdminArea: "${place.administrativeArea}"');
        print('SubAdminArea: "${place.subAdministrativeArea}"');
        print('PostalCode: "${place.postalCode}"');
        print('Country: "${place.country}"');
        print('ISOCountryCode: "${place.isoCountryCode}"');
        print('ThoroughFare: "${place.thoroughfare}"');
        print('SubThoroughFare: "${place.subThoroughfare}"');

        String address = _buildAddress(place);
        String city = _extractCity(place);
        String state = place.administrativeArea ?? 'Unknown State';
        String pincode = place.postalCode ?? '000000';

        print(
          'Extracted - City: "$city", State: "$state", Pincode: "$pincode"',
        );

        // If we got any useful data, return it
        if (city != 'Unknown City' ||
            state != 'Unknown State' ||
            pincode != '000000') {
          return LocationData(
            address: address,
            city: city,
            state: state,
            pincode: pincode,
            coordinates: CoordinatesData(lat: lat, lng: lng),
          );
        }
      }
    } catch (e) {
      print('Standard geocoding error: $e');
    }
    return null;
  }

  /// Extract city from placemark with multiple fallback options
  String _extractCity(Placemark place) {
    // Try different fields in priority order
    String? city;

    // Priority 1: Direct locality
    if (place.locality != null && place.locality!.isNotEmpty) {
      city = place.locality;
    }
    // Priority 2: Sub-administrative area (often contains city)
    else if (place.subAdministrativeArea != null &&
        place.subAdministrativeArea!.isNotEmpty) {
      city = place.subAdministrativeArea;
    }
    // Priority 3: Sub-locality
    else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      city = place.subLocality;
    }
    // Priority 4: Try to extract from thoroughfare or name
    else if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
      // Sometimes city is embedded in thoroughfare
      final parts = place.thoroughfare!.split(',');
      if (parts.length > 1) {
        city = parts.last.trim();
      }
    }
    // Priority 5: Try to extract from name field
    else if (place.name != null && place.name!.isNotEmpty) {
      // Sometimes city is in the name field
      final parts = place.name!.split(',');
      if (parts.length > 1) {
        city = parts.last.trim();
      }
    }

    // Clean up the city name
    if (city != null) {
      city = city.trim();
      // Remove common suffixes that might appear
      city = city.replaceAll(
        RegExp(r'\s+(District|Dist|City)$', caseSensitive: false),
        '',
      );

      // If it's still not empty and reasonable length
      if (city.isNotEmpty && city.length > 1 && city.length < 50) {
        return city;
      }
    }

    return 'Unknown City';
  }

  /// Build address from placemark
  String _buildAddress(Placemark place) {
    List<String> parts = [];

    if (place.street != null && place.street!.isNotEmpty) {
      parts.add(place.street!);
    } else if (place.name != null && place.name!.isNotEmpty) {
      parts.add(place.name!);
    }

    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      parts.add(place.subLocality!);
    }

    return parts.isNotEmpty ? parts.join(', ') : 'Address not found';
  }

  /// Alternative geocoding using OpenStreetMap Nominatim (free service)
  Future<LocationData?> _tryAlternativeGeocoding(double lat, double lng) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {'User-Agent': 'Roomie-Flutter-App/1.0'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          String displayName = data['display_name'] ?? 'Address not found';
          String city =
              address['city'] ??
              address['town'] ??
              address['village'] ??
              address['hamlet'] ??
              'Unknown City';
          String state = address['state'] ?? 'Unknown State';
          String pincode = address['postcode'] ?? '000000';

          // Create a cleaner address
          List<String> addressParts = [];
          if (address['house_number'] != null) {
            addressParts.add(address['house_number']);
          }
          if (address['road'] != null) {
            addressParts.add(address['road']);
          }
          if (address['suburb'] != null) {
            addressParts.add(address['suburb']);
          }

          String cleanAddress =
              addressParts.isNotEmpty
                  ? addressParts.join(', ')
                  : displayName.split(',').take(2).join(', ');

          return LocationData(
            address: cleanAddress,
            city: city,
            state: state,
            pincode: pincode,
            coordinates: CoordinatesData(lat: lat, lng: lng),
          );
        }
      }
    } catch (e) {
      print('Alternative geocoding error: $e');
    }
    return null;
  }

  /// Coordinate-based location estimation for Indian coordinates
  LocationData _getCoordinateBasedLocation(double lat, double lng) {
    String city = 'Unknown City';
    String state = 'Unknown State';

    // Basic coordinate-based city detection for major Indian cities
    if (lat >= 12.8 && lat <= 13.1 && lng >= 77.5 && lng <= 77.7) {
      city = 'Bangalore';
      state = 'Karnataka';
    } else if (lat >= 19.0 && lat <= 19.3 && lng >= 72.7 && lng <= 73.0) {
      city = 'Mumbai';
      state = 'Maharashtra';
    } else if (lat >= 28.4 && lat <= 28.8 && lng >= 77.0 && lng <= 77.4) {
      city = 'New Delhi';
      state = 'Delhi';
    } else if (lat >= 22.4 && lat <= 22.7 && lng >= 88.2 && lng <= 88.5) {
      city = 'Kolkata';
      state = 'West Bengal';
    } else if (lat >= 13.0 && lat <= 13.2 && lng >= 80.1 && lng <= 80.3) {
      city = 'Chennai';
      state = 'Tamil Nadu';
    } else if (lat >= 17.3 && lat <= 17.5 && lng >= 78.3 && lng <= 78.6) {
      city = 'Hyderabad';
      state = 'Telangana';
    } else if (lat >= 23.0 && lat <= 23.3 && lng >= 72.4 && lng <= 72.7) {
      city = 'Ahmedabad';
      state = 'Gujarat';
    } else if (lat >= 18.4 && lat <= 18.7 && lng >= 73.7 && lng <= 74.0) {
      city = 'Pune';
      state = 'Maharashtra';
    }

    return LocationData(
      address: 'Location near $city',
      city: city,
      state: state,
      pincode: '000000',
      coordinates: CoordinatesData(lat: lat, lng: lng),
    );
  }

  /// Simple address string conversion
  Future<String> coordinatesToAddress(double lat, double lng) async {
    final locationData = await coordinatesToLocationData(lat, lng);
    return locationData.address;
  }
}

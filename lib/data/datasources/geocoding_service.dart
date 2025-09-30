import 'package:geocoding/geocoding.dart';
import 'package:roomie/data/models/group_model.dart';

class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  /// Convert coordinates to a human-readable address
  Future<String> coordinatesToAddress(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        // Build a comprehensive address string with proper priority
        List<String> addressParts = [];

        // Add street address first (most specific)
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        } else if (place.name != null && place.name!.isNotEmpty) {
          addressParts.add(place.name!);
        }

        // Add sub-locality
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }

        // Add locality (city)
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }

        // Add state
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }

        // Add country if needed
        if (place.country != null &&
            place.country!.isNotEmpty &&
            place.country != 'India') {
          addressParts.add(place.country!);
        }

        if (addressParts.isNotEmpty) {
          return addressParts.join(', ');
        }
      }
    } catch (e) {
      print('Error in reverse geocoding: $e');
      // Try once more after a delay
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        List<Placemark> retryPlacemarks = await placemarkFromCoordinates(
          lat,
          lng,
        );
        if (retryPlacemarks.isNotEmpty) {
          final place = retryPlacemarks.first;
          return place.street ?? place.name ?? 'Address not found';
        }
      } catch (retryError) {
        print('Retry address conversion failed: $retryError');
      }
    }

    // Fallback to coordinates if geocoding fails
    return 'Coordinates: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// Convert coordinates to LocationData with all components
  Future<LocationData> coordinatesToLocationData(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        // Debug print to see what we're getting
        print('Geocoding result: ${place.toString()}');
        print('Name: ${place.name}');
        print('Street: ${place.street}');
        print('Locality: ${place.locality}');
        print('SubLocality: ${place.subLocality}');
        print('AdminArea: ${place.administrativeArea}');
        print('SubAdminArea: ${place.subAdministrativeArea}');
        print('PostalCode: ${place.postalCode}');
        print('Country: ${place.country}');

        // Build detailed address with priority order
        List<String> addressParts = [];

        // Add street/name
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        } else if (place.name != null && place.name!.isNotEmpty) {
          addressParts.add(place.name!);
        }

        // Add sub-locality if available
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }

        String fullAddress =
            addressParts.isNotEmpty
                ? addressParts.join(', ')
                : 'Address not found';

        // Extract city with fallback options
        String city =
            place.locality ??
            place.subAdministrativeArea ??
            place.subLocality ??
            'Unknown City';

        // Extract state
        String state = place.administrativeArea ?? 'Unknown State';

        // Extract pincode
        String pincode = place.postalCode ?? '000000';

        // If we still have unknown values, try alternative approaches
        if (city == 'Unknown City' || state == 'Unknown State') {
          // Try with different placemarks if available
          for (var i = 1; i < placemarks.length && i < 3; i++) {
            final altPlace = placemarks[i];
            if (city == 'Unknown City' && altPlace.locality != null) {
              city = altPlace.locality!;
            }
            if (state == 'Unknown State' &&
                altPlace.administrativeArea != null) {
              state = altPlace.administrativeArea!;
            }
            if (pincode == '000000' && altPlace.postalCode != null) {
              pincode = altPlace.postalCode!;
            }
          }
        }

        return LocationData(
          address: fullAddress,
          city: city,
          state: state,
          pincode: pincode,
          coordinates: CoordinatesData(lat: lat, lng: lng),
        );
      }
    } catch (e) {
      print('Error creating LocationData from coordinates: $e');
      // Try a different approach with error handling
      try {
        // Sometimes the first call fails, try again with a slight delay
        await Future.delayed(const Duration(milliseconds: 500));
        List<Placemark> retryPlacemarks = await placemarkFromCoordinates(
          lat,
          lng,
        );
        if (retryPlacemarks.isNotEmpty) {
          final place = retryPlacemarks.first;
          return LocationData(
            address: place.street ?? place.name ?? 'Address not available',
            city:
                place.locality ??
                place.subAdministrativeArea ??
                'City not found',
            state: place.administrativeArea ?? 'State not found',
            pincode: place.postalCode ?? '000000',
            coordinates: CoordinatesData(lat: lat, lng: lng),
          );
        }
      } catch (retryError) {
        print('Retry geocoding also failed: $retryError');
      }
    }

    // Final fallback LocationData
    return LocationData(
      address: 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
      city: 'Geocoding Failed',
      state: 'Please try again',
      pincode: '000000',
      coordinates: CoordinatesData(lat: lat, lng: lng),
    );
  }

  /// Get a short address format (City, State)
  Future<String> coordinatesToShortAddress(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String city =
            place.locality ?? place.subAdministrativeArea ?? 'Unknown';
        String state = place.administrativeArea ?? 'Unknown';
        return '$city, $state';
      }
    } catch (e) {
      print('Error getting short address: $e');
    }

    return 'Unknown Location';
  }

  /// Check if geocoding service is available
  Future<bool> isGeocodingAvailable() async {
    try {
      // Test with a known location (Google HQ)
      await placemarkFromCoordinates(37.4219999, -122.0840575);
      return true;
    } catch (e) {
      print('Geocoding service not available: $e');
      return false;
    }
  }

  /// Get country from coordinates
  Future<String> coordinatesToCountry(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        return placemarks.first.country ?? 'Unknown Country';
      }
    } catch (e) {
      print('Error getting country: $e');
    }
    return 'Unknown Country';
  }
}

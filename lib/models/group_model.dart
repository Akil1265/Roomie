import 'package:geocoding/geocoding.dart';

// Supporting data classes
class LocationData {
  final String address;
  final String city;
  final String state;
  final String pincode;
  final CoordinatesData coordinates;

  LocationData({
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.coordinates,
  });

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      coordinates: CoordinatesData.fromMap(map['coordinates'] ?? {}),
    );
  }

  /// Create LocationData from coordinates using reverse geocoding
  static Future<LocationData> fromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        // Build address from placemark components
        String address = '';
        if (place.name != null && place.name!.isNotEmpty) {
          address += place.name!;
        }
        if (place.street != null && place.street!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.street!;
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.subLocality!;
        }

        return LocationData(
          address: address.isNotEmpty ? address : 'Unknown Address',
          city: place.locality ?? place.subAdministrativeArea ?? 'Unknown City',
          state: place.administrativeArea ?? 'Unknown State',
          pincode: place.postalCode ?? '000000',
          coordinates: CoordinatesData(lat: lat, lng: lng),
        );
      }
    } catch (e) {
      print('Error in reverse geocoding: $e');
    }

    // Fallback if geocoding fails
    return LocationData(
      address: 'Location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
      city: 'Unknown City',
      state: 'Unknown State',
      pincode: '000000',
      coordinates: CoordinatesData(lat: lat, lng: lng),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'coordinates': coordinates.toMap(),
    };
  }

  /// Update location data with new coordinates and reverse geocode to get address
  Future<LocationData> updateFromCoordinates(double lat, double lng) async {
    return await LocationData.fromCoordinates(lat, lng);
  }

  String get fullAddress => '$address, $city, $state $pincode';

  /// Get a short display address (city, state)
  String get shortAddress => '$city, $state';

  /// Check if coordinates are valid (not 0,0)
  bool get hasValidCoordinates =>
      coordinates.lat != 0.0 || coordinates.lng != 0.0;
}

class CoordinatesData {
  final double lat;
  final double lng;

  CoordinatesData({required this.lat, required this.lng});

  factory CoordinatesData.fromMap(Map<String, dynamic> map) {
    return CoordinatesData(
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'lat': lat, 'lng': lng};
  }

  /// Convert coordinates to human-readable address
  Future<String> toAddress() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.locality}, ${place.administrativeArea}, ${place.country}';
      }
    } catch (e) {
      print('Error converting coordinates to address: $e');
    }
    return 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
  }

  /// Check if coordinates are valid
  bool get isValid => lat != 0.0 || lng != 0.0;

  /// Get formatted coordinate string
  String get formatted =>
      '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
}

class RentData {
  final double amount;
  final String currency;

  RentData({required this.amount, required this.currency});

  factory RentData.fromMap(Map<String, dynamic> map) {
    return RentData(
      amount: (map['amount'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'INR',
    );
  }

  Map<String, dynamic> toMap() {
    return {'amount': amount, 'currency': currency};
  }

  String get displayRent => '₹${amount.toStringAsFixed(0)}/$currency';
}

class MemberData {
  final String userId;
  final String role; // admin | member
  final DateTime joinedAt;

  MemberData({
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  factory MemberData.fromMap(Map<String, dynamic> map) {
    return MemberData(
      userId: map['userId'] ?? '',
      role: map['role'] ?? 'member',
      joinedAt: map['joinedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'userId': userId, 'role': role, 'joinedAt': joinedAt};
  }

  bool get isAdmin => role == 'admin';
}

class JoinRequestData {
  final String userId;
  final String message;
  final String status; // pending | accepted | rejected
  final DateTime requestedAt;

  JoinRequestData({
    required this.userId,
    required this.message,
    required this.status,
    required this.requestedAt,
  });

  factory JoinRequestData.fromMap(Map<String, dynamic> map) {
    return JoinRequestData(
      userId: map['userId'] ?? '',
      message: map['message'] ?? '',
      status: map['status'] ?? 'pending',
      requestedAt: map['requestedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'message': message,
      'status': status,
      'requestedAt': requestedAt,
    };
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
}

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String? imageId; // MongoDB image reference ID
  final LocationData location;
  final String roomType; // e.g., '1BHK', '2BHK', 'Shared', 'PG'
  final int capacity; // Max roommates allowed (renamed from maxMembers)
  final int currentMembers; // Current joined members (renamed from memberCount)
  final RentData rent;
  final List<String> amenities; // Facilities available
  final List<String> images; // Cloudinary/Firebase image URLs
  final String createdBy; // Admin/Creator ID
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<MemberData> members; // All members with roles
  final List<JoinRequestData> joinRequests; // Pending join requests

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    this.imageId,
    required this.location,
    required this.roomType,
    required this.capacity,
    required this.currentMembers,
    required this.rent,
    required this.amenities,
    required this.images,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    required this.members,
    required this.joinRequests,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      id: id,
      name: map['roomName'] ?? map['name'] ?? '',
      description: map['description'] ?? '',
      imageId: map['imageId'],
      location: LocationData.fromMap(map['location'] ?? {}),
      roomType: map['roomType'] ?? 'Shared',
      capacity: map['capacity'] ?? map['maxMembers'] ?? 4,
      currentMembers: map['currentMembers'] ?? map['memberCount'] ?? 0,
      rent: RentData.fromMap(map['rent'] ?? {}),
      amenities: List<String>.from(map['amenities'] ?? []),
      images: List<String>.from(map['images'] ?? []),
      createdBy: map['adminId'] ?? map['createdBy'] ?? '',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate(),
      members:
          (map['members'] as List<dynamic>? ?? [])
              .map((m) => MemberData.fromMap(m))
              .toList(),
      joinRequests:
          (map['joinRequests'] as List<dynamic>? ?? [])
              .map((r) => JoinRequestData.fromMap(r))
              .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomName': name,
      'name': name, // Keep both for compatibility
      'description': description,
      'imageId': imageId,
      'location': location.toMap(),
      'roomType': roomType,
      'capacity': capacity,
      'currentMembers': currentMembers,
      'rent': rent.toMap(),
      'amenities': amenities,
      'images': images,
      'adminId': createdBy,
      'createdBy': createdBy, // Keep both for compatibility
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'members': members.map((m) => m.toMap()).toList(),
      'joinRequests': joinRequests.map((r) => r.toMap()).toList(),
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageId,
    LocationData? location,
    String? roomType,
    int? capacity,
    int? currentMembers,
    RentData? rent,
    List<String>? amenities,
    List<String>? images,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<MemberData>? members,
    List<JoinRequestData>? joinRequests,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageId: imageId ?? this.imageId,
      location: location ?? this.location,
      roomType: roomType ?? this.roomType,
      capacity: capacity ?? this.capacity,
      currentMembers: currentMembers ?? this.currentMembers,
      rent: rent ?? this.rent,
      amenities: amenities ?? this.amenities,
      images: images ?? this.images,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      members: members ?? this.members,
      joinRequests: joinRequests ?? this.joinRequests,
    );
  }

  // Helper getters
  bool get hasAvailableSlots => currentMembers < capacity;

  int get availableSlots => capacity - currentMembers;

  bool get isFull => currentMembers >= capacity;

  String get memberCountText => '$currentMembers/$capacity members';

  String get displayName => name.isNotEmpty ? name : 'Unnamed Group';

  String get displayDescription =>
      description.isNotEmpty ? description : 'No description available';

  String get displayRent => rent.displayRent;

  String get displayLocation => location.fullAddress;

  bool get hasPendingRequests => joinRequests.any((r) => r.isPending);

  int get pendingRequestsCount => joinRequests.where((r) => r.isPending).length;

  List<MemberData> get adminMembers => members.where((m) => m.isAdmin).toList();

  MemberData? get primaryAdmin => members.firstWhere(
    (m) => m.isAdmin && m.userId == createdBy,
    orElse:
        () => members.firstWhere(
          (m) => m.isAdmin,
          orElse: () => throw StateError('No admin found'),
        ),
  );

  @override
  String toString() {
    return 'GroupModel(id: $id, name: $name, location: ${location.fullAddress}, currentMembers: $currentMembers)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Hybrid Storage Methods

  /// Returns data for Firebase Firestore (text data only)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'roomName': name,
      'name': name, // Keep both for compatibility
      'description': description,
      'location': location.toMap(),
      'roomType': roomType,
      'capacity': capacity,
      'currentMembers': currentMembers,
      'rent': rent.toMap(),
      'amenities': amenities,
      'images': images,
      'adminId': createdBy,
      'createdBy': createdBy, // Keep both for compatibility
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'imageId': imageId, // Store MongoDB image reference in Firestore
      'members': members.map((m) => m.toMap()).toList(),
      'joinRequests': joinRequests.map((r) => r.toMap()).toList(),
    };
  }

  /// Creates GroupModel from Firestore data
  factory GroupModel.fromFirestore(Map<String, dynamic> data, String id) {
    return GroupModel(
      id: id,
      name: data['roomName'] ?? data['name'] ?? '',
      description: data['description'] ?? '',
      imageId: data['imageId'], // MongoDB image reference
      location: LocationData.fromMap(data['location'] ?? {}),
      roomType: data['roomType'] ?? 'Shared',
      capacity: data['capacity'] ?? data['maxMembers'] ?? 4,
      currentMembers: data['currentMembers'] ?? data['memberCount'] ?? 0,
      rent: RentData.fromMap(data['rent'] ?? {}),
      amenities: List<String>.from(data['amenities'] ?? []),
      images: List<String>.from(data['images'] ?? []),
      createdBy: data['adminId'] ?? data['createdBy'] ?? '',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate(),
      members:
          (data['members'] as List<dynamic>? ?? [])
              .map((m) => MemberData.fromMap(m))
              .toList(),
      joinRequests:
          (data['joinRequests'] as List<dynamic>? ?? [])
              .map((r) => JoinRequestData.fromMap(r))
              .toList(),
    );
  }

  /// Returns data for MongoDB (image data handling)
  Map<String, dynamic> toMongoMap() {
    return {
      'groupId': id, // Reference to Firestore group
      'imageId': imageId,
      'uploadedAt': DateTime.now().toIso8601String(),
    };
  }
}

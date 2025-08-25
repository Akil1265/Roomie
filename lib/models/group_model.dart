class GroupModel {
  final String id;
  final String name;
  final String description;
  final String? imageId; // MongoDB image reference ID
  final String location;
  final int memberCount;
  final int maxMembers;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? rent;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    this.imageId,
    required this.location,
    required this.memberCount,
    required this.maxMembers,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.rent,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageId: map['imageId'],
      location: map['location'] ?? '',
      memberCount: map['memberCount'] ?? 0,
      maxMembers: map['maxMembers'] ?? 4,
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate(),
      rent: map['rent']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageId': imageId,
      'location': location,
      'memberCount': memberCount,
      'maxMembers': maxMembers,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'rent': rent,
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageId,
    String? location,
    int? memberCount,
    int? maxMembers,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? rent,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageId: imageId ?? this.imageId,
      location: location ?? this.location,
      memberCount: memberCount ?? this.memberCount,
      maxMembers: maxMembers ?? this.maxMembers,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rent: rent ?? this.rent,
    );
  }

  // Helper getters
  bool get hasAvailableSlots => memberCount < maxMembers;

  int get availableSlots => maxMembers - memberCount;

  bool get isFull => memberCount >= maxMembers;

  String get memberCountText => '$memberCount/$maxMembers members';

  String get displayName => name.isNotEmpty ? name : 'Unnamed Group';

  String get displayDescription =>
      description.isNotEmpty ? description : 'No description available';

  @override
  String toString() {
    return 'GroupModel(id: $id, name: $name, location: $location, memberCount: $memberCount)';
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
      'name': name,
      'description': description,
      'location': location,
      'memberCount': memberCount,
      'maxMembers': maxMembers,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'rent': rent,
      'imageId': imageId, // Store MongoDB image reference in Firestore
    };
  }

  /// Creates GroupModel from Firestore data
  factory GroupModel.fromFirestore(Map<String, dynamic> data, String id) {
    return GroupModel(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageId: data['imageId'], // MongoDB image reference
      location: data['location'] ?? '',
      memberCount: data['memberCount'] ?? 0,
      maxMembers: data['maxMembers'] ?? 4,
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate(),
      rent: data['rent']?.toDouble(),
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

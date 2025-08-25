class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String? username;
  final String? phone;
  final String? bio;
  final String? profileImageUrl;
  final String? location;
  final String? occupation;
  final int? age;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.username,
    this.phone,
    this.bio,
    this.profileImageUrl,
    this.location,
    this.occupation,
    this.age,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'],
      username: map['username'],
      phone: map['phone'],
      bio: map['bio'],
      profileImageUrl: map['profileImageUrl'],
      location: map['location'],
      occupation: map['occupation'],
      age: map['age'],
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'username': username,
      'phone': phone,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'location': location,
      'occupation': occupation,
      'age': age,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  String get displayName {
    if (username != null && username!.isNotEmpty) return username!;
    if (name != null && name!.isNotEmpty) return name!;
    return email.split('@')[0]; // Fallback to email username
  }

  String get displayBio {
    if (bio != null && bio!.isNotEmpty) return bio!;
    return 'No bio available';
  }
}

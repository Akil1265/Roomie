import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roomie/services/profile_image_service.dart';
import 'package:roomie/services/profile_image_notifier.dart';
import 'dart:io';

class FirestoreService {
  final _firestore = FirebaseFirestore.instance;
  final _profileImageService = ProfileImageService();
  final _profileImageNotifier = ProfileImageNotifier();

  // Get profile image from MongoDB
  Future<String?> getProfileImage(String imageId) async {
    try {
      return await _profileImageService.getUserProfileImage(imageId);
    } catch (e) {
      print('Error getting profile image: $e');
      return null;
    }
  }

  /// Save or update user details
  Future<void> saveUserDetails(
    String uid,
    String email, {
    String? name,
    String? phone,
    String? username,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);

    final userData = {
      'email': email,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (username != null) 'username': username,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      // If new user, also store createdAt
      userData['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(userData, SetOptions(merge: true));
  }

  /// Save user profile with username, bio, and profile image
  Future<void> saveUserProfile({
    required String userId,
    required String username,
    required String bio,
    required String email,
    required String phone,
    File? profileImage,
    String? location,
    String? occupation,
    int? age,
  }) async {
    final docRef = _firestore.collection('users').doc(userId);

    // Get existing data to preserve profile image URL if no new image is provided
    final docSnapshot = await docRef.get();
    String? existingProfileImageUrl;
    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      existingProfileImageUrl = data?['profileImageUrl'] as String?;
    }

    String? profileImageUrl =
        existingProfileImageUrl; // Start with existing URL

    // Store profile image in MongoDB if provided
    if (profileImage != null) {
      try {
        print('Attempting to store profile image in MongoDB...'); // Debug log

        // Use the dedicated profile image service for better management
        final newImageId = await _profileImageService.saveUserProfileImage(
          userId: userId,
          imageFile: profileImage,
          previousImageId:
              existingProfileImageUrl, // This will clean up old images
        );

        if (newImageId != null) {
          profileImageUrl = newImageId;
          print(
            'Profile image stored in MongoDB with ID: $newImageId',
          ); // Debug log

          // Notify all widgets about the profile image change
          _profileImageNotifier.updateProfileImage(newImageId);

          // Clean up old images (keep only recent 5)
          await _profileImageService.cleanupOldProfileImages(userId);
        } else {
          print('Failed to store profile image in MongoDB');
        }
      } catch (e) {
        print('Error storing profile image: $e');
        // Keep existing image URL if upload fails
        print('Continuing without image upload due to storage error');
      }
    }

    final userData = {
      'username': username,
      'bio': bio,
      'email': email,
      'phone': phone,
      'profileImageUrl': profileImageUrl, // Always include this field
      if (location != null) 'location': location,
      if (occupation != null) 'occupation': occupation,
      if (age != null) 'age': age,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!docSnapshot.exists) {
      // If new user, also store createdAt
      userData['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(userData, SetOptions(merge: true));
    print('Profile data saved successfully'); // Debug log
  }

  /// Fetch user details (optional utility)
  Future<Map<String, dynamic>?> getUserDetails(String uid) async {
    print('Firestore: Fetching user details for UID: $uid'); // Debug log
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      print('Firestore: Document exists: ${doc.exists}'); // Debug log
      if (doc.exists) {
        final data = doc.data();
        print('Firestore: Document data: $data'); // Debug log
        return data;
      } else {
        print('Firestore: No document found for UID: $uid'); // Debug log
        return null;
      }
    } catch (e) {
      print('Firestore: Error fetching user details: $e'); // Debug log
      return null;
    }
  }
}

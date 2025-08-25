import 'package:roomie/services/mongodb_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show where;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

class ProfileImageService {
  final _mongoService = MongoDBService();

  /// Store a user's profile image with detailed metadata
  Future<String?> saveUserProfileImage({
    required String userId,
    required File imageFile,
    String? previousImageId,
  }) async {
    try {
      final imageCollection = await _mongoService.getCollection(
        'profile_images',
      );
      if (imageCollection == null) {
        print('Failed to get MongoDB collection');
        return null;
      }

      // Convert image to Base64
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64String = base64Encode(imageBytes);

      // Create unique image ID for this user
      final String imageId =
          'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}';

      // If there's a previous image, remove it to avoid duplicates
      if (previousImageId != null) {
        await imageCollection.deleteOne(where.eq('imageId', previousImageId));
        print('Deleted previous profile image: $previousImageId');
      }

      // Store new image with detailed metadata
      await imageCollection.insertOne({
        'imageId': imageId,
        'userId': userId,
        'imageBase64': base64String,
        'fileSize': imageBytes.length,
        'uploadedAt': DateTime.now(),
        'type': 'profile_image',
        'active': true,
        'metadata': {
          'originalName': imageFile.path.split('/').last,
          'extension': imageFile.path.split('.').last.toLowerCase(),
        },
      });

      _mongoService.resetReconnectAttempts(); // Reset on successful operation
      print('Profile image saved successfully with ID: $imageId');
      print('Image size: ${imageBytes.length} bytes');

      return imageId;
    } catch (e) {
      print('Error saving profile image: $e');
      return null;
    }
  }

  /// Get a user's current profile image
  Future<String?> getUserProfileImage(String imageId) async {
    try {
      final imageCollection = await _mongoService.getCollection(
        'profile_images',
      );
      if (imageCollection == null) {
        print('Failed to get MongoDB collection');
        return null;
      }

      final imageDoc = await imageCollection.findOne({
        'imageId': imageId,
        'active': true,
      });

      if (imageDoc != null && imageDoc['imageBase64'] != null) {
        _mongoService.resetReconnectAttempts(); // Reset on successful operation
        print('Profile image found for ID: $imageId');
        return imageDoc['imageBase64'] as String;
      }

      print('No profile image found for ID: $imageId');
      return null;
    } catch (e) {
      print('Error getting profile image: $e');
      return null;
    }
  }

  /// Get all profile images for a user (for management/history)
  Future<List<Map<String, dynamic>>> getUserProfileImageHistory(
    String userId,
  ) async {
    try {
      final imageCollection = await _mongoService.getCollection(
        'profile_images',
      );
      if (imageCollection == null) {
        print('Failed to get MongoDB collection');
        return [];
      }

      final cursor = imageCollection.find(
        where.eq('userId', userId).sortBy('uploadedAt', descending: true),
      );

      final images = await cursor.toList();
      _mongoService.resetReconnectAttempts(); // Reset on successful operation
      return images
          .map(
            (doc) => {
              'imageId': doc['imageId'],
              'uploadedAt': doc['uploadedAt'],
              'fileSize': doc['fileSize'],
              'active': doc['active'] ?? true,
              'metadata': doc['metadata'],
            },
          )
          .toList();
    } catch (e) {
      print('Error getting user profile image history: $e');
      return [];
    }
  }

  /// Update user's current active profile image (set others as inactive)
  Future<bool> setActiveProfileImage(String userId, String imageId) async {
    try {
      final imageCollection = await _mongoService.getCollection(
        'profile_images',
      );
      if (imageCollection == null) {
        print('Failed to get MongoDB collection');
        return false;
      }

      // Set all user's images as inactive
      await imageCollection.updateMany(where.eq('userId', userId), {
        '\$set': {'active': false},
      });

      // Set the specified image as active
      final result = await imageCollection.updateOne(
        where.eq('imageId', imageId).eq('userId', userId),
        {
          '\$set': {'active': true, 'activatedAt': DateTime.now()},
        },
      );

      _mongoService.resetReconnectAttempts(); // Reset on successful operation
      print('Set profile image as active: $imageId');
      return result.isSuccess;
    } catch (e) {
      print('Error setting active profile image: $e');
      return false;
    }
  }

  /// Delete a specific profile image
  Future<bool> deleteProfileImage(String imageId, String userId) async {
    try {
      final imageCollection = await _mongoService.getCollection(
        'profile_images',
      );
      if (imageCollection == null) {
        print('Failed to get MongoDB collection');
        return false;
      }

      final result = await imageCollection.deleteOne(
        where.eq('imageId', imageId).eq('userId', userId),
      );

      _mongoService.resetReconnectAttempts(); // Reset on successful operation
      print('Deleted profile image: $imageId');
      return result.isSuccess;
    } catch (e) {
      print('Error deleting profile image: $e');
      return false;
    }
  }

  /// Clean up old inactive profile images for a user (keep only latest 5)
  Future<void> cleanupOldProfileImages(String userId) async {
    try {
      final imageCollection = await _mongoService.getCollection(
        'profile_images',
      );
      if (imageCollection == null) {
        print('Failed to get MongoDB collection');
        return;
      }

      // Get all images for user, sorted by upload date
      final cursor = imageCollection.find(
        where.eq('userId', userId).sortBy('uploadedAt', descending: true),
      );

      final images = await cursor.toList();

      // Keep only the 5 most recent images, delete the rest
      if (images.length > 5) {
        for (int i = 5; i < images.length; i++) {
          await imageCollection.deleteOne(
            where.eq('imageId', images[i]['imageId']),
          );
          print('Cleaned up old profile image: ${images[i]['imageId']}');
        }
      }
      _mongoService.resetReconnectAttempts(); // Reset on successful operation
    } catch (e) {
      print('Error cleaning up old profile images: $e');
    }
  }

  /// Get profile image metadata
  Future<Map<String, dynamic>?> getProfileImageMetadata(String imageId) async {
    try {
      final imageCollection = await _mongoService.getCollection(
        'profile_images',
      );
      if (imageCollection == null) {
        print('Failed to get MongoDB collection');
        return null;
      }

      final imageDoc = await imageCollection.findOne(
        where.eq('imageId', imageId),
      );

      if (imageDoc != null) {
        _mongoService.resetReconnectAttempts(); // Reset on successful operation
      }
      return imageDoc;
    } catch (e) {
      print('Error getting profile image metadata: $e');
      return null;
    }
  }
}

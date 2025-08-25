import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:roomie/services/mongodb_service.dart';
import 'package:roomie/services/auth_service.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';

class HybridGroupsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MongoDBService _mongoService = MongoDBService();
  static const String _firestoreCollection = 'groups';
  static const String _mongoImagesCollection = 'group_images';

  // Convert image file to Base64
  Future<String?> _encodeImageToBase64(File imageFile) async {
    try {
      print('Converting image to Base64...');
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64String = base64Encode(imageBytes);
      print(
        'Image converted to Base64 successfully, size: ${base64String.length} characters',
      );
      return base64String;
    } catch (e) {
      print('Error converting image to Base64: $e');
      return null;
    }
  }

  // Ensure MongoDB connection for images
  Future<void> _ensureMongoConnection() async {
    if (!_mongoService.isConnected) {
      await _mongoService.connect();
    }
  }

  // Store image in MongoDB and return image ID
  Future<String?> _storeImage(File imageFile, String groupId) async {
    try {
      await _ensureMongoConnection();

      final imageBase64 = await _encodeImageToBase64(imageFile);
      if (imageBase64 == null) return null;

      final imageId = ObjectId().toHexString();
      final imageData = {
        '_id': ObjectId.fromHexString(imageId),
        'imageId': imageId,
        'groupId': groupId,
        'imageBase64': imageBase64,
        'uploadedAt': DateTime.now(),
        'type': 'group_image',
      };

      final collection = await _mongoService.getCollection(
        _mongoImagesCollection,
      );
      if (collection == null) {
        throw Exception('Failed to get collection');
      }
      final result = await collection.insertOne(imageData);

      if (result.isSuccess) {
        print('Image stored in MongoDB with ID: $imageId');
        return imageId;
      } else {
        throw Exception('Failed to store image in MongoDB');
      }
    } catch (e) {
      print('Error storing image: $e');
      return null;
    }
  }

  // Get image from MongoDB by image ID
  Future<String?> getImage(String imageId) async {
    try {
      await _ensureMongoConnection();

      final collection = await _mongoService.getCollection(
        _mongoImagesCollection,
      );
      if (collection == null) {
        throw Exception('Failed to get collection');
      }
      final imageDoc = await collection.findOne(where.eq('imageId', imageId));

      if (imageDoc != null && imageDoc['imageBase64'] != null) {
        return imageDoc['imageBase64'] as String;
      }
      return null;
    } catch (e) {
      print('Error getting image: $e');
      return null;
    }
  }

  // Create a new group (text data in Firestore, image in MongoDB)
  Future<String?> createGroup({
    required String name,
    required String description,
    required String location,
    required String rentAmount,
    required String otherDetails,
    File? imageFile,
  }) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('Creating group for user: ${user.uid}');

      // Create group in Firestore first
      final groupRef = _firestore.collection(_firestoreCollection).doc();
      final groupId = groupRef.id;

      String? imageId;
      if (imageFile != null) {
        print('Storing group image in MongoDB...');
        imageId = await _storeImage(imageFile, groupId);
        if (imageId == null) {
          print('Image storage failed, continuing without image');
        }
      }

      // Store text data in Firestore
      final groupData = {
        'id': groupId,
        'name': name.trim(),
        'description': description.trim(),
        'location': location.trim(),
        'rentAmount': rentAmount.trim(),
        'otherDetails': otherDetails.trim(),
        'imageId': imageId, // Reference to MongoDB image
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'members': [user.uid],
        'memberCount': 1,
        'isActive': true,
      };

      await groupRef.set(groupData);
      print('Group created successfully with ID: $groupId');
      return groupId;
    } catch (e) {
      print('Error creating group: $e');
      rethrow;
    }
  }

  // Get all groups with images
  Future<List<Map<String, dynamic>>> getAllGroups() async {
    try {
      print('Fetching all groups from Firestore...');

      final querySnapshot =
          await _firestore
              .collection(_firestoreCollection)
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .get();

      final groups = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        final groupData = doc.data();
        groupData['id'] = doc.id;

        // Get image from MongoDB if imageId exists
        if (groupData['imageId'] != null) {
          final imageBase64 = await getImage(groupData['imageId']);
          groupData['imageBase64'] = imageBase64;
        }

        groups.add(groupData);
      }

      print('Fetched ${groups.length} groups');
      return groups;
    } catch (e) {
      print('Error getting all groups: $e');
      return [];
    }
  }

  // Get groups created by user
  Future<List<Map<String, dynamic>>> getUserGroups(String userId) async {
    try {
      print('Fetching user groups from Firestore for user: $userId');

      final querySnapshot =
          await _firestore
              .collection(_firestoreCollection)
              .where('createdBy', isEqualTo: userId)
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .get();

      final groups = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        final groupData = doc.data();
        groupData['id'] = doc.id;

        // Get image from MongoDB if imageId exists
        if (groupData['imageId'] != null) {
          final imageBase64 = await getImage(groupData['imageId']);
          groupData['imageBase64'] = imageBase64;
        }

        groups.add(groupData);
      }

      print('Fetched ${groups.length} user groups');
      return groups;
    } catch (e) {
      print('Error getting user groups: $e');
      return [];
    }
  }

  // Get groups where user is a member
  Future<List<Map<String, dynamic>>> getUserMemberGroups(String userId) async {
    try {
      print('Fetching member groups from Firestore for user: $userId');

      final querySnapshot =
          await _firestore
              .collection(_firestoreCollection)
              .where('members', arrayContains: userId)
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .get();

      final groups = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        final groupData = doc.data();
        groupData['id'] = doc.id;

        // Get image from MongoDB if imageId exists
        if (groupData['imageId'] != null) {
          final imageBase64 = await getImage(groupData['imageId']);
          groupData['imageBase64'] = imageBase64;
        }

        groups.add(groupData);
      }

      print('Fetched ${groups.length} member groups');
      return groups;
    } catch (e) {
      print('Error getting member groups: $e');
      return [];
    }
  }

  // Join a group
  Future<bool> joinGroup(String groupId, String userId) async {
    try {
      print('User $userId joining group $groupId');

      final groupRef = _firestore.collection(_firestoreCollection).doc(groupId);

      await _firestore.runTransaction((transaction) async {
        final groupDoc = await transaction.get(groupRef);

        if (!groupDoc.exists) {
          throw Exception('Group not found');
        }

        final groupData = groupDoc.data()!;
        final members = List<String>.from(groupData['members'] ?? []);

        if (!members.contains(userId)) {
          members.add(userId);

          transaction.update(groupRef, {
            'members': members,
            'memberCount': members.length,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('User joined group successfully');
      return true;
    } catch (e) {
      print('Error joining group: $e');
      return false;
    }
  }

  // Leave a group
  Future<bool> leaveGroup(String groupId, String userId) async {
    try {
      print('User $userId leaving group $groupId');

      final groupRef = _firestore.collection(_firestoreCollection).doc(groupId);

      await _firestore.runTransaction((transaction) async {
        final groupDoc = await transaction.get(groupRef);

        if (!groupDoc.exists) {
          throw Exception('Group not found');
        }

        final groupData = groupDoc.data()!;
        final members = List<String>.from(groupData['members'] ?? []);

        if (members.contains(userId)) {
          members.remove(userId);

          transaction.update(groupRef, {
            'members': members,
            'memberCount': members.length,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('User left group successfully');
      return true;
    } catch (e) {
      print('Error leaving group: $e');
      return false;
    }
  }

  // Update group
  Future<bool> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? location,
    String? rentAmount,
    String? otherDetails,
    File? newImageFile,
  }) async {
    try {
      print('Updating group: $groupId');

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name.trim();
      if (description != null) updateData['description'] = description.trim();
      if (location != null) updateData['location'] = location.trim();
      if (rentAmount != null) updateData['rentAmount'] = rentAmount.trim();
      if (otherDetails != null) {
        updateData['otherDetails'] = otherDetails.trim();
      }

      // Handle new image
      if (newImageFile != null) {
        final imageId = await _storeImage(newImageFile, groupId);
        if (imageId != null) {
          updateData['imageId'] = imageId;
        }
      }

      await _firestore
          .collection(_firestoreCollection)
          .doc(groupId)
          .update(updateData);

      print('Group updated successfully');
      return true;
    } catch (e) {
      print('Error updating group: $e');
      return false;
    }
  }

  // Delete group (soft delete)
  Future<bool> deleteGroup(String groupId) async {
    try {
      print('Deleting group: $groupId');

      await _firestore.collection(_firestoreCollection).doc(groupId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Group deleted successfully');
      return true;
    } catch (e) {
      print('Error deleting group: $e');
      return false;
    }
  }

  // Get groups stream for real-time updates
  Stream<List<Map<String, dynamic>>> getGroupsStream() {
    return _firestore
        .collection(_firestoreCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final groups = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final groupData = doc.data();
            groupData['id'] = doc.id;

            // Get image from MongoDB if imageId exists
            if (groupData['imageId'] != null) {
              final imageBase64 = await getImage(groupData['imageId']);
              groupData['imageBase64'] = imageBase64;
            }

            groups.add(groupData);
          }

          return groups;
        });
  }

  // Get user groups stream
  Stream<List<Map<String, dynamic>>> getUserGroupsStream(String userId) {
    return _firestore
        .collection(_firestoreCollection)
        .where('createdBy', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final groups = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final groupData = doc.data();
            groupData['id'] = doc.id;

            // Get image from MongoDB if imageId exists
            if (groupData['imageId'] != null) {
              final imageBase64 = await getImage(groupData['imageId']);
              groupData['imageBase64'] = imageBase64;
            }

            groups.add(groupData);
          }

          return groups;
        });
  }
}

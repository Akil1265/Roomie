import 'package:mongo_dart/mongo_dart.dart';
import 'package:roomie/services/mongodb_service.dart';
import 'package:roomie/services/auth_service.dart';
import 'package:roomie/services/hybrid_groups_service.dart';
import 'package:roomie/utils/debug_utils.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class MongoGroupsService {
  final MongoDBService _mongoService = MongoDBService();
  final HybridGroupsService _hybridService = HybridGroupsService();
  static const String _collectionName = 'groups';

  // Check if we should use Firestore (for web) or MongoDB (for mobile)
  bool get _useFirestore => kIsWeb;

  // Convert image file to Base64
  Future<String?> _encodeImageToBase64(File imageFile) async {
    try {
      DebugUtils.log('Converting image to Base64...', 'MongoGroups');
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64String = base64Encode(imageBytes);
      DebugUtils.log(
        'Image converted to Base64 successfully, size: ${base64String.length} characters',
        'MongoGroups',
      );
      return base64String;
    } catch (e) {
      DebugUtils.logError('Error converting image to Base64', e, 'MongoGroups');
      return null;
    }
  }

  // Ensure MongoDB connection
  Future<void> _ensureConnection() async {
    if (!_mongoService.isConnected) {
      await _mongoService.connect();
    }
  }

  // Create a new group
  Future<String?> createGroup({
    required String name,
    required String description,
    required String location,
    required int memberCount,
    required int maxMembers,
    required double? rent,
    File? imageFile,
  }) async {
    try {
      // Use Firestore for web, MongoDB for mobile
      if (_useFirestore) {
        DebugUtils.log('Using Firestore for web platform', 'MongoGroups');
        return await _hybridService.createGroup(
          name: name,
          description: description,
          location: location,
          rentAmount: rent?.toString() ?? '',
          otherDetails: 'Member Count: $memberCount, Max Members: $maxMembers',
          imageFile: imageFile,
        );
      }

      // Original MongoDB logic for mobile
      final user = AuthService().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _ensureConnection();
      DebugUtils.log('Creating group for user: ${user.uid}', 'MongoGroups');

      final groupId = ObjectId().toHexString();

      String? imageBase64;
      String? imageId;
      if (imageFile != null) {
        DebugUtils.log('Converting group image to Base64...', 'MongoGroups');
        imageBase64 = await _encodeImageToBase64(imageFile);
        if (imageBase64 != null) {
          imageId = ObjectId().toHexString(); // Generate unique imageId
        } else {
          DebugUtils.log(
            'Image conversion failed, continuing without image',
            'MongoGroups',
          );
        }
      }

      final groupData = {
        '_id': ObjectId.fromHexString(groupId),
        'id': groupId,
        'name': name.trim(),
        'description': description.trim(),
        'imageId': imageId,
        'location': location.trim(),
        'memberCount': memberCount,
        'maxMembers': maxMembers,
        'createdBy': user.uid,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'rent': rent,
        'imageBase64': imageBase64,
        'isActive': true,
      };

      final collection = await _mongoService.getCollection(_collectionName);
      if (collection == null) {
        DebugUtils.logError(
          'MongoDB not connected. Please check your internet connection.',
          'Database connection failed',
          'MongoGroups',
        );
        return null;
      }
      final result = await collection.insertOne(groupData);

      if (result.isSuccess) {
        DebugUtils.log(
          'Group created successfully with ID: $groupId',
          'MongoGroups',
        );
        return groupId;
      } else {
        throw Exception('Failed to create group in MongoDB');
      }
    } catch (e) {
      DebugUtils.logError('Error creating group', e, 'MongoGroups');
      rethrow;
    }
  }

  // Get all groups
  Future<List<Map<String, dynamic>>> getAllGroups() async {
    try {
      // Use Firestore for web, MongoDB for mobile
      if (_useFirestore) {
        DebugUtils.log('Using Firestore for web platform', 'MongoGroups');
        return await _hybridService.getAllGroups();
      }

      // Original MongoDB logic for mobile
      await _ensureConnection();

      final collection = await _mongoService.getCollection(_collectionName);
      if (collection == null) {
        DebugUtils.logError(
          'MongoDB not connected. Please check your internet connection.',
          'Database connection failed',
          'MongoGroups',
        );
        return [];
      }
      final cursor = collection.find(
        where.eq('isActive', true).sortBy('createdAt', descending: true),
      );

      final groups = await cursor.toList();
      print('MongoDB: Found ${groups.length} groups');

      final processedGroups =
          groups.map((group) {
            // Convert ObjectId to string for Flutter compatibility
            if (group['_id'] is ObjectId) {
              group['_id'] = group['_id'].toHexString();
            }

            // Debug log for image data
            if (group['imageBase64'] != null) {
              print(
                'MongoDB: Group ${group['name'] ?? 'Unknown'} has image data (${group['imageBase64'].toString().length} chars)',
              );
            } else {
              print(
                'MongoDB: Group ${group['name'] ?? 'Unknown'} has no image data',
              );
            }

            return Map<String, dynamic>.from(group);
          }).toList();

      return processedGroups;
    } catch (e) {
      print('Error getting all groups: $e');
      return [];
    }
  }

  // Get groups created by user
  Future<List<Map<String, dynamic>>> getUserGroups(String userId) async {
    try {
      await _ensureConnection();

      final collection = await _mongoService.getCollection(_collectionName);
      if (collection == null) {
        DebugUtils.logError(
          'MongoDB not connected. Please check your internet connection.',
          'Database connection failed',
          'MongoGroups',
        );
        return [];
      }
      final cursor = collection.find(
        where
            .eq('createdBy', userId)
            .eq('isActive', true)
            .sortBy('createdAt', descending: true),
      );

      final groups = await cursor.toList();
      return groups.map((group) {
        if (group['_id'] is ObjectId) {
          group['_id'] = group['_id'].toHexString();
        }
        return Map<String, dynamic>.from(group);
      }).toList();
    } catch (e) {
      print('Error getting user groups: $e');
      return [];
    }
  }

  // Get groups where user is a member
  Future<List<Map<String, dynamic>>> getUserMemberGroups(String userId) async {
    try {
      await _ensureConnection();

      final collection = await _mongoService.getCollection(_collectionName);
      if (collection == null) {
        DebugUtils.logError(
          'MongoDB not connected. Please check your internet connection.',
          'Database connection failed',
          'MongoGroups',
        );
        return [];
      }
      final cursor = collection.find(
        where
            .all('members', [userId])
            .eq('isActive', true)
            .sortBy('createdAt', descending: true),
      );

      final groups = await cursor.toList();
      return groups.map((group) {
        if (group['_id'] is ObjectId) {
          group['_id'] = group['_id'].toHexString();
        }
        return Map<String, dynamic>.from(group);
      }).toList();
    } catch (e) {
      print('Error getting user member groups: $e');
      return [];
    }
  }

  // Get group by ID
  Future<Map<String, dynamic>?> getGroupById(String groupId) async {
    try {
      await _ensureConnection();

      final collection = await _mongoService.getCollection(_collectionName);
      if (collection == null) {
        DebugUtils.logError(
          'MongoDB not connected. Please check your internet connection.',
          'Database connection failed',
          'MongoGroups',
        );
        return null;
      }
      final group = await collection.findOne(where.eq('id', groupId));

      if (group != null) {
        if (group['_id'] is ObjectId) {
          group['_id'] = group['_id'].toHexString();
        }
        return Map<String, dynamic>.from(group);
      }
      return null;
    } catch (e) {
      print('Error getting group by ID: $e');
      return null;
    }
  }

  // Join a group
  Future<void> joinGroup(String groupId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _ensureConnection();

      final collection = await _mongoService.getCollection(_collectionName);
      if (collection == null) {
        DebugUtils.logError(
          'MongoDB not connected. Please check your internet connection.',
          'Database connection failed',
          'MongoGroups',
        );
        throw Exception('Database not connected. Please try again later.');
      }

      // First, get the current group
      final group = await collection.findOne(where.eq('id', groupId));
      if (group == null) {
        throw Exception('Group not found');
      }

      final List<dynamic> members = List.from(group['members'] ?? []);

      if (!members.contains(user.uid)) {
        members.add(user.uid);

        final result = await collection.updateOne(
          where.eq('id', groupId),
          modify
              .set('members', members)
              .set('memberCount', members.length)
              .set('updatedAt', DateTime.now()),
        );

        if (result.isSuccess) {
          print('User ${user.uid} joined group $groupId');
        } else {
          throw Exception('Failed to join group');
        }
      }
    } catch (e) {
      print('Error joining group: $e');
      rethrow;
    }
  }

  // Leave a group
  Future<void> leaveGroup(String groupId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _ensureConnection();

      final collection = await _mongoService.getCollection(_collectionName);
      if (collection == null) {
        DebugUtils.logError(
          'MongoDB not connected. Please check your internet connection.',
          'Database connection failed',
          'MongoGroups',
        );
        throw Exception('Database not connected. Please try again later.');
      }

      // First, get the current group
      final group = await collection.findOne(where.eq('id', groupId));
      if (group == null) {
        throw Exception('Group not found');
      }

      final List<dynamic> members = List.from(group['members'] ?? []);

      if (members.contains(user.uid)) {
        members.remove(user.uid);

        final result = await collection.updateOne(
          where.eq('id', groupId),
          modify
              .set('members', members)
              .set('memberCount', members.length)
              .set('updatedAt', DateTime.now()),
        );

        if (result.isSuccess) {
          print('User ${user.uid} left group $groupId');
        } else {
          throw Exception('Failed to leave group');
        }
      }
    } catch (e) {
      print('Error leaving group: $e');
      rethrow;
    }
  }

  // Update group details
  Future<void> updateGroup({
    required String groupId,
    required String name,
    required String description,
    required String location,
    required int memberCount,
    required int maxMembers,
    required double? rent,
    File? newImageFile,
  }) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _ensureConnection();

      String? imageBase64;
      String? imageId;
      if (newImageFile != null) {
        imageBase64 = await _encodeImageToBase64(newImageFile);
        if (imageBase64 != null) {
          imageId =
              ObjectId()
                  .toHexString(); // Generate new imageId for updated image
        }
      }

      final updateData = {
        'name': name.trim(),
        'description': description.trim(),
        'location': location.trim(),
        'memberCount': memberCount,
        'maxMembers': maxMembers,
        'rent': rent,
        'updatedAt': DateTime.now(),
      };

      if (imageBase64 != null) {
        updateData['imageBase64'] = imageBase64;
        updateData['imageId'] = imageId;
      }

      final collection = await _mongoService.getCollection(_collectionName);
      if (collection == null) {
        DebugUtils.logError(
          'MongoDB not connected. Please check your internet connection.',
          'Database connection failed',
          'MongoGroups',
        );
        throw Exception('Database not connected. Please try again later.');
      }
      final result = await collection.updateOne(
        where.eq('id', groupId),
        modify
            .set('name', updateData['name'])
            .set('description', updateData['description'])
            .set('location', updateData['location'])
            .set('memberCount', updateData['memberCount'])
            .set('maxMembers', updateData['maxMembers'])
            .set('rent', updateData['rent'])
            .set('updatedAt', updateData['updatedAt']),
      );

      if (imageBase64 != null) {
        await collection.updateOne(
          where.eq('id', groupId),
          modify.set('imageBase64', imageBase64).set('imageId', imageId),
        );
      }

      if (result.isSuccess) {
        print('Group $groupId updated successfully');
      } else {
        throw Exception('Failed to update group');
      }
    } catch (e) {
      print('Error updating group: $e');
      rethrow;
    }
  }

  // Delete/deactivate group
  Future<void> deleteGroup(String groupId) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _ensureConnection();

      final collection = await _mongoService.getCollection(_collectionName);
      if (collection == null) {
        DebugUtils.logError(
          'MongoDB not connected. Please check your internet connection.',
          'Database connection failed',
          'MongoGroups',
        );
        throw Exception('Database not connected. Please try again later.');
      }
      final result = await collection.updateOne(
        where.eq('id', groupId),
        modify
            .set('isActive', false)
            .set('updatedAt', DateTime.now())
            .set('deletedBy', user.uid)
            .set('deletedAt', DateTime.now()),
      );

      if (result.isSuccess) {
        print('Group $groupId deactivated successfully');
      } else {
        throw Exception('Failed to delete group');
      }
    } catch (e) {
      print('Error deleting group: $e');
      rethrow;
    }
  }

  // Get groups with real-time updates (polling simulation)
  Stream<List<Map<String, dynamic>>> getGroupsStream() async* {
    while (true) {
      try {
        final groups = await getAllGroups();
        yield groups;
        await Future.delayed(
          const Duration(seconds: 5),
        ); // Poll every 5 seconds
      } catch (e) {
        print('Error in groups stream: $e');
        yield [];
      }
    }
  }
}

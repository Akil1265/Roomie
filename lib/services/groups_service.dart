import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:roomie/services/cloudinary_service.dart';
import 'package:roomie/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';

class GroupsService {
  final _firestore = FirebaseFirestore.instance;
  final _realtimeDB = FirebaseDatabase.instance;
  final _cloudinary = CloudinaryService();
  static const String _collection = 'groups';

  Future<String?> createGroup({
    required String name,
    required String description,
    required String location,
    required int memberCount,
    required int maxMembers,
    double? rent,
    List<File> imageFiles = const [],
    List<XFile> webPickedFiles = const [],
    File? imageFile,
    XFile? webPicked, // for legacy single-image usage
  }) async {
    final user = AuthService().currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Check if user can create a group (not already in one)
    final canCreate = await canUserCreateGroup();
    if (!canCreate) {
      throw Exception('You can only create or join one group at a time');
    }

    final docRef = _firestore.collection(_collection).doc();
    final List<String> imageUrls = [];

    final List<File> allLocalImages = [
      ...imageFiles,
      if (imageFile != null) imageFile,
    ];

    final List<XFile> allWebImages = [
      ...webPickedFiles,
      if (webPicked != null) webPicked,
    ];

    if (!kIsWeb && allLocalImages.isNotEmpty) {
      for (var index = 0; index < allLocalImages.length; index++) {
        final file = allLocalImages[index];
        final url = await _cloudinary.uploadFile(
          file: file,
          folder: CloudinaryFolder.groups,
          publicId: 'group_${docRef.id}_${index + 1}',
          context: {'groupId': docRef.id, 'createdBy': user.uid},
        );
        if (url != null) {
          imageUrls.add(url);
        }
      }
    } else if (kIsWeb && allWebImages.isNotEmpty) {
      for (var index = 0; index < allWebImages.length; index++) {
        final image = allWebImages[index];
        final bytes = await image.readAsBytes();
        final url = await _cloudinary.uploadBytes(
          bytes: bytes,
          fileName: image.name,
          folder: CloudinaryFolder.groups,
          publicId: 'group_${docRef.id}_${index + 1}',
          context: {'groupId': docRef.id, 'createdBy': user.uid},
        );
        if (url != null) {
          imageUrls.add(url);
        }
      }
    }

    final data = {
      'id': docRef.id,
      'name': name.trim(),
      'description': description.trim(),
      'location': location.trim(),
      'memberCount': memberCount,
      'maxMembers': maxMembers,
      'rent': rent,
      'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : null,
      'images': imageUrls,
      'imageCount': imageUrls.length,
      'createdBy': user.uid,
      'members': [user.uid],
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data);

    // Initialize group chat in Realtime Database
    await _updateGroupChatMembers(docRef.id);

    print('Group created successfully: ${docRef.id} for user: ${user.uid}');
    print('Group data: $data');
    return docRef.id;
  }

  Future<List<Map<String, dynamic>>> getAllGroups() async {
    final snapshot =
        await _firestore
            .collection(_collection)
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  // Get current user's group (created or joined)
  Future<Map<String, dynamic>?> getCurrentUserGroup() async {
    final user = AuthService().currentUser;
    if (user == null) {
      print('No user authenticated for getCurrentUserGroup');
      return null;
    }

    print('Getting current group for user: ${user.uid}');

    final snapshot =
        await _firestore
            .collection(_collection)
            .where('isActive', isEqualTo: true)
            .where('members', arrayContains: user.uid)
            .limit(1)
            .get();

    print('Found ${snapshot.docs.length} groups for current user');

    if (snapshot.docs.isNotEmpty) {
      final groupData = snapshot.docs.first.data();
      print('Current user group: ${groupData['name']} (${groupData['id']})');
      return groupData;
    }

    print('No current group found for user');
    return null;
  }

  // Check if user can create a new group (hasn't created or joined any)
  Future<bool> canUserCreateGroup() async {
    final currentGroup = await getCurrentUserGroup();
    return currentGroup == null;
  }

  // Get available groups (excluding user's current group)
  Future<List<Map<String, dynamic>>> getAvailableGroups() async {
    final user = AuthService().currentUser;
    if (user == null) {
      print('No user authenticated for getAvailableGroups');
      return [];
    }

    print('Getting available groups for user: ${user.uid}');

    final snapshot =
        await _firestore
            .collection(_collection)
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .get();

    print('Total groups found: ${snapshot.docs.length}');

    final availableGroups =
        snapshot.docs.map((d) => d.data()).where((group) {
          final members = List<String>.from(group['members'] ?? []);
          final isUserMember = members.contains(user.uid);
          print(
            'Group ${group['name']}: members=$members, userIsMember=$isUserMember',
          );
          return !isUserMember; // Exclude groups user is already in
        }).toList();

    print('Available groups count: ${availableGroups.length}');
    return availableGroups;
  }

  Future<bool> joinGroup(String groupId) async {
    final user = AuthService().currentUser;
    if (user == null) return false;

    // Check if user can join a group (not already in one)
    final canJoin = await canUserCreateGroup();
    if (!canJoin) {
      throw Exception('You can only be in one group at a time');
    }

    final ref = _firestore.collection(_collection).doc(groupId);
    return _firestore
        .runTransaction((tx) async {
          final snap = await tx.get(ref);
          if (!snap.exists) throw Exception('Group missing');
          final data = snap.data()!;
          final members = List<String>.from(data['members'] ?? []);
          if (!members.contains(user.uid)) {
            members.add(user.uid);
            tx.update(ref, {
              'members': members,
              'memberCount': members.length,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          return true;
        })
        .then((result) async {
          if (result) {
            // Update group chat in Realtime Database
            await _updateGroupChatMembers(groupId);
          }
          return result;
        })
        .catchError((e) {
          print('Error joining group: $e');
          return false;
        });
  }

  Future<void> leaveGroup(String groupId) async {
    final user = AuthService().currentUser;
    if (user == null) throw Exception('Not authenticated');

    final ref = _firestore.collection(_collection).doc(groupId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Group does not exist');

      final data = snap.data()!;
      final members = List<String>.from(data['members'] ?? []);

      if (members.contains(user.uid)) {
        members.remove(user.uid);

        // If the group is now empty, mark it as inactive.
        // Otherwise, just update the member list and count.
        if (members.isEmpty) {
          tx.update(ref, {
            'members': members,
            'memberCount': 0,
            'isActive': false, // Deactivate group if last member leaves
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          tx.update(ref, {
            'members': members,
            'memberCount': members.length,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // This case should ideally not happen if UI is correct
        throw Exception('User is not a member of this group');
      }
    });
  }

  Future<bool> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? location,
    double? rent,
    File? newImageFile,
  }) async {
    final ref = _firestore.collection(_collection).doc(groupId);
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) updates['name'] = name.trim();
    if (description != null) updates['description'] = description.trim();
    if (location != null) updates['location'] = location.trim();
    if (rent != null) updates['rent'] = rent;

    if (newImageFile != null) {
      final url = await _cloudinary.uploadFile(
        file: newImageFile,
        folder: CloudinaryFolder.groups,
        publicId: 'group_$groupId',
        context: {'groupId': groupId},
      );
      if (url != null) updates['imageUrl'] = url;
    }
    await ref.update(updates);
    return true;
  }

  Future<bool> deleteGroup(String groupId) async {
    final ref = _firestore.collection(_collection).doc(groupId);
    await ref.update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  // 🔔 Send join request to group
  Future<bool> sendJoinRequest(String groupId) async {
    final user = AuthService().currentUser;
    if (user == null) return false;

    try {
      // Check if user can join a group (not already in one)
      final canJoin = await canUserCreateGroup();
      if (!canJoin) {
        throw Exception('You can only be in one group at a time');
      }

      // Get user details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Create join request
      final requestRef = _firestore.collection('joinRequests').doc();
      await requestRef.set({
        'id': requestRef.id,
        'groupId': groupId,
        'userId': user.uid,
        'userName': userData['name'] ?? user.displayName ?? 'Unknown User',
        'userEmail': userData['email'] ?? user.email ?? '',
        'userPhone': userData['phone'] ?? '',
        'userProfileImage': userData['profileImageUrl'],
        'status': 'pending', // pending, approved, rejected
        'requestedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
      });

      print('✅ Join request sent for group: $groupId');
      return true;
    } catch (e) {
      print('❌ Error sending join request: $e');
      return false;
    }
  }

  // 🔍 Get join requests for a group (for group members to review)
  Stream<List<Map<String, dynamic>>> getGroupJoinRequests(String groupId) {
    return _firestore
        .collection('joinRequests')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          // Sort in memory instead of using orderBy
          final docs =
              snapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              }).toList();

          // Sort by requestedAt in descending order
          docs.sort((a, b) {
            final aTime = a['requestedAt'];
            final bTime = b['requestedAt'];
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return docs;
        });
  }

  // ✅ Approve join request
  Future<bool> approveJoinRequest(
    String requestId,
    String groupId,
    String userId,
  ) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return false;

    try {
      return await _firestore
          .runTransaction((tx) async {
            // Get the join request
            final requestRef = _firestore
                .collection('joinRequests')
                .doc(requestId);
            final requestSnap = await tx.get(requestRef);

            if (!requestSnap.exists) throw Exception('Join request not found');

            // Get the group
            final groupRef = _firestore.collection(_collection).doc(groupId);
            final groupSnap = await tx.get(groupRef);

            if (!groupSnap.exists) throw Exception('Group not found');

            final groupData = groupSnap.data()!;
            final members = List<String>.from(groupData['members'] ?? []);

            // Check if current user is a member of this group (can approve)
            if (!members.contains(currentUser.uid)) {
              throw Exception('You are not authorized to approve this request');
            }

            // Add user to group
            if (!members.contains(userId)) {
              members.add(userId);
              tx.update(groupRef, {
                'members': members,
                'memberCount': members.length,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }

            // Update request status
            tx.update(requestRef, {
              'status': 'approved',
              'reviewedAt': FieldValue.serverTimestamp(),
              'reviewedBy': currentUser.uid,
            });

            return true;
          })
          .then((result) async {
            if (result) {
              // Update group chat in Realtime Database
              await _updateGroupChatMembers(groupId);
            }
            return result;
          });
    } catch (e) {
      print('❌ Error approving join request: $e');
      return false;
    }
  }

  // Update group chat members in Realtime Database
  Future<void> _updateGroupChatMembers(String groupId) async {
    try {
      // Get updated group data from Firestore
      final groupDoc =
          await _firestore.collection(_collection).doc(groupId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data()!;
      final members = List<String>.from(groupData['members'] ?? []);
      final groupName = groupData['name'] ?? 'Group Chat';

      // Update group chat in Realtime Database
      final chatRef = _realtimeDB.ref('groupChats/$groupId');
      final chatSnapshot = await chatRef.get();

      if (chatSnapshot.exists) {
        // Update existing group chat
        await chatRef.update({
          'members': members,
          'memberNames': {
            for (String memberId in members) memberId: 'Member',
          }, // You can enhance this
        });
        print('✅ Updated group chat members for group: $groupId');
      } else {
        // Create new group chat if it doesn't exist
        final chatData = {
          'id': groupId,
          'groupName': groupName,
          'members': members,
          'memberNames': {for (String memberId in members) memberId: 'Member'},
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'lastMessage': 'Group created',
          'lastSenderId': 'system',
          'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
          'unreadCounts': {for (String memberId in members) memberId: 0},
        };

        await chatRef.set(chatData);
        print('✅ Created new group chat for group: $groupId');
      }
    } catch (e) {
      print('❌ Error updating group chat members: $e');
    }
  }

  // ❌ Reject join request
  Future<bool> rejectJoinRequest(String requestId) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return false;

    try {
      await _firestore.collection('joinRequests').doc(requestId).update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': currentUser.uid,
      });

      print('✅ Join request rejected: $requestId');
      return true;
    } catch (e) {
      print('❌ Error rejecting join request: $e');
      return false;
    }
  }

  // 📋 Get user's pending join requests
  Stream<List<Map<String, dynamic>>> getUserJoinRequests(String userId) {
    return _firestore
        .collection('joinRequests')
        .where('userId', isEqualTo: userId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // 🔍 Check if user has pending request for a group
  Future<bool> hasPendingRequest(String groupId, String userId) async {
    try {
      final query =
          await _firestore
              .collection('joinRequests')
              .where('groupId', isEqualTo: groupId)
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking pending request: $e');
      return false;
    }
  }
}

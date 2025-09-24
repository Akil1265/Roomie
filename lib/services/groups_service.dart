import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roomie/services/cloudinary_service.dart';
import 'package:roomie/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';

class GroupsService {
  final _firestore = FirebaseFirestore.instance;
  final _cloudinary = CloudinaryService();
  static const String _collection = 'groups';

  Future<String?> createGroup({
    required String name,
    required String description,
    required String location,
    required int memberCount,
    required int maxMembers,
    double? rent,
    File? imageFile,
    XFile? webPicked, // for web usage
  }) async {
    final user = AuthService().currentUser;
    if (user == null) throw Exception('Not authenticated');

    final docRef = _firestore.collection(_collection).doc();
    String? imageUrl;

    if (imageFile != null) {
      imageUrl = await _cloudinary.uploadFile(
        file: imageFile,
        folder: CloudinaryFolder.groups,
        publicId: 'group_${docRef.id}',
        context: {'groupId': docRef.id, 'createdBy': user.uid},
      );
    } else if (kIsWeb && webPicked != null) {
      final bytes = await webPicked.readAsBytes();
      imageUrl = await _cloudinary.uploadBytes(
        bytes: bytes,
        fileName: webPicked.name,
        folder: CloudinaryFolder.groups,
        publicId: 'group_${docRef.id}',
        context: {'groupId': docRef.id, 'createdBy': user.uid},
      );
    }

    final data = {
      'id': docRef.id,
      'name': name.trim(),
      'description': description.trim(),
      'location': location.trim(),
      'memberCount': memberCount,
      'maxMembers': maxMembers,
      'rent': rent,
      'imageUrl': imageUrl,
      'createdBy': user.uid,
      'members': [user.uid],
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data);
    return docRef.id;
  }

  Future<List<Map<String, dynamic>>> getAllGroups() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<bool> joinGroup(String groupId) async {
    final user = AuthService().currentUser;
    if (user == null) return false;
    final ref = _firestore.collection(_collection).doc(groupId);
    return _firestore.runTransaction((tx) async {
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
    });
  }

  Future<bool> leaveGroup(String groupId) async {
    final user = AuthService().currentUser;
    if (user == null) return false;
    final ref = _firestore.collection(_collection).doc(groupId);
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Group missing');
      final data = snap.data()!;
      final members = List<String>.from(data['members'] ?? []);
      if (members.contains(user.uid)) {
        members.remove(user.uid);
        tx.update(ref, {
          'members': members,
          'memberCount': members.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
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
    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
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
}

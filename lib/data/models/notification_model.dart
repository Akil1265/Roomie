import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final Timestamp createdAt;
  final bool isRead;
  final String type; // e.g., 'group_join_conflict', 'request_accepted'
  final Map<String, dynamic> data; // For extra data like groupId

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    required this.type,
    this.data = const {},
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
      type: data['type'] ?? '',
      data: data['data'] is Map ? Map<String, dynamic>.from(data['data']) : {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'createdAt': createdAt,
      'isRead': isRead,
      'type': type,
      'data': data,
    };
  }
}

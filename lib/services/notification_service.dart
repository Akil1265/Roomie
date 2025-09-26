import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roomie/services/auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  NotificationService._internal();
  factory NotificationService() => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Initialize notifications
  Future<void> initialize() async {
    try {
      // Request permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted permission');

        // Get FCM token
        String? token = await _fcm.getToken();
        if (token != null) {
          await _saveFCMToken(token);
        }

        // Listen for token refresh
        _fcm.onTokenRefresh.listen(_saveFCMToken);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification taps
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      }
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveFCMToken(String token) async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'tokenUpdated': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token saved');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Received foreground message: ${message.notification?.title}');
    // You can show local notification here if needed
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('🔔 Notification tapped: ${message.data}');
    // Navigate to specific screen based on notification data
  }

  // Send notification to group members
  Future<void> sendGroupNotification({
    required String groupId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'groupId': groupId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'group',
      });
      print('✅ Group notification sent');
    } catch (e) {
      print('❌ Error sending group notification: $e');
    }
  }

  // Send notification to specific user
  Future<void> sendUserNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'user',
      });
      print('✅ User notification sent');
    } catch (e) {
      print('❌ Error sending user notification: $e');
    }
  }

  // Send expense notifications
  Future<void> sendExpenseNotification({
    required String groupId,
    required String expenseTitle,
    required String action, // 'created', 'paid', 'reminder'
    required double amount,
  }) async {
    String title = '';
    String body = '';

    switch (action) {
      case 'created':
        title = 'New Expense Added';
        body = '$expenseTitle - ₹$amount';
        break;
      case 'paid':
        title = 'Expense Payment Received';
        body = 'Payment received for $expenseTitle';
        break;
      case 'reminder':
        title = 'Payment Reminder';
        body = 'Please pay your share for $expenseTitle';
        break;
    }

    await sendGroupNotification(
      groupId: groupId,
      title: title,
      body: body,
      data: {'type': 'expense', 'action': action, 'amount': amount},
    );
  }

  // Show local notification
  void showLocalNotification({required String title, required String body}) {
    // In a real app, you'd use flutter_local_notifications here
    print('🔔 Local notification: $title - $body');
  }
}

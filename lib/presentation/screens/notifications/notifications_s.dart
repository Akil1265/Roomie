import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomie/data/models/notification_model.dart';
import 'package:roomie/presentation/screens/groups/join_requests_s.dart';
import 'package:roomie/data/datasources/auth_service.dart';
import 'package:roomie/data/datasources/groups_service.dart';
import 'package:roomie/data/datasources/notification_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final notificationService = NotificationService();
    final userId = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[50],
      body:
          userId == null
              ? const Center(child: Text('Please log in to see notifications.'))
              : StreamBuilder<List<NotificationModel>>(
                stream: notificationService.getNotifications(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No notifications yet.',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final notifications = snapshot.data!;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return NotificationCard(notification: notification);
                    },
                  );
                },
              ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;

  const NotificationCard({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();
    final bool isJoinRequestNotification =
        notification.type == 'join_request_received';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap:
          isJoinRequestNotification
              ? () => _handleJoinRequestTap(context)
              : null,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getIconForType(notification.type),
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      notification.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 40.0),
                child: Text(
                  notification.body,
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timeago.format(notification.createdAt.toDate()),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (notification.type == 'group_join_conflict')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await notificationService.deleteNotification(
                                notification.id,
                              );
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed:
                                () => _handleSwitchGroup(context, notification),
                            child: const Text('Switch Group'),
                          ),
                        ],
                      )
                    else if (notification.type == 'join_request_received')
                      TextButton(
                        onPressed: () => _handleJoinRequestTap(context),
                        child: const Text('Review'),
                      )
                    else if (notification.type == 'request_accepted')
                      Container()
                    else
                      Container(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSwitchGroup(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final groupsService = GroupsService();
    final notificationService = NotificationService();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Leave Current Group?'),
            content: const Text(
              'Are you sure you want to leave your current group and join this new one?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final String newGroupId = notification.data['newGroupId'];
        final String currentGroupId = notification.data['currentGroupId'];
        final String userId = notification.userId;

        await groupsService.switchGroup(
          userId: userId,
          currentGroupId: currentGroupId,
          newGroupId: newGroupId,
        );
        await notificationService.deleteNotification(notification.id);

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Successfully switched groups!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to switch groups: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'group_join_conflict':
        return Icons.merge_type;
      case 'request_accepted':
        return Icons.check_circle_outline;
      case 'request_sent':
        return Icons.send_outlined;
      case 'join_request_received':
        return Icons.person_add_alt_1_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Future<void> _handleJoinRequestTap(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    final groupId = notification.data['groupId'] as String?;
    if (groupId == null || groupId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Group information is missing for this request.'),
        ),
      );
      return;
    }

    var dialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final group = await GroupsService().getGroupById(groupId);

      if (dialogOpen) {
        rootNavigator.pop();
        dialogOpen = false;
      }

      if (group == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('The group could not be found.')),
        );
        return;
      }

      if (!notification.isRead) {
        await NotificationService().markAsRead(notification.id);
      }

      navigator.push(
        MaterialPageRoute(builder: (_) => JoinRequestsScreen(group: group)),
      );
    } catch (e) {
      if (dialogOpen) {
        rootNavigator.pop();
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to open join requests: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

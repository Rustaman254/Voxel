import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../state/notification_service.dart';
import '../state/world_controller.dart';

class NotificationDialog extends ConsumerStatefulWidget {
  const NotificationDialog({super.key});

  @override
  ConsumerState<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends ConsumerState<NotificationDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationServiceProvider);
    final messages = notifications.where((n) => n.type == 'message').toList();
    final requests = notifications.where((n) => n.type == 'friend_request').toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                   Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB452FF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_rounded, color: Color(0xFFB452FF)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'NOTIFICATIONS',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFB452FF),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFB452FF),
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              tabs: [
                Tab(child: Text('MESSAGES (${messages.length})')),
                Tab(child: Text('REQUESTS (${requests.length})')),
              ],
            ),
            
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNotificationList(messages, isMessage: true),
                  _buildNotificationList(requests, isMessage: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<AppNotification> items, {required bool isMessage}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMessage ? Icons.chat_bubble_outline : Icons.person_add_disabled,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isMessage ? 'No messages yet' : 'No new requests',
              style: GoogleFonts.outfit(
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (c, i) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: Key(item.id),
          background: Container(color: Colors.red),
          onDismissed: (_) {
            ref.read(notificationServiceProvider.notifier).clearNotification(item.id);
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isMessage ? Colors.blue[50] : Colors.orange[50],
              child: Icon(
                isMessage ? Icons.chat : Icons.person_add,
                color: isMessage ? Colors.blue : Colors.orange,
                size: 20,
              ),
            ),
            title: Text(
              item.title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: GoogleFonts.outfit(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.jm().format(item.timestamp),
                  style: GoogleFonts.outfit(
                    color: Colors.grey[400],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            trailing: !item.isRead             ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB452FF),
                    shape: BoxShape.circle,
                  ),
                )
              : null,
            onTap: () {
              // Handle tap action (open chat or accept request)
              if (isMessage) {
                // Navigate to chat (To be implemented)
                Navigator.pop(context); // Close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Use chat bubble to chat!')),
                );
              } else {
                // Determine request ID
                final requestId = item.id;
                
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Friend Request'),
                    content: Text('Do you want to accept ${item.title}?'), // Title is mostly just "Friend Request" but let's assume body has name or use data
                    actions: [
                      TextButton(
                        onPressed: () {
                          // Reject
                          ref.read(notificationServiceProvider.notifier).clearNotification(item.id);
                          ref.read(worldRepositoryProvider).respondToFriendRequest(requestId, 'reject');
                          Navigator.pop(ctx);
                        },
                        child: const Text('Decline', style: TextStyle(color: Colors.red)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                           // Accept
                           ref.read(notificationServiceProvider.notifier).clearNotification(item.id);
                           ref.read(worldRepositoryProvider).respondToFriendRequest(requestId, 'accept');
                           Navigator.pop(ctx);
                           Navigator.pop(context); // Close notification dialog
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Friend request accepted!')),
                           );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB452FF), foregroundColor: Colors.white),
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../state/notification_service.dart';
import '../state/world_controller.dart';
import '../screens/chat_screen.dart';
import '../screens/friends_list_screen.dart';

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
              Navigator.pop(context); // Close dialog first

              if (isMessage) {
                final senderId = item.data['senderId'];
                final senderName = item.data['senderName'] ?? 'User'; // Fallback
                
                if (senderId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => ChatScreen(
                        peerId: senderId,
                        peerName: senderName,
                      ),
                    ),
                  );
                } else {
                   // Fallback to list
                   // Navigator.push(context, MaterialPageRoute(builder: (c) => const MessagesListScreen()));
                }
              } else {
                // Open Friends List (Requests Tab)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => const FriendsListScreen(),
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

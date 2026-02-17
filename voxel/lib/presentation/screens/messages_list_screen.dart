import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/peers_provider.dart';
import '../state/auth_notifier.dart';
import '../widgets/voxel_avatar.dart';
import 'chat_screen.dart';
import '../../data/services/chat_database_service.dart';
import 'package:intl/intl.dart';

class MessagesListScreen extends ConsumerStatefulWidget {
  const MessagesListScreen({super.key});

  @override
  ConsumerState<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends ConsumerState<MessagesListScreen> {
  final ChatDatabaseService _chatDb = ChatDatabaseService();
  Map<String, Map<String, dynamic>> _lastMessages = {};
  Map<String, int> _unreadCounts = {};

  @override
  void initState() {
    super.initState();
    _loadLastMessages();
  }

  Future<void> _loadLastMessages() async {
    final currentUser = ref.read(authProvider).user;
    if (currentUser == null) return;

    final peerIds = await _chatDb.getAllConversationPeerIds(currentUser.id);
    
    for (final peerId in peerIds) {
      final lastMsg = await _chatDb.getLastMessage(currentUser.id, peerId);
      final unreadCount = await _chatDb.getUnreadCount(currentUser.id, peerId);
      
      if (mounted) {
        setState(() {
          if (lastMsg != null) {
            _lastMessages[peerId] = lastMsg;
          }
          _unreadCounts[peerId] = unreadCount;
        });
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(timestamp);
    } else {
      return DateFormat('M/d/yy').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peersAsync = ref.watch(peersStreamProvider);
    final currentUser = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Text(
              'Messages',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: Color(0xFFB452FF), size: 24),
            onPressed: () {
              // TODO: Implement new message
            },
          ),
        ],
      ),
      body: peersAsync.when(
        data: (peers) {
          if (peers.isEmpty && _lastMessages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No messages',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'There are no messages yet.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          // Get all peer IDs from both active peers and chat history
          final Set<String> allPeerIds = {};
          for (final peer in peers) {
            if (peer.userId != currentUser?.id) {
              allPeerIds.add(peer.userId);
            }
          }
          allPeerIds.addAll(_lastMessages.keys);

          if (allPeerIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No conversations',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }

          // Sort by last message timestamp
          final sortedPeerIds = allPeerIds.toList()
            ..sort((a, b) {
              final aTime = _lastMessages[a]?['timestamp'] as DateTime?;
              final bTime = _lastMessages[b]?['timestamp'] as DateTime?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sortedPeerIds.length,
            itemBuilder: (context, index) {
              final peerId = sortedPeerIds[index];
              final peer = peers.firstWhere(
                (p) => p.userId == peerId,
                orElse: () => peers.first, // Fallback
              );
              
              final lastMsg = _lastMessages[peerId];
              final unreadCount = _unreadCounts[peerId] ?? 0;

              return _MessageListItem(
                userId: peerId,
                username: peer.username.isNotEmpty ? peer.username : 'User',
                avatarUrl: peer.avatarUrl,
                isOnline: peer.isVisible,
                lastMessage: lastMsg?['message'] ?? '',
                timestamp: lastMsg?['timestamp'],
                unreadCount: unreadCount,
                isSentByMe: lastMsg?['isSentByMe'] ?? false,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        peerId: peerId,
                        peerName: peer.username.isNotEmpty ? peer.username : 'User',
                      ),
                    ),
                  );
                  // Reload messages after returning from chat
                  _loadLastMessages();
                },
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFB452FF),
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load messages',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageListItem extends StatelessWidget {
  final String userId;
  final String username;
  final String avatarUrl;
  final bool isOnline;
  final String lastMessage;
  final DateTime? timestamp;
  final int unreadCount;
  final bool isSentByMe;
  final VoidCallback onTap;

  const _MessageListItem({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.isOnline,
    required this.lastMessage,
    this.timestamp,
    required this.unreadCount,
    required this.isSentByMe,
    required this.onTap,
  });

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(timestamp);
    } else {
      return DateFormat('M/d/yy').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: unreadCount > 0 ? const Color(0xFFF8F9FA) : Colors.white,
        ),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: unreadCount > 0 ? const Color(0xFFB452FF) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: VoxelAvatar(
                    radius: 28,
                    avatarUrl: avatarUrl,
                    displayName: username,
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D856),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // User info and message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          username,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          _formatTimestamp(timestamp!),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: unreadCount > 0 ? const Color(0xFFB452FF) : Colors.grey[600],
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage.isEmpty 
                              ? 'Tap to start chatting' 
                              : (isSentByMe ? 'You: ' : '') + lastMessage,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFB452FF),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../state/world_controller.dart';
import '../state/notification_service.dart';
import '../state/friends_provider.dart';
import '../state/auth_notifier.dart';
import '../../data/services/chat_database_service.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerAvatarUrl;

  const ChatScreen({
    super.key, 
    required this.peerId, 
    required this.peerName,
    this.peerAvatarUrl,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatDatabaseService _chatDb = ChatDatabaseService();
  final _uuid = const Uuid();
  
  List<ChatMessage> _messages = [];
  ChatMessage? _replyingTo;
  
  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
  }

  Future<void> _loadMessages() async {
    final myUserId = ref.read(authProvider).user?.id ?? '';
    final messages = await _chatDb.getConversation(myUserId, widget.peerId);
    
    if (mounted) {
      setState(() {
        _messages = messages;
      });
      _scrollToBottom();
    }
  }

  Future<void> _markAsRead() async {
    final myUserId = ref.read(authProvider).user?.id ?? '';
    await _chatDb.markAsRead(myUserId, widget.peerId);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = ref.read(authProvider).user?.id ?? '';
    
    // Listen to new messages from notifications
    ref.listen(notificationServiceProvider, (previous, next) {
      final newMessages = next
          .where((n) => n.type == 'message' && n.data['senderId'] == widget.peerId)
          .toList();
      
      if (newMessages.isNotEmpty) {
        _loadMessages();
        _markAsRead();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.peerAvatarUrl != null && widget.peerAvatarUrl!.isNotEmpty
                  ? NetworkImage(widget.peerAvatarUrl!) 
                  : null,
              backgroundColor: Colors.grey[200],
              child: widget.peerAvatarUrl == null || widget.peerAvatarUrl!.isEmpty
                  ? Text(widget.peerName[0], style: GoogleFonts.outfit(color: Colors.black))
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              widget.peerName,
              style: GoogleFonts.outfit(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_rounded, color: Colors.black, size: 22),
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audio call coming soon!')),
               );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.black, size: 24),
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video call coming soon!')),
               );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(myUserId),
          ),
          if (_replyingTo != null)
            _buildReplyPreview(),
          _buildInputArea(myUserId),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFB452FF),
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyingTo!.senderId == ref.read(authProvider).user?.id 
                      ? 'You' 
                      : widget.peerName,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB452FF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.message,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _replyingTo = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(String myUserId) {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to start the conversation',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    final sortedMessages = List<ChatMessage>.from(_messages)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: sortedMessages.length,
      itemBuilder: (context, index) {
        final msg = sortedMessages[index];
        final isMe = msg.senderId == myUserId;
        final showTime = index == sortedMessages.length - 1 || 
            sortedMessages[index + 1].timestamp.difference(msg.timestamp).inMinutes.abs() > 5;

        return Column(
          children: [
            if (showTime)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  DateFormat.jm().format(msg.timestamp),
                  style: GoogleFonts.outfit(
                    color: Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            GestureDetector(
              onLongPress: () {
                setState(() {
                  _replyingTo = msg;
                });
              },
              child: Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (msg.replyToMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 2,
                                height: 30,
                                color: isMe ? Colors.white : const Color(0xFFB452FF),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  msg.replyToMessage!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: isMe ? Colors.white70 : Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isMe 
                              ? const LinearGradient(
                                  colors: [Color(0xFFB452FF), Color(0xFF9B59B6)],
                                )
                              : null,
                          color: isMe ? null : const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                          ),
                        ),
                        child: Text(
                          msg.message,
                          style: GoogleFonts.outfit(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputArea(String myUserId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
             color: Colors.black.withOpacity(0.05),
             offset: const Offset(0, -4),
             blurRadius: 10,
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.add_a_photo_rounded, color: Color(0xFFB452FF)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Photo sharing coming soon!')),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: GoogleFonts.outfit(color: Colors.grey[500]),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: GoogleFonts.outfit(color: Colors.black),
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _sendMessage(myUserId),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _sendMessage(myUserId),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFB452FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage(String myUserId) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final messageId = _uuid.v4();
    final message = ChatMessage(
      id: messageId,
      senderId: myUserId,
      receiverId: widget.peerId,
      message: text,
      timestamp: DateTime.now(),
      isRead: false,
      replyToId: _replyingTo?.id,
      replyToMessage: _replyingTo?.message,
    );

    // Save to database
    await _chatDb.saveMessage(message);

    // Send via WebSocket
    try {
      final repo = ref.read(worldRepositoryProvider);
      (repo as dynamic).sendMessage({
        'type': 'send_message',
        'payload': {
           'receiverId': widget.peerId,
           'content': text,
           'messageId': messageId,
           'replyToId': _replyingTo?.id,
           'replyToMessage': _replyingTo?.message,
        }
      });
    } catch (e) {
      debugPrint('Failed to send message via WebSocket: $e');
    }

    // Update UI
    setState(() {
      _messages.add(message);
      _messageController.clear();
      _replyingTo = null;
    });

    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

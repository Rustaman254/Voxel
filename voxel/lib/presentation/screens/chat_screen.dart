import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../state/world_controller.dart';
import '../state/auth_notifier.dart';
import '../../data/services/chat_database_service.dart';
import '../../data/repositories/socket_world_repository.dart';
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
  bool _peerIsTyping = false;
  Timer? _typingDebounce;

  StreamSubscription? _notificationSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _receiptSub;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
    _subscribeToRealTime();
  }

  void _subscribeToRealTime() {
    final repo = ref.read(worldRepositoryProvider);
    if (repo is! SocketWorldRepository) return;

    // Real-time incoming messages
    _notificationSub = repo.subscribeNotifications().listen((data) {
      final type = data['type'];
      if (type != 'message_received') return;

      final senderId = data['senderId']?.toString() ?? data['senderID']?.toString() ?? '';
      if (senderId != widget.peerId) return;

      final content = data['content']?.toString() ?? '';
      final messageId = data['id']?.toString() ?? _uuid.v4();

      final msg = ChatMessage(
        id: messageId,
        senderId: senderId,
        receiverId: ref.read(authProvider).user?.id ?? '',
        message: content,
        timestamp: DateTime.now(),
        isRead: true, // We're viewing right now
        status: 'delivered',
      );

      _chatDb.saveMessage(msg);

      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();

        // Send read receipt back
        repo.sendMarkRead(senderId, messageId);
      }
    });

    // Typing indicator from peer
    _typingSub = repo.subscribeTyping().listen((data) {
      final senderId = data['senderId']?.toString() ?? '';
      if (senderId != widget.peerId) return;
      final targetId = data['targetId']?.toString() ?? '';
      final myId = ref.read(authProvider).user?.id ?? '';
      if (targetId.isNotEmpty && targetId != myId) return;

      final isTyping = data['isTyping'] == true;
      if (mounted) {
        setState(() => _peerIsTyping = isTyping);
      }
    });

    // Read receipts from peer
    _receiptSub = repo.subscribeReadReceipts().listen((data) {
      final readerId = data['readerId']?.toString() ?? '';
      final messageId = data['messageId']?.toString() ?? '';
      if (readerId != widget.peerId) return;

      _chatDb.updateMessageStatus(messageId, 'read');
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(status: 'read');
          }
        });
      }
    });
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

    // Send read receipts for unread messages
    final repo = ref.read(worldRepositoryProvider);
    if (repo is SocketWorldRepository) {
      for (final msg in _messages) {
        if (msg.senderId == widget.peerId && !msg.isRead) {
          repo.sendMarkRead(widget.peerId, msg.id);
        }
      }
    }
  }

  void _onTextChanged(String text) {
    final repo = ref.read(worldRepositoryProvider);
    if (repo is! SocketWorldRepository) return;

    if (text.isNotEmpty) {
      repo.sendTypingIndicator(isTyping: true, targetId: widget.peerId);
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      repo.sendTypingIndicator(isTyping: false, targetId: widget.peerId);
    });
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peerName,
                  style: GoogleFonts.outfit(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (_peerIsTyping)
                  Text(
                    'typing...',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFB452FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
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
          // Typing indicator
          if (_peerIsTyping)
            _buildTypingIndicator(),
          if (_replyingTo != null)
            _buildReplyPreview(),
          _buildInputArea(myUserId),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedTypingDots(),
          const SizedBox(width: 8),
          Text(
            '${widget.peerName} is typing...',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                msg.message,
                                style: GoogleFonts.outfit(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat.jm().format(msg.timestamp),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: isMe ? Colors.white60 : Colors.grey[400],
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  _buildStatusIcon(msg.status, isMe),
                                ],
                              ],
                            ),
                          ],
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

  Widget _buildStatusIcon(String status, bool isMe) {
    switch (status) {
      case 'read':
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF4FC3F7));
      case 'delivered':
        return Icon(Icons.done_all, size: 14, color: isMe ? Colors.white60 : Colors.grey);
      case 'sent':
      default:
        return Icon(Icons.done, size: 14, color: isMe ? Colors.white60 : Colors.grey);
    }
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
                  onChanged: _onTextChanged,
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
      status: 'sent',
    );

    // Save to local database
    await _chatDb.saveMessage(message);

    // Send via WebSocket
    try {
      final repo = ref.read(worldRepositoryProvider);
      if (repo is SocketWorldRepository) {
        repo.sendMessage({
          'type': 'send_message',
          'payload': {
             'receiverId': widget.peerId,
             'content': text,
             'messageId': messageId,
             'replyToId': _replyingTo?.id,
             'replyToMessage': _replyingTo?.message,
          }
        });
        // Stop typing indicator
        repo.sendTypingIndicator(isTyping: false, targetId: widget.peerId);
      }
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
    _notificationSub?.cancel();
    _typingSub?.cancel();
    _receiptSub?.cancel();
    _typingDebounce?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

/// Animated typing dots widget
class _AnimatedTypingDots extends StatefulWidget {
  @override
  State<_AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<_AnimatedTypingDots>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final value = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final offset = (value < 0.5) ? value * 2 : (1.0 - value) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.translate(
                offset: Offset(0, -3 * offset),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/socket_world_repository.dart';
import '../../data/services/chat_database_service.dart';
import '../state/auth_notifier.dart';
import '../state/world_controller.dart';

class LobbyChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;

  const LobbyChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  ConsumerState<LobbyChatScreen> createState() => _LobbyChatScreenState();
}

class _LobbyChatScreenState extends ConsumerState<LobbyChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatDatabaseService _chatDb = ChatDatabaseService();
  final List<ChatMessage> _messages = [];
  
  StreamSubscription? _lobbySub;
  StreamSubscription? _typingSub;
  final Set<String> _typingUsers = {};
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _subscribeToLobby();
  }

  void _loadHistory() async {
    final history = await _chatDb.getLobbyMessages(widget.roomId);
    if (mounted) {
      setState(() => _messages.addAll(history));
      _scrollToBottom();
    }
  }

  void _subscribeToLobby() {
    final repo = ref.read(worldRepositoryProvider);
    if (repo is SocketWorldRepository) {
      _lobbySub = repo.subscribeLobbyChat().listen((data) {
        final roomId = data['roomId']?.toString() ?? '';
        if (roomId != widget.roomId) return;

        final currentUser = ref.read(authProvider).user;
        final senderId = data['senderId']?.toString() ?? '';
        
        final msg = ChatMessage(
          id: data['messageId']?.toString() ?? const Uuid().v4(),
          senderId: senderId,
          receiverId: widget.roomId,
          message: data['content']?.toString() ?? '',
          timestamp: data['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] is int ? data['timestamp'] : int.tryParse(data['timestamp'].toString()) ?? 0)
              : DateTime.now(),
          roomId: widget.roomId,
          senderName: data['senderName']?.toString(),
          status: 'delivered',
        );

        // Don't double-add if it's our own message (we added it optimistically)
        if (senderId == currentUser?.id) {
          // Update status of our optimistic message
          final idx = _messages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) {
            setState(() {
              _messages[idx] = _messages[idx].copyWith(status: 'delivered');
            });
          }
          return;
        }

        _chatDb.saveMessage(msg);
        if (mounted) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      });

      _typingSub = repo.subscribeTyping().listen((data) {
        final roomId = data['roomId']?.toString() ?? '';
        if (roomId != widget.roomId) return;
        
        final senderId = data['senderId']?.toString() ?? '';
        final isTyping = data['isTyping'] == true;
        final currentUser = ref.read(authProvider).user;
        if (senderId == currentUser?.id) return;

        if (mounted) {
          setState(() {
            if (isTyping) {
              _typingUsers.add(senderId);
            } else {
              _typingUsers.remove(senderId);
            }
          });
        }
      });
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = ref.read(authProvider).user;
    if (currentUser == null) return;

    final messageId = const Uuid().v4();
    
    // Add optimistically
    final msg = ChatMessage(
      id: messageId,
      senderId: currentUser.id,
      receiverId: widget.roomId,
      message: text,
      timestamp: DateTime.now(),
      roomId: widget.roomId,
      senderName: currentUser.displayName.isNotEmpty ? currentUser.displayName : currentUser.username,
      status: 'sent',
    );

    _chatDb.saveMessage(msg);
    setState(() => _messages.add(msg));
    _scrollToBottom();

    // Send via WebSocket
    final repo = ref.read(worldRepositoryProvider);
    if (repo is SocketWorldRepository) {
      repo.sendLobbyMessage(text, msg.senderName ?? 'User', messageId);
      // Stop typing indicator
      repo.sendTypingIndicator(isTyping: false, roomId: widget.roomId);
    }

    _messageController.clear();
  }

  void _onTextChanged(String text) {
    final repo = ref.read(worldRepositoryProvider);
    if (repo is! SocketWorldRepository) return;

    if (text.isNotEmpty) {
      repo.sendTypingIndicator(isTyping: true, roomId: widget.roomId);
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      repo.sendTypingIndicator(isTyping: false, roomId: widget.roomId);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _lobbySub?.cancel();
    _typingSub?.cancel();
    _typingDebounce?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14142B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.roomName,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (_typingUsers.isNotEmpty)
              Text(
                '${_typingUsers.length} ${_typingUsers.length == 1 ? "person" : "people"} typing...',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFFB452FF),
                ),
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, color: Colors.white54, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Room',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start the conversation!',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == currentUser?.id;
                      final showSender = !isMe && (index == 0 || _messages[index - 1].senderId != msg.senderId);

                      return _LobbyMessageBubble(
                        message: msg,
                        isMe: isMe,
                        showSender: showSender,
                      );
                    },
                  ),
          ),

          // Typing indicator
          if (_typingUsers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  _TypingDotsAnimation(),
                  const SizedBox(width: 8),
                  Text(
                    '${_typingUsers.length} typing...',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF14142B),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        onChanged: _onTextChanged,
                        onSubmitted: (_) => _sendMessage(),
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Message ${widget.roomName}...',
                          hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFB452FF), Color(0xFF8B2FC9)],
                        ),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showSender;

  const _LobbyMessageBubble({
    required this.message,
    required this.isMe,
    required this.showSender,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: showSender ? 12 : 2,
        bottom: 2,
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                message.senderName ?? 'User',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB452FF),
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFFB452FF).withOpacity(0.2)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              border: Border.all(
                color: isMe
                    ? const Color(0xFFB452FF).withOpacity(0.3)
                    : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message.message,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: Colors.white30,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.status == 'read'
                            ? Icons.done_all
                            : message.status == 'delivered'
                                ? Icons.done_all
                                : Icons.done,
                        size: 14,
                        color: message.status == 'read'
                            ? const Color(0xFF4FC3F7)
                            : Colors.white30,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime ts) {
    final h = ts.hour.toString().padLeft(2, '0');
    final m = ts.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TypingDotsAnimation extends StatefulWidget {
  @override
  State<_TypingDotsAnimation> createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<_TypingDotsAnimation>
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
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final value = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final offset = (value < 0.5) ? value * 2 : (1.0 - value) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -3 * offset),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB452FF).withOpacity(0.6),
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

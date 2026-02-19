import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? replyToId;
  final String? replyToMessage;
  final String status; // 'sent', 'delivered', 'read'
  final String? roomId; // null = private, set = lobby/room message
  final String? senderName;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.replyToId,
    this.replyToMessage,
    this.status = 'sent',
    this.roomId,
    this.senderName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead ? 1 : 0,
      'replyToId': replyToId,
      'replyToMessage': replyToMessage,
      'status': status,
      'roomId': roomId,
      'senderName': senderName,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      message: map['message'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      isRead: map['isRead'] == 1,
      replyToId: map['replyToId'],
      replyToMessage: map['replyToMessage'],
      status: map['status'] ?? 'sent',
      roomId: map['roomId'],
      senderName: map['senderName'],
    );
  }

  ChatMessage copyWith({
    String? status,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      replyToId: replyToId,
      replyToMessage: replyToMessage,
      status: status ?? this.status,
      roomId: roomId,
      senderName: senderName,
    );
  }
}

class ChatDatabaseService {
  static final ChatDatabaseService _instance = ChatDatabaseService._internal();
  factory ChatDatabaseService() => _instance;
  ChatDatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'chat_messages.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages(
            id TEXT PRIMARY KEY,
            senderId TEXT NOT NULL,
            receiverId TEXT NOT NULL,
            message TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            isRead INTEGER NOT NULL DEFAULT 0,
            replyToId TEXT,
            replyToMessage TEXT,
            status TEXT NOT NULL DEFAULT 'sent',
            roomId TEXT,
            senderName TEXT
          )
        ''');
        
        await db.execute('''
          CREATE INDEX idx_conversation ON messages(senderId, receiverId)
        ''');
        await db.execute('''
          CREATE INDEX idx_room ON messages(roomId)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE messages ADD COLUMN status TEXT NOT NULL DEFAULT 'sent'");
          await db.execute("ALTER TABLE messages ADD COLUMN roomId TEXT");
          await db.execute("ALTER TABLE messages ADD COLUMN senderName TEXT");
          await db.execute('CREATE INDEX IF NOT EXISTS idx_room ON messages(roomId)');
          debugPrint('📦 Database migrated from v$oldVersion to v$newVersion');
        }
      },
    );
  }

  Future<void> saveMessage(ChatMessage message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('💾 Saved message: ${message.id}');
  }

  Future<List<ChatMessage>> getConversation(String userId, String peerId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'roomId IS NULL AND ((senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?))',
      whereArgs: [userId, peerId, peerId, userId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) => ChatMessage.fromMap(maps[i]));
  }

  /// Get lobby/room messages
  Future<List<ChatMessage>> getLobbyMessages(String roomId, {int limit = 100}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'roomId = ?',
      whereArgs: [roomId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );

    return List.generate(maps.length, (i) => ChatMessage.fromMap(maps[i]));
  }

  Future<Map<String, dynamic>?> getLastMessage(String userId, String peerId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'roomId IS NULL AND ((senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?))',
      whereArgs: [userId, peerId, peerId, userId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    
    final message = ChatMessage.fromMap(maps[0]);
    return {
      'message': message.message,
      'timestamp': message.timestamp,
      'isRead': message.isRead,
      'isSentByMe': message.senderId == userId,
      'status': message.status,
    };
  }

  Future<int> getUnreadCount(String userId, String peerId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE senderId = ? AND receiverId = ? AND isRead = 0 AND roomId IS NULL',
      [peerId, userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markAsRead(String userId, String peerId) async {
    final db = await database;
    await db.update(
      'messages',
      {'isRead': 1, 'status': 'read'},
      where: 'senderId = ? AND receiverId = ? AND roomId IS NULL',
      whereArgs: [peerId, userId],
    );
  }

  /// Update message status (sent → delivered → read)
  Future<void> updateMessageStatus(String messageId, String status) async {
    final db = await database;
    await db.update(
      'messages',
      {'status': status},
      where: 'id = ?',
      whereArgs: [messageId],
    );
    debugPrint('📝 Updated message $messageId status to $status');
  }

  Future<List<String>> getAllConversationPeerIds(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT 
        CASE 
          WHEN senderId = ? THEN receiverId 
          ELSE senderId 
        END as peerId
      FROM messages
      WHERE (senderId = ? OR receiverId = ?) AND roomId IS NULL
      ORDER BY timestamp DESC
    ''', [userId, userId, userId]);

    return maps.map((m) => m['peerId'] as String).toList();
  }

  Future<void> deleteConversation(String userId, String peerId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'roomId IS NULL AND ((senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?))',
      whereArgs: [userId, peerId, peerId, userId],
    );
  }
}

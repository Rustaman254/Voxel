import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/room.dart';
import '../state/room_controller.dart';
import '../state/auth_notifier.dart';

class RoomDetailsScreen extends ConsumerWidget {
  final Room room;

  const RoomDetailsScreen({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider).user;
    final isCreator = currentUser?.id == room.creatorId;
    final isMember = room.members.any((m) => m.userId == currentUser?.id);

    return Container( // Designed to be shown in a modal bottom sheet
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Header handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB452FF).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.meeting_room_rounded,
                                color: Color(0xFFB452FF),
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.name,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                      height: 1.1,
                                    ),
                                  ),
                                  if (room.isPrivate)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.lock, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Private Room',
                                            style: GoogleFonts.outfit(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        Text(
                          'ABOUT',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey[500],
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          room.description.isNotEmpty 
                              ? room.description 
                              : 'No description provided.',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'MEMBERS (${room.members.length})',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey[500],
                                letterSpacing: 1,
                              ),
                            ),
                            if (isCreator)
                              TextButton.icon(
                                onPressed: () {
                                  // TODO: Manage members sheet
                                },
                                icon: const Icon(Icons.settings, size: 16),
                                label: Text(
                                  'MANAGE',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFB452FF),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final member = room.members[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[100]!),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: member.avatarUrl.isNotEmpty 
                                    ? NetworkImage(member.avatarUrl) 
                                    : null,
                                backgroundColor: Colors.grey[300],
                                child: member.avatarUrl.isEmpty 
                                    ? const Icon(Icons.person, color: Colors.white) 
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.username,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      member.role.toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        color: member.role == 'creator' 
                                            ? const Color(0xFFB452FF) 
                                            : Colors.grey[600],
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (member.permissions.contains('speak'))
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.mic, size: 16, color: Colors.green),
                                ),
                              if (isCreator && member.userId != currentUser?.id) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.person_remove, size: 20, color: Colors.orange),
                                  onPressed: () {
                                    ref.read(roomControllerProvider.notifier).kickUser(room.id, member.userId);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Kicked ${member.username}')),
                                    );
                                  },
                                  tooltip: 'Kick',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.block, size: 20, color: Colors.red),
                                  onPressed: () {
                                    ref.read(roomControllerProvider.notifier).banUser(room.id, member.userId);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Banned ${member.username}')),
                                    );
                                  },
                                  tooltip: 'Ban',
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      childCount: room.members.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
              ],
            ),
          ),
          
          // Bottom interactions
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMember)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(roomControllerProvider.notifier).addMember(
                                room.id,
                                currentUser!.id,
                                ['speak'], // Default perms
                              ).then((_) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Joined room!')),
                                );
                                // Refresh room list?
                                ref.read(roomControllerProvider.notifier).loadRooms();
                              });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB452FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFFB452FF).withOpacity(0.4),
                        ),
                        child: Text(
                          'JOIN ROOM',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    
                  if (isMember)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Enter room voice chat logic
                                Navigator.pop(context);
                                ref.read(roomControllerProvider.notifier).joinRoom(room.id);
                              },
                              icon: const Icon(Icons.mic),
                              label: Text(
                                'ENTER AUDIO',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () {
                              ref.read(roomControllerProvider.notifier).leaveRoom(); // Local state leave
                              ref.read(roomControllerProvider.notifier).removeMember(
                                room.id,
                                currentUser!.id,
                              ).then((_) {
                                 Navigator.pop(context);
                                 ref.read(roomControllerProvider.notifier).loadRooms();
                              });
                            },
                             style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Icon(Icons.exit_to_app),
                          ),
                        ),
                      ],
                    ),
                    
                  if (isCreator)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton(
                        onPressed: () {
                          // Confirm delete
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Room?'),
                              content: const Text('This cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('CANCEL'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref.read(roomControllerProvider.notifier).deleteRoom(room.id);
                                    Navigator.pop(context); // Close dialog
                                    Navigator.pop(context); // Close sheet
                                  },
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('DELETE'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text(
                          'DELETE ROOM',
                          style: GoogleFonts.outfit(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

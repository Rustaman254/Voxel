import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../state/event_notifier.dart';
import '../state/event_registration_notifier.dart';
import '../../domain/models/event_model.dart';
import 'dart:ui';

class DiscoverEventsDialog extends ConsumerStatefulWidget {
  const DiscoverEventsDialog({super.key});

  @override
  ConsumerState<DiscoverEventsDialog> createState() => _DiscoverEventsDialogState();
}

class _DiscoverEventsDialogState extends ConsumerState<DiscoverEventsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Music', 'Tech', 'Social', 'Gaming', 'Education'];

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
    final events = ref.watch(eventProvider);
    final registeredIds = ref.watch(eventRegistrationProvider);
    
    // Sort events by time
    final sortedEvents = [...events]..sort((a, b) => a.startTime.compareTo(b.startTime));

    final upcomingEvents = _selectedFilter == 'All' 
        ? sortedEvents 
        : sortedEvents.where((e) => e.eventType == _selectedFilter.toUpperCase() || e.voxelTheme == _selectedFilter.toUpperCase()).toList();
        
    final registeredEvents = sortedEvents.where((e) => registeredIds.contains(e.id)).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                // Header with Tabs
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DISCOVER',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey[100],
                              shape: const CircleBorder(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 50,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(21),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.grey[500],
                          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13),
                          tabs: const [
                            Tab(text: 'UPCOMING'),
                            Tab(text: 'REGISTERED'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // UPCOMING TAB
                      Column(
                        children: [
                          if (upcomingEvents.isNotEmpty)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: Row(
                              children: _filters.map((filter) {
                                final isSelected = _selectedFilter == filter;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedFilter = filter;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFB452FF) : Colors.white,
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFFB452FF) : Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        filter,
                                        style: GoogleFonts.outfit(
                                          color: isSelected ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          
                          Expanded(
                            child: upcomingEvents.isEmpty 
                                ? _buildEmptyState('No upcoming events found')
                                : ListView.separated(
                                    padding: const EdgeInsets.all(24),
                                    itemCount: upcomingEvents.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                                    itemBuilder: (context, index) {
                                      final event = upcomingEvents[index];
                                      return _buildEventCard(event, ref);
                                    },
                                  ),
                          ),
                        ],
                      ),
                      
                      // REGISTERED TAB (Luma style)
                      registeredEvents.isEmpty 
                          ? _buildEmptyState('You haven\'t registered for any events yet') 
                          : ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: registeredEvents.length,
                              itemBuilder: (context, index) {
                                final event = registeredEvents[index];
                                final isLast = index == registeredEvents.length - 1;
                                return _buildTimelineItem(event, isLast, ref);
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.outfit(
              color: Colors.grey[400],
              fontSize: 16, 
              fontWeight: FontWeight.w600
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(VoxelEvent event, WidgetRef ref) {
    final isRegistered = ref.watch(eventRegistrationProvider).contains(event.id);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB452FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.eventType.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFB452FF),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        event.title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MMM d, h:mm a').format(event.startTime),
                        style: GoogleFonts.outfit(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(Icons.location_on_rounded, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (isRegistered) {
                    ref.read(eventRegistrationProvider.notifier).unregisterFromEvent(event.id);
                  } else {
                    ref.read(eventRegistrationProvider.notifier).registerForEvent(event.id);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRegistered ?Colors.grey[100] : Colors.black,
                  foregroundColor: isRegistered ? Colors.black : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isRegistered ? 'REGISTERED' : 'REGISTER',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(VoxelEvent event, bool isLast, WidgetRef ref) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB452FF).withOpacity(0.4),
                        blurRadius: 0,
                        spreadRadius: 4,
                      )
                    ],
                    color: const Color(0xFFB452FF),
                  ),
                ),
                if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey[200],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(event.startTime).toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.title,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('h:mm a').format(event.startTime),
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFB452FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: const NetworkImage('https://api.dicebear.com/9.x/adventurer/png?seed=host'),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hosted by User',
                          style: GoogleFonts.outfit(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

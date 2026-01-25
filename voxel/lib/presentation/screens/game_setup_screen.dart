import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/event_notifier.dart';
import '../state/auth_notifier.dart';
import '../state/game_session_provider.dart';

class GameSetupScreen extends ConsumerStatefulWidget {
  final String gameType; // e.g., 'AMONG US'
  const GameSetupScreen({super.key, required this.gameType});

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  int _currentStep = 0;
  String? _selectedEventId;
  final List<Map<String, String>> _tasks = [];
  final _taskNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventProvider);
    final user = ref.watch(authProvider).value;
    final myEvents = events.where((e) => e.creatorId == user?.id).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB452FF),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'HOST A GAME',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 18,
          )
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                _buildEventSelectionStep(myEvents),
                _buildTaskBuilderStep(),
                _buildSummaryStep(myEvents),
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))
        ]
      ),
      child: Row(
        children: List.generate(3, (index) {
          final isDone = _currentStep > index;
          final isCurrent = _currentStep == index;
          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDone || isCurrent ? const Color(0xFFB452FF) : Colors.grey[100],
                    shape: BoxShape.circle,
                    boxShadow: isCurrent ? [
                       BoxShadow(color: const Color(0xFFB452FF).withOpacity(0.3), blurRadius: 10, spreadRadius: 2)
                    ] : null,
                  ),
                  child: Center(
                    child: isDone 
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '${index + 1}', 
                          style: GoogleFonts.outfit(
                            color: isCurrent ? Colors.white : Colors.grey[400], 
                            fontWeight: FontWeight.w900
                          )
                        ),
                  ),
                ),
                if (index < 2) 
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDone ? const Color(0xFFB452FF) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSnapCard({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildEventSelectionStep(List<dynamic> myEvents) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Attach to Event',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Select one of your events to host this game.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 32),
          if (myEvents.isEmpty)
            _buildSnapCard(
              child: Column(
                children: [
                  const Icon(Icons.event_busy_rounded, size: 64, color: Color(0xFFB452FF)),
                  const SizedBox(height: 16),
                  Text(
                    'No events found!',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create an event first to host a game session.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          else
            ...myEvents.map((e) {
              final isSelected = _selectedEventId == e.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedEventId = e.id),
                  child: _buildSnapCard(
                    color: isSelected ? const Color(0xFFB452FF).withOpacity(0.03) : Colors.white,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFB452FF) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.celebration_rounded, 
                            color: isSelected ? Colors.white : const Color(0xFFB452FF)
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title, 
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)
                              ),
                              Text(
                                e.startTime.toString().split('.')[0].substring(0, 16), 
                                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.bold)
                              ),
                            ],
                          ),
                        ),
                        if (isSelected) 
                          const Icon(Icons.check_circle_rounded, color: Color(0xFFB452FF), size: 28),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTaskBuilderStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Create Tasks',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Define custom tasks for players to complete.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 32),
          _buildSnapCard(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskNameController,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'e.g. Fix Wiring',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontWeight: FontWeight.normal),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    if (_taskNameController.text.isNotEmpty) {
                      setState(() {
                        _tasks.add({'name': _taskNameController.text, 'id': DateTime.now().toString()});
                        _taskNameController.clear();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFB452FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_tasks.isEmpty)
             Center(
               child: Padding(
                 padding: const EdgeInsets.symmetric(vertical: 40),
                 child: Text(
                   'No tasks added yet!', 
                   style: GoogleFonts.outfit(color: Colors.grey[400], fontWeight: FontWeight.w900)
                 ),
               ),
             )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSnapCard(
                    child: Row(
                      children: [
                        const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFFB452FF), size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _tasks[index]['name']!, 
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)
                          )
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 24),
                          onPressed: () => setState(() => _tasks.removeAt(index)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep(List<dynamic> myEvents) {
    final event = myEvents.firstWhere((e) => e.id == _selectedEventId, orElse: () => null);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Ready to Play?',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSummaryCard(Icons.dashboard_rounded, 'GAME MODE', widget.gameType),
          const SizedBox(height: 16),
          _buildSummaryCard(Icons.celebration_rounded, 'EVENT', event?.title ?? 'No Event Connected'),
          const SizedBox(height: 16),
          _buildSummaryCard(Icons.list_alt_rounded, 'TASKS', '${_tasks.length} custom tasks'),
          const SizedBox(height: 32),
          _buildSnapCard(
            color: const Color(0xFFB452FF).withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFB452FF), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'All players at this event will get an invite automatically.',
                    style: GoogleFonts.outfit(
                      fontSize: 13, 
                      color: const Color(0xFFB452FF), 
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(IconData icon, String label, String value) {
    return _buildSnapCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: const Color(0xFFB452FF)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w900, letterSpacing: 1.5)
              ),
              const SizedBox(height: 2),
              Text(
                value, 
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: SizedBox(
                height: 64,
                child: ElevatedButton(
                  onPressed: () => setState(() => _currentStep--),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32), 
                      side: const BorderSide(color: Colors.black12)
                    ),
                  ),
                  child: Text('BACK', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 64,
              child: ElevatedButton(
                onPressed: () {
                  if (_currentStep < 2) {
                    setState(() => _currentStep++);
                  } else {
                    ref.read(gameSessionProvider.notifier).createSession('PROXIMITY_TAG');
                    Navigator.pop(context);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000000),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                ),
                child: Text(
                  _currentStep == 2 ? 'LAUNCH GAME 🚀' : 'NEXT',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

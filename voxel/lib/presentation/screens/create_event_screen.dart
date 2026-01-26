import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/event_notifier.dart';
import '../state/auth_notifier.dart';
import '../state/world_controller.dart';
import 'voxel_picker_screen.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '0.00');
  bool _hasTickets = false;
  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  String _selectedTheme = 'CLASSIC';
  double? _customX;
  double? _customY;

  final List<Map<String, String>> _themes = [
    {'id': 'CLASSIC', 'name': 'Classic', 'icon': '🏙️'},
    {'id': 'NEON', 'name': 'Neon City', 'icon': '🌆'},
    {'id': 'FOREST', 'name': 'Zen Forest', 'icon': '🌲'},
    {'id': 'SPACE', 'name': 'Space Port', 'icon': '🚀'},
  ];

  @override
  Widget build(BuildContext context) {
    final worldState = ref.watch(worldControllerProvider);
    final user = ref.read(authProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      appBar: AppBar(
        backgroundColor: const Color(0xFFB452FF), 
        elevation: 0,
        centerTitle: true,
        title: Text(
          worldState.isGpsMode ? 'POST AN EVENT' : 'CREATE A ROOM',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'What\'s the Vibe?',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildFunTextField(
              controller: _titleController,
              hint: worldState.isGpsMode ? 'Event Name' : 'Room Name',
              label: worldState.isGpsMode ? 'EVENT TITLE' : 'ROOM NAME',
              icon: Icons.celebration_rounded,
            ),
            const SizedBox(height: 20),
            _buildFunTextField(
              controller: _descriptionController,
              hint: 'Tell the world what\'s up...',
              label: 'DESCRIPTION',
              icon: Icons.notes_rounded,
              maxLines: 4,
            ),
            const SizedBox(height: 32),
            _buildDateTimePicker(),
            const SizedBox(height: 32),
            _buildFunHeader('WHERE AT?'),
            GestureDetector(
              onTap: () async {
                // In Room mode, location is fixed to virtual map center or current pos relative to canvas
                // In Event mode, we open map picker
                if (!worldState.isGpsMode) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rooms are placed at your current virtual location!')));
                   return;
                }
                
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => VoxelPickerScreen(
                      initialX: _customX ?? worldState.myPosition?.latitude ?? -1.2921,
                      initialY: _customY ?? worldState.myPosition?.longitude ?? 36.8219,
                      voxelTheme: _selectedTheme,
                    ),
                  ),
                );
                if (result is Offset) { // Reuse Offset for LatLng logic simply for now or update picker
                  setState(() {
                    _customX = result.dx;
                    _customY = result.dy;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFB452FF),
                      const Color(0xFF9B59B6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB452FF).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_customX == null) ? 'CURRENT LOCATION' : 'CUSTOM LOCATION SET',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontSize: 14,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            worldState.isGpsMode 
                               ? 'Lat/Long: ${(_customX ?? worldState.myPosition?.latitude ?? 0).toStringAsFixed(4)}, ${(_customY ?? worldState.myPosition?.longitude ?? 0).toStringAsFixed(4)}'
                               : 'Virtual: ${(_customX ?? worldState.myPosition?.x ?? 500).toStringAsFixed(0)}, ${(_customY ?? worldState.myPosition?.y ?? 500).toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildThemeSelection(),
            const SizedBox(height: 32),
            _buildTicketingSection(),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: () {
                  if (_titleController.text.isEmpty || user == null) return;
                  
                  final targetX = _customX ?? (worldState.isGpsMode ? (worldState.myPosition?.latitude ?? 0) : (worldState.myPosition?.x ?? 500));
                  final targetY = _customY ?? (worldState.isGpsMode ? (worldState.myPosition?.longitude ?? 0) : (worldState.myPosition?.y ?? 500));
                  
                  ref.read(eventProvider.notifier).addEvent(
                    _titleController.text,
                    _descriptionController.text,
                    targetX,
                    targetY,
                    user.id,
                    ticketPrice: double.tryParse(_priceController.text) ?? 0.0,
                    hasTickets: _hasTickets,
                    startTime: _selectedDateTime,
                    voxelTheme: _selectedTheme,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000000),
                  foregroundColor: const Color(0xFFFFFFFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: Text(
                  'SEND IT! 🚀',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFunHeader('WHEN?'),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDateTime,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
              );
              if (time != null) {
                setState(() {
                  _selectedDateTime = DateTime(
                    date.year, date.month, date.day, time.hour, time.minute
                  );
                });
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Color(0xFFFF5E9B)),
                const SizedBox(width: 16),
                Text(
                  '${_selectedDateTime.toString().split('.')[0].substring(0, 16)}',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                const Icon(Icons.edit_calendar_rounded, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFunHeader('VOXEL STYLE'),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _themes.length,
            itemBuilder: (context, index) {
              final theme = _themes[index];
              final isSelected = _selectedTheme == theme['id'];
              return GestureDetector(
                onTap: () => setState(() => _selectedTheme = theme['id']!),
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFB452FF) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFB452FF) : Colors.black12,
                      width: 2,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(color: const Color(0xFFB452FF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                    ] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(theme['icon']!, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(
                        theme['name']!,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFunHeader('TICKETING OPTIONAL'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_activity_rounded, color: Color(0xFFB452FF)),
                      const SizedBox(width: 12),
                      Text('Enable Tickets', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Switch(
                    value: _hasTickets,
                    onChanged: (v) => setState(() => _hasTickets = v),
                    activeColor: const Color(0xFFB452FF),
                  ),
                ],
              ),
              if (_hasTickets) ...[
                const Divider(height: 32),
                Row(
                  children: [
                    const Text('\$', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Set your entry price', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFunHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: Colors.grey[600],
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildFunTextField({
    required TextEditingController controller,
    required String hint,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Colors.grey[600],
              letterSpacing: 1.5,
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontWeight: FontWeight.normal),
            prefixIcon: Icon(icon, color: const Color(0xFFFF5E9B)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: const BorderSide(color: Color(0xFFFF5E9B), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

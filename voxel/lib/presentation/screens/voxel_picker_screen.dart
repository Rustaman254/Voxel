import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/world_controller.dart';

class VoxelPickerScreen extends ConsumerStatefulWidget {
  final double initialX;
  final double initialY;

  const VoxelPickerScreen({
    super.key, 
    required this.initialX, 
    required this.initialY,
  });

  @override
  ConsumerState<VoxelPickerScreen> createState() => _VoxelPickerScreenState();
}

class _VoxelPickerScreenState extends ConsumerState<VoxelPickerScreen> {
  late double _pickedX;
  late double _pickedY;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _pickedX = widget.initialX;
    _pickedY = widget.initialY;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB452FF),
        elevation: 0,
        title: Text('SET LOCATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, Offset(_pickedX, _pickedY)),
            child: Text('DONE', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth / 2;
          final centerY = constraints.maxHeight / 2;

          return GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _pickedX -= details.delta.dx / _zoom;
                _pickedY -= details.delta.dy / _zoom;
              });
            },
            onScaleUpdate: (details) {
              setState(() {
                _zoom *= details.scale;
                _zoom = _zoom.clamp(0.1, 5.0);
              });
            },
            child: Container(
              color: Colors.grey[100],
              child: Stack(
                children: [
                  // SIMPLE GRID REPRESENTATION
                  CustomPaint(
                    painter: _MapPainter(
                      centerX: centerX,
                      centerY: centerY,
                      offsetX: _pickedX,
                      offsetY: _pickedY,
                      zoom: _zoom,
                    ),
                    size: Size.infinite,
                  ),
                  // SELECTION CROSSHAIR
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFB452FF), width: 3),
                          ),
                          child: const Center(
                            child: Icon(Icons.add, color: Color(0xFFB452FF), size: 30),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'VOXEL: ${_pickedX.toInt()}, ${_pickedY.toInt()}',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // INSTRUCTION
                  Positioned(
                    bottom: 40,
                    left: 40,
                    right: 40,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: Text(
                        'Drag the map to set the exact spot for your event!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final double centerX;
  final double centerY;
  final double offsetX;
  final double offsetY;
  final double zoom;

  _MapPainter({
    required this.centerX,
    required this.centerY,
    required this.offsetX,
    required this.offsetY,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final step = 50.0 * zoom;
    
    // Draw Grid
    for (double i = (centerX - offsetX * zoom) % step; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = (centerY - offsetY * zoom) % step; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/world_controller.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../painters/world_painter.dart';
import '../../domain/entities/avatar_position.dart';

class VoxelPickerScreen extends ConsumerStatefulWidget {
  final double initialX;
  final double initialY;
  final String? voxelTheme;

  const VoxelPickerScreen({
    super.key, 
    required this.initialX, 
    required this.initialY,
    this.voxelTheme,
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

            return Container(
              color: Colors.grey[100],
              child: Stack(
                children: [
                   // SWITCH: Virtual Grid vs Real Map
                   if (_isRealMapMode())
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(_pickedX, _pickedY),
                          initialZoom: 15,
                          onPositionChanged: (pos, hasGesture) {
                             if (hasGesture && pos.center != null) {
                               setState(() {
                                 _pickedX = pos.center!.latitude;
                                 _pickedY = pos.center!.longitude;
                               });
                             }
                          },
                        ),
                        children: [
                           TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.voxel.app',
                           ),
                        ],
                      )
                   else
                      GestureDetector(
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
                        child: CustomPaint(
                          painter: WorldPainter(
                            cameraX: _pickedX,
                            cameraY: _pickedY,
                            zoom: _zoom,
                            myPosition: null,
                            peers: [],
                            voxelTheme: widget.voxelTheme,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                      
                  // SELECTION CROSSHAIR
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         if (_isRealMapMode())
                            const Icon(Icons.location_on, size: 40, color: Color(0xFFB452FF))
                         else ...[
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
                         ],
                         
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isRealMapMode() 
                                ? 'GPS: ${_pickedX.toStringAsFixed(5)}, ${_pickedY.toStringAsFixed(5)}'
                                : 'VOXEL: ${_pickedX.toInt()}, ${_pickedY.toInt()}',
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
                        _isRealMapMode() ? 'Pan map to pin location' : 'Drag grid to set location',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
        },
      ),
    );
  }

  bool _isRealMapMode() {
    // Heuristic: If coordinates are small (like Lat/Long), assume Map Mode.
    // Virtual coordinates are usually 500, 500. Lat/Long are -90 to 90 / -180 to 180.
    return _pickedX.abs() <= 90 && _pickedY.abs() <= 180;
  }
}

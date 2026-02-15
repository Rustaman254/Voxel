import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/location_service.dart';
import '../../data/services/real_location_service.dart';
import 'package:geolocator/geolocator.dart'; // Import geolocator for permission checks

final locationServiceProvider = Provider<LocationService>((ref) => RealLocationService());

final locationStreamProvider = StreamProvider<Position>((ref) async* {
  final service = ref.watch(locationServiceProvider);

  // Check and request permissions before starting the stream
  final permissionGranted = await service.requestPermission();
  if (!permissionGranted) {
    // If permission is not granted, yield a dummy position and then complete the stream.
    // In a real app, you might want to show a persistent error state to the user.
    yield Position(
      latitude: 0,
      longitude: 0,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    return; // Complete the stream
  }

  // If permissions are granted, then provide the actual position stream.
  await for (final position in service.getPositionStream()) {
    yield position;
  }
});

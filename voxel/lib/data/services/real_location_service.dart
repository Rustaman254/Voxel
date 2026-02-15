import 'package:geolocator/geolocator.dart';
import '../../domain/services/location_service.dart';
import 'dart:collection'; // Import for Queue

class RealLocationService implements LocationService {
  final int _bufferSize = 5; // Number of recent positions to average
  final Queue<Position> _positionBuffer = Queue();

  @override
  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Prompt user to enable location services
      await Geolocator.openLocationSettings();
      // After opening settings, wait a bit and re-check once
      await Future.delayed(const Duration(seconds: 2));
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  @override
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, // Highest accuracy for navigation
        distanceFilter: 0, // Update immediately on any movement for fluid tracking
        timeLimit: Duration(seconds: 1), // Optional: ensure updates at least every second
      ),
    ).map((position) {
      // Add new position to buffer
      _positionBuffer.add(position);
      if (_positionBuffer.length > _bufferSize) {
        _positionBuffer.removeFirst();
      }
      return _getSmoothedPosition();
    });
  }

  Position _getSmoothedPosition() {
    if (_positionBuffer.isEmpty) {
      return Position(
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
      ); // Return a default or throw error, depending on desired behavior
    }

    double totalLatitude = 0;
    double totalLongitude = 0;
    double totalAccuracy = 0;
    double totalAltitude = 0;
    double totalHeading = 0;
    double totalSpeed = 0;
    double totalSpeedAccuracy = 0;
    double totalAltitudeAccuracy = 0;
    double totalHeadingAccuracy = 0;

    for (var pos in _positionBuffer) {
      totalLatitude += pos.latitude;
      totalLongitude += pos.longitude;
      totalAccuracy += pos.accuracy;
      totalAltitude += pos.altitude;
      totalHeading += pos.heading;
      totalSpeed += pos.speed;
      totalSpeedAccuracy += pos.speedAccuracy;
      totalAltitudeAccuracy += pos.altitudeAccuracy;
      totalHeadingAccuracy += pos.headingAccuracy;
    }

    final int count = _positionBuffer.length;
    return Position(
      latitude: totalLatitude / count,
      longitude: totalLongitude / count,
      timestamp: _positionBuffer.last.timestamp, // Use the latest timestamp
      accuracy: totalAccuracy / count,
      altitude: totalAltitude / count,
      heading: totalHeading / count,
      speed: totalSpeed / count,
      speedAccuracy: totalSpeedAccuracy / count,
      altitudeAccuracy: totalAltitudeAccuracy / count,
      headingAccuracy: totalHeadingAccuracy / count,
    );
  }
}

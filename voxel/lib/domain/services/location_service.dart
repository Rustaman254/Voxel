import 'package:geolocator/geolocator.dart';

abstract class LocationService {
  Future<bool> requestPermission();
  Stream<Position> getPositionStream();
}

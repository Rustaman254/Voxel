import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/location_service.dart';
import '../../data/services/real_location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) => RealLocationService());

final locationStreamProvider = StreamProvider((ref) {
  final service = ref.watch(locationServiceProvider);
  // Optional: Check permissions first?
  // Use a FutureProvider chain if permission check is needed first.
  // For now assume logic handles it or returns error stream.
  return service.getPositionStream();
});

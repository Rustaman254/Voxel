import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_profile.dart';
import '../../data/repositories/auth_repository.dart';

class AuthNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AsyncData(null));

  Future<void> login(String username, String avatarUrl) async {
    state = const AsyncLoading();
    try {
      final user = await _authRepository.login(username, avatarUrl);
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void logout() {
    state = const AsyncData(null);
  }
}

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserProfile?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

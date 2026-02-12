import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_profile.dart';
import '../../data/repositories/auth_repository.dart';

class AuthNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AsyncLoading()) {
    checkPersistedUser();
  }

  Future<void> checkPersistedUser() async {
    try {
      final user = await _authRepository.getPersistedUser();
      state = AsyncData(user);
    } catch (e) {
      state = const AsyncData(null);
    }
  }

  Future<void> login(String email, String password) async {
    // state = const AsyncLoading(); // Removed to prevent main.dart form rebuilding
    try {
      final user = await _authRepository.login(email, password);
      state = AsyncData(user);
    } catch (e) {
      // state = AsyncError(e, st); // Keep state as is (null), but throw
      rethrow;
    }
  }
  
  Future<void> signup(String email, String username, String displayName, String avatarUrl, String password) async {
    // state = const AsyncLoading();
    try {
      final user = await _authRepository.signup(email, username, displayName, avatarUrl, password);
      state = AsyncData(user);
    } catch (e) {
      // state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authRepository.clearSession();
    state = const AsyncData(null);
  }
}

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserProfile?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

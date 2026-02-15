import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_profile.dart';
import '../../data/repositories/auth_repository.dart';

class AuthState {
  final UserProfile? user;
  final bool onboardingCompleted;
  final bool isLoading;

  AuthState({this.user, this.onboardingCompleted = false, this.isLoading = false});

  AuthState copyWith({UserProfile? user, bool? onboardingCompleted, bool? isLoading}) {
    return AuthState(
      user: user ?? this.user,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(AuthState(isLoading: true)) {
    checkPersistedUser();
  }

  Future<void> checkPersistedUser() async {
    try {
      final user = await _authRepository.getPersistedUser();
      final onboardingCompleted = await _authRepository.isOnboardingCompleted();
      state = state.copyWith(user: user, onboardingCompleted: onboardingCompleted, isLoading: false);
    } catch (e) {
      state = state.copyWith(user: null, isLoading: false);
    }
  }

  void completeOnboarding() {
    _authRepository.setOnboardingCompleted(true);
    state = state.copyWith(onboardingCompleted: true);
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _authRepository.login(email, password);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
  
  Future<void> signup(String email, String username, String displayName, String avatarUrl, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _authRepository.signup(email, username, displayName, avatarUrl, password);
      // After signup, onboarding is definitely completed
      _authRepository.setOnboardingCompleted(true);
      state = state.copyWith(user: user, onboardingCompleted: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> updateProfile(String displayName, String avatarUrl) async {
    if (state.user == null) {
      throw Exception('No user logged in');
    }
    
    try {
      final updatedUser = await _authRepository.updateProfile(
        state.user!.id,
        displayName,
        avatarUrl,
        state.user!.authToken,
      );
      
      // Merge with existing user data
      final mergedUser = UserProfile(
        id: state.user!.id,
        displayName: displayName,
        avatarUrl: avatarUrl,
        email: state.user!.email,
        username: state.user!.username,
        authToken: state.user!.authToken,
      );
      
      state = state.copyWith(user: mergedUser);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authRepository.clearSession();
    state = AuthState(user: null, onboardingCompleted: true, isLoading: false);
  }
}

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

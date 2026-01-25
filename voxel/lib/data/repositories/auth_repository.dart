import 'package:uuid/uuid.dart';
import '../../domain/entities/user_profile.dart';

class AuthRepository {
  Future<UserProfile> login(String username, String avatarUrl) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final id = const Uuid().v4();
    return UserProfile(
      id: id,
      displayName: username,
      avatarUrl: avatarUrl,
    );
  }

  Future<UserProfile> signup(String email, String password) async {
    return login(email, password);
  }
}

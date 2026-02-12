import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String displayName;
  final String avatarUrl;
  final String email;
  final String username;
  final String authToken;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    this.email = '',
    this.username = '',
    this.authToken = '',
  });

  @override
  List<Object?> get props => [id, displayName, avatarUrl, email, username, authToken];
}

import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String displayName;
  final String avatarUrl;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
  });

  @override
  List<Object?> get props => [id, displayName, avatarUrl];
}

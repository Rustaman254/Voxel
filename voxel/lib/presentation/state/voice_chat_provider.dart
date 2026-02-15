import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/voice_chat_service.dart';
import '../../data/services/mock_voice_chat_service.dart';
import '../../data/services/webrtc_voice_service.dart';
import '../../data/repositories/socket_world_repository.dart';
import 'auth_notifier.dart';
import 'world_controller.dart';

final voiceChatServiceProvider = Provider<VoiceChatService>((ref) {
  final authState = ref.watch(authProvider);
  final repo = ref.watch(worldRepositoryProvider);
  final userId = authState.user?.id;
  
  if (userId != null && repo is SocketWorldRepository) {
    return WebrtcVoiceService(repo, userId);
  }
  
  return MockVoiceChatService();
});

final voiceChatStateProvider = StreamProvider<VoiceChatState>((ref) {
  final service = ref.watch(voiceChatServiceProvider);
  return service.state;
});

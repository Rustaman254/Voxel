import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/voice_chat/voice_chat_bloc.dart';
import '../../core/error_handler.dart';

/// Example widget showing how to use VoiceChatBloc
class VoiceChatWidget extends StatelessWidget {
  const VoiceChatWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VoiceChatBloc, VoiceChatBlocState>(
      listener: (context, state) {
        // Handle errors
        if (state is VoiceChatError) {
          ErrorHandler.showErrorSnackBar(context, state.message);
        }
        
        // Handle successful connection
        if (state is VoiceChatConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to voice chat with ${state.connectedUserIds.length} users'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is VoiceChatConnecting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to voice chat...'),
              ],
            ),
          );
        }

        if (state is VoiceChatConnected) {
          return _buildConnectedUI(context, state);
        }

        if (state is VoiceChatError) {
          return GlobalErrorWidget(
            error: state.message,
            onRetry: () {
              // Retry connection
              if (state.channelId != null) {
                context.read<VoiceChatBloc>().add(JoinVoiceChannel(state.channelId!));
              }
            },
          );
        }

        // Initial or disconnected state
        return _buildDisconnectedUI(context);
      },
    );
  }

  Widget _buildConnectedUI(BuildContext context, VoiceChatConnected state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Voice Chat Active',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text('${state.connectedUserIds.length} users connected'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                state.isMuted ? Icons.mic_off : Icons.mic,
                color: state.isMuted ? Colors.red : Colors.green,
              ),
              onPressed: () {
                context.read<VoiceChatBloc>().add(ToggleMute(!state.isMuted));
              },
              tooltip: state.isMuted ? 'Unmute' : 'Mute',
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              onPressed: () {
                context.read<VoiceChatBloc>().add(const LeaveVoiceChannel());
              },
              tooltip: 'Leave',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDisconnectedUI(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Not connected to voice chat'),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            // Example: join a test channel
            context.read<VoiceChatBloc>().add(const JoinVoiceChannel('test-channel'));
          },
          icon: const Icon(Icons.mic),
          label: const Text('Join Voice Chat'),
        ),
      ],
    );
  }
}

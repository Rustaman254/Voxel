import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'presentation/state/auth_notifier.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/world_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'core/services/network_config_service.dart';
import 'presentation/bloc/voice_chat/voice_chat_bloc.dart';
import 'presentation/state/voice_chat_provider.dart';
import 'core/error_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NetworkConfigService().init();
  
  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    ErrorHandler.handleError(details.exception, details.stack, context: 'Flutter');
  };
  
  runApp(
    const ProviderScope(child: VoxelApp()),
  );
}

class VoxelApp extends ConsumerWidget {
  const VoxelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final voiceService = ref.watch(voiceChatServiceProvider);

    return MultiBlocProvider(
      providers: [
        BlocProvider<VoiceChatBloc>(
          create: (context) => VoiceChatBloc(voiceService),
        ),
        // Add more BLoCs here as needed
      ],
      child: MaterialApp(
        title: 'Voxel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFB452FF), // Neon Purple
            primary: const Color(0xFFB452FF), // Neon Purple
            secondary: const Color(0xFFFF5E9B), // Vibrant Pink
            tertiary: const Color(0xFF9B59B6), // Electric Purple
            surface: const Color(0xFFFFFFFF), // White
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.outfitTextTheme(
            ThemeData.light().textTheme.apply(
              bodyColor: const Color(0xFF000000), // Black text
              displayColor: const Color(0xFF000000),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
          ),
        ),
        builder: (context, widget) {
          // Global error boundary
          ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
            return GlobalErrorWidget(
              error: errorDetails.exception,
              onRetry: () {
                // Trigger app rebuild
                (context as Element).markNeedsBuild();
              },
            );
          };
          return widget ?? const SizedBox();
        },
        home: authState.isLoading 
          ? const SplashScreen()
          : authState.user != null
              ? const WorldScreen()
              : authState.onboardingCompleted
                  ? const LoginScreen()
                  : const OnboardingScreen(),
      ),
    );
  }
}

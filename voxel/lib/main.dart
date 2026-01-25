import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'presentation/state/auth_notifier.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/world_screen.dart';

void main() {
  runApp(
    const ProviderScope(child: VoxelApp()),
  );
}

class VoxelApp extends ConsumerWidget {
  const VoxelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Voxel World',
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
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const WorldScreen();
          } else {
            return const LoginScreen();
          }
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, st) => Scaffold(body: Center(child: Text('Error: $err'))),
      ),
    );
  }
}

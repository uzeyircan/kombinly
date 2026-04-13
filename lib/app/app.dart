import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_gender.dart';
import '../features/auth/presentation/pages/auth_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/onboarding/presentation/pages/gender_selection_page.dart';

class KombinlyApp extends StatelessWidget {
  const KombinlyApp({super.key});

  ThemeData _buildTheme() {
    const seed = Color(0xFF8F4D3F);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ).copyWith(
          surface: const Color(0xFFFFF8F1),
          surfaceContainer: const Color(0xFFF7EAE0),
          surfaceContainerHighest: const Color(0xFFF0DDD2),
        );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFFF8F1),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF2D2421),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Color(0xFF2D2421),
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.74),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
      ),
    );
  }

  Future<String> _resolveGender(SupabaseClient client, String userId) async {
    try {
      final profile = await client
          .from('profiles')
          .select('gender')
          .eq('id', userId)
          .maybeSingle();

      final gender = (profile?['gender'] as String?)?.trim();
      return ProfileGender.normalize(gender);
    } catch (_) {
      return ProfileGender.unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kombinly',
      theme: _buildTheme(),
      home: StreamBuilder<AuthState>(
        stream: client.auth.onAuthStateChange,
        builder: (context, authSnapshot) {
          final session =
              authSnapshot.data?.session ?? client.auth.currentSession;

          if (session == null) {
            return const AuthPage();
          }

          return FutureBuilder<String>(
            future: _resolveGender(client, session.user.id),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final gender = profileSnapshot.data ?? ProfileGender.unknown;
              if (gender == ProfileGender.unknown) {
                return const GenderSelectionPage();
              }

              return HomePage(gender: gender);
            },
          );
        },
      ),
    );
  }
}

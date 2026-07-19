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

          return _ProfileRouter(userId: session.user.id);
        },
      ),
    );
  }
}

class _ProfileRouter extends StatefulWidget {
  final String userId;

  const _ProfileRouter({required this.userId});

  @override
  State<_ProfileRouter> createState() => _ProfileRouterState();
}

class _ProfileRouterState extends State<_ProfileRouter> {
  late Future<String> _genderFuture;

  @override
  void initState() {
    super.initState();
    _genderFuture = _resolveGender();
  }

  @override
  void didUpdateWidget(covariant _ProfileRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _genderFuture = _resolveGender();
    }
  }

  Future<String> _resolveGender() async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('gender')
          .eq('id', widget.userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      final gender = (profile?['gender'] as String?)?.trim();
      return ProfileGender.normalize(gender);
    } catch (_) {
      // Profil tablosu erişilemiyorsa kullanıcıyı sonsuz loading ekranında
      // bırakmak yerine onboarding'e geçiririz. Kayıt işlemi orada yeniden
      // denenebilir ve gerçek hata kullanıcıya gösterilebilir.
      return ProfileGender.unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _genderFuture,
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
  }
}

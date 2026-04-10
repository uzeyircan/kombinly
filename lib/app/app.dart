import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_gender.dart';
import '../features/auth/presentation/pages/auth_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/onboarding/presentation/pages/gender_selection_page.dart';

class KombinlyApp extends StatelessWidget {
  const KombinlyApp({super.key});

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      home: StreamBuilder<AuthState>(
        stream: client.auth.onAuthStateChange,
        builder: (context, authSnapshot) {
          final session = authSnapshot.data?.session ?? client.auth.currentSession;

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

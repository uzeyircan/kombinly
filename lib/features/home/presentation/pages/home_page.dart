import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/profile_gender.dart';
import '../../../ai_try_on/presentation/pages/ai_try_on_page.dart';
import '../../../wardrobe/presentation/pages/wardrobe_page.dart';
import '../../../outfit/presentation/pages/try_on_studio_page.dart';
import '../../../outfit/presentation/pages/today_outfit_page.dart';
import '../../../outfit/presentation/pages/saved_outfits_page.dart';

class HomePage extends StatefulWidget {
  final String gender;

  const HomePage({super.key, required this.gender});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;

  late String _gender;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _gender = ProfileGender.normalize(widget.gender);
  }

  Future<void> _updateGender(String value) async {
    final user = _supabase.auth.currentUser;
    final normalizedValue = ProfileGender.normalize(value);
    if (user == null || _isBusy || normalizedValue == _gender) return;

    setState(() => _isBusy = true);

    try {
      PostgrestException? lastPostgrestError;
      var updateSucceeded = false;

      for (final candidate in ProfileGender.storageCandidates(normalizedValue)) {
        try {
          await _supabase
              .from('profiles')
              .update({'gender': candidate})
              .eq('id', user.id);
          updateSucceeded = true;
          break;
        } on PostgrestException catch (e) {
          lastPostgrestError = e;
        }
      }

      if (!updateSucceeded) {
        throw lastPostgrestError ??
            PostgrestException(message: 'Could not find an accepted gender value');
      }

      if (!mounted) return;

      setState(() => _gender = normalizedValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gender updated to ${ProfileGender.label(normalizedValue)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update gender: $e')));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _showGenderPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Women'),
                trailing: _gender == ProfileGender.female
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, ProfileGender.female),
              ),
              ListTile(
                title: const Text('Men'),
                trailing: _gender == ProfileGender.male
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, ProfileGender.male),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await _updateGender(selected);
    }
  }

  Future<void> _signOut() async {
    if (_isBusy) return;

    setState(() => _isBusy = true);

    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not sign out: $e')));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _showProfileSheet() async {
    final user = _supabase.auth.currentUser;
    final email = user?.email ?? 'No email';
    final userId = user?.id ?? '';
    final shortId = userId.length > 8 ? userId.substring(0, 8) : userId;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      child: Text(
                        email.isNotEmpty ? email[0].toUpperCase() : 'U',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (shortId.isNotEmpty)
                            Text(
                              'User ID: $shortId',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Current gender'),
                  subtitle: Text(ProfileGender.label(_gender)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.swap_horiz),
                  title: const Text('Change gender'),
                  subtitle: const Text('Update your wardrobe base'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _showGenderPicker();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  subtitle: const Text('Return to the login screen'),
                  enabled: !_isBusy,
                  onTap: () async {
                    Navigator.pop(context);
                    await _signOut();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kombinly'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showProfileSheet,
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome, ${ProfileGender.label(_gender)} user',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your wardrobe-based outfit assistant is ready.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            _HomeActionCard(
              title: 'AI Try-On',
              subtitle: 'Generate realistic mannequin try-on images',
              icon: Icons.auto_fix_high_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiTryOnPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _HomeActionCard(
              title: 'My Wardrobe',
              subtitle: 'Add and manage your clothes',
              icon: Icons.checkroom_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WardrobePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _HomeActionCard(
              title: 'Try On Studio',
              subtitle: 'Build a look manually on the mannequin',
              icon: Icons.view_in_ar_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TryOnStudioPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _HomeActionCard(
              title: 'Today’s Outfit',
              subtitle: 'Get outfit suggestions for today',
              icon: Icons.auto_awesome_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TodayOutfitPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _HomeActionCard(
              title: 'Saved Outfits',
              subtitle: 'View your saved outfit history',
              icon: Icons.bookmark_outline,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SavedOutfitsPage(),
                  ),
                );
              },
            ),
          ],
        ),
        ],
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _HomeActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: 112,
            child: Row(
              children: [
                Icon(icon, size: 42),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(subtitle, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

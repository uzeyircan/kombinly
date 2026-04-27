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

      for (final candidate in ProfileGender.storageCandidates(
        normalizedValue,
      )) {
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
            PostgrestException(
              message: 'Could not find an accepted gender value',
            );
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

  Widget _buildRecommendationPage() {
    return TodayOutfitPage(initialGender: _gender);
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
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          _HomeHeroCard(
            gender: ProfileGender.label(_gender),
            onRecommend: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _buildRecommendationPage()),
              );
            },
            onWardrobe: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WardrobePage()),
              );
            },
            onSaved: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedOutfitsPage()),
              );
            },
          ),
          const SizedBox(height: 22),
          Text(
            'Başla',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          _HomeActionCard(
            title: 'Gardıroptan Kombin',
            subtitle: 'Senaryo, stil ve ortama göre ne giyeceğine karar ver',
            icon: Icons.auto_awesome_outlined,
            accentColor: const Color(0xFF8B6F3D),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _buildRecommendationPage()),
              );
            },
          ),
          const SizedBox(height: 14),
          _HomeActionCard(
            title: 'My Wardrobe',
            subtitle: 'Upload, process, and organize your clothes',
            icon: Icons.checkroom_outlined,
            accentColor: const Color(0xFF617B58),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WardrobePage()),
              );
            },
          ),
          const SizedBox(height: 14),
          _HomeActionCard(
            title: 'Saved Outfits',
            subtitle: 'Karar motorunun önerilerini ve kayıtlı kombinlerini gör',
            icon: Icons.bookmark_outline,
            accentColor: const Color(0xFF704F62),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedOutfitsPage()),
              );
            },
          ),
          const SizedBox(height: 14),
          _HomeActionCard(
            title: 'Try On Studio',
            subtitle: 'Manken üzerinde manuel kombin önizlemesi oluştur',
            icon: Icons.view_in_ar_outlined,
            accentColor: const Color(0xFF3F6C7B),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TryOnStudioPage()),
              );
            },
          ),
          const SizedBox(height: 14),
          _HomeActionCard(
            title: 'AI Try-On',
            subtitle:
                'Experimental: generate AI try-on images from wardrobe pieces',
            icon: Icons.auto_fix_high_outlined,
            accentColor: const Color(0xFFB85C38),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiTryOnPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeHeroCard extends StatelessWidget {
  final String gender;
  final VoidCallback onRecommend;
  final VoidCallback onWardrobe;
  final VoidCallback onSaved;

  const _HomeHeroCard({
    required this.gender,
    required this.onRecommend,
    required this.onWardrobe,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F2A25), Color(0xFF8F4D3F), Color(0xFFE9B872)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Text(
              '$gender wardrobe profile',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Ne giyeceğine birlikte karar verelim',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Senaryonu, stilini ve ortamını seç. Kombinly gardırobundaki parçalardan uygun kombini önerir, eksikleri gösterir ve manken üzerinde önizletir.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 16,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _HeroMetric(
                label: 'Kombin',
                icon: Icons.auto_awesome,
                onTap: onRecommend,
              ),
              const SizedBox(width: 10),
              _HeroMetric(
                label: 'Gardırop',
                icon: Icons.checkroom,
                onTap: onWardrobe,
              ),
              const SizedBox(width: 10),
              _HeroMetric(label: 'Saved', icon: Icons.bookmark, onTap: onSaved),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HeroMetric({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
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

class _HomeActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

  const _HomeActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: Colors.white.withValues(alpha: 0.74),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.52),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, size: 30, color: accentColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.25,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

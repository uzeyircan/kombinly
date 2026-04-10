import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/profile_gender.dart';
import '../../../home/presentation/pages/home_page.dart';

class GenderSelectionPage extends StatefulWidget {
  const GenderSelectionPage({super.key});

  @override
  State<GenderSelectionPage> createState() => _GenderSelectionPageState();
}

class _GenderSelectionPageState extends State<GenderSelectionPage> {
  final _supabase = Supabase.instance.client;
  bool _isSaving = false;

  Future<void> _selectGender(String value) async {
    final user = _supabase.auth.currentUser;
    if (user == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      PostgrestException? lastPostgrestError;
      var saved = false;

      for (final candidate in ProfileGender.storageCandidates(value)) {
        try {
          await _supabase
              .from('profiles')
              .update({'gender': candidate})
              .eq('id', user.id);
          saved = true;
          break;
        } on PostgrestException catch (e) {
          lastPostgrestError = e;
        }
      }

      if (!saved) {
        throw lastPostgrestError ??
            PostgrestException(message: 'Could not save gender');
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomePage(gender: value)),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save gender: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Style Base'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              'Select the option that best matches your wardrobe.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _GenderCard(
                      title: 'Women',
                      icon: Icons.female,
                      onTap: _isSaving
                          ? null
                          : () => _selectGender(ProfileGender.female),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _GenderCard(
                      title: 'Men',
                      icon: Icons.male,
                      onTap: _isSaving
                          ? null
                          : () => _selectGender(ProfileGender.male),
                    ),
                  ),
                ],
              ),
            ),
            if (_isSaving) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const _GenderCard({
    required this.title,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

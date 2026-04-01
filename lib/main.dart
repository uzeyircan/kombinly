import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://iwpczevhetourgorfdwc.supabase.co',
    anonKey: 'sb_publishable_3xoBFL-1c7i4rP4BY6Oc0Q_exNuLSBr',
  );

  runApp(const KombinlyApp());
}

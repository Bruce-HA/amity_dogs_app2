import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'login_page.dart';
import 'session_gate.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
   );
/*
  await Supabase.initialize(
    url: 'https://phkwizyrpfzoecugpshb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBoa3dpenlycGZ6b2VjdWdwc2hiIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2OTM2NjI4MiwiZXhwIjoyMDg0OTQyMjgyfQ.XF9Mi_Pzp-F2AQflrFEbuftf1rqavZWsLUwRoS6XpHA',
  );
*/
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const AmityDogsApp(),
    ),
  );
}

class AmityDogsApp extends StatelessWidget {
  const AmityDogsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Amity Labradoodles',
      theme: themeProvider.themeData,
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session =
              Supabase.instance.client.auth.currentSession;

          if (session == null) {
            return LoginPage();
          } else {
            return SessionGate();
          }
        },
      ),
    );
  }
}
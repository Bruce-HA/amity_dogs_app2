import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_user.dart';
import 'pages/dashboard_page.dart';
import 'login_page.dart';
import 'pages/reset_password_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ResetPasswordPage(),
            ),
          );
        });
      }
    });
  }

  @override
    Widget build(BuildContext context) {
      final session = supabase.auth.currentSession;

      // 🔥 Detect recovery session
      final isRecovery =
          supabase.auth.currentSession?.user?.recoverySentAt != null;

      if (isRecovery) {
        return const ResetPasswordPage();
      }

      if (session == null) {
        return const LoginPage();
      }

      // 👇 LOAD USER BEFORE DASHBOARD
      return FutureBuilder(
        future: AppUser.load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return const DashboardPage();
        },
      );
    }
}
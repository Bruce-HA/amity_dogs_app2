import 'package:flutter/material.dart';
import 'services/app_session.dart';
import 'pages/dashboard_page.dart';
import 'services/app_user.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AppSession().load();
    await AppUser.load(); // ✅ ADD THIS
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const DashboardPage();
  }
}
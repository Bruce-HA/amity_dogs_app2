import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionManager extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  String? userId;
  String? businessId;
  String? role;

  bool get isSuperAdmin => role == 'super_admin';
  bool get isOwner => role == 'owner' || role == 'super_admin';
  bool get isHelper => role == 'helper';

  Future<void> loadUser() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    userId = user.id;

    final data = await supabase
        .from('app_users')
        .select('business_id, role')
        .eq('id', userId!)
        .single();

    businessId = data['business_id'];
    role = data['role'];

    notifyListeners();
  }

  void clear() {
    userId = null;
    businessId = null;
    role = null;
    notifyListeners();
  }
}
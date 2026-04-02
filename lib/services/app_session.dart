import 'package:supabase_flutter/supabase_flutter.dart';

class AppSession {
  static final AppSession _instance = AppSession._internal();
  factory AppSession() => _instance;
  AppSession._internal();

  final supabase = Supabase.instance.client;

  String? userId;
  String? businessId;
  String? role;

  bool get isAdmin => role == 'admin';
  bool get isBreeder => role == 'breeder';
  bool get isHelper => role == 'helper';

  bool get canManageUsers => isAdmin;

  Future<void> load() async {
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
  }

  void clear() {
    userId = null;
    businessId = null;
    role = null;
  }
}